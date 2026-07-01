
-- Profiles table (linked to auth.users)
CREATE TABLE public.profiles (
  id UUID NOT NULL PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  persona TEXT CHECK (persona IN ('homeowner','renter')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "Users insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
-- DELETE is intentional: this is the account-deletion mechanism (cascades to
-- sessions/messages/reports/feedback). No UI calls it yet; add a confirmation
-- flow before exposing it in product.
CREATE POLICY "Users delete own profile" ON public.profiles FOR DELETE TO authenticated USING (auth.uid() = id);

-- Sessions
CREATE TABLE public.sessions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'New session',
  is_complete BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sessions TO authenticated;
GRANT ALL ON public.sessions TO service_role;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own sessions" ON public.sessions FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
-- Postgres does not auto-index foreign keys; this is filtered on directly
-- (src/routes/history.tsx).
CREATE INDEX idx_sessions_user_id ON public.sessions(user_id);

-- Messages
CREATE TABLE public.messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user','assistant')),
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO authenticated;
GRANT ALL ON public.messages TO service_role;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage messages in own sessions" ON public.messages FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.sessions s WHERE s.id = session_id AND s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE INDEX idx_messages_session ON public.messages(session_id, created_at);

-- Reports
CREATE TABLE public.reports (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  persona TEXT,
  top_options JSONB NOT NULL DEFAULT '[]'::jsonb,
  key_insights JSONB NOT NULL DEFAULT '[]'::jsonb,
  next_steps JSONB NOT NULL DEFAULT '[]'::jsonb,
  resources JSONB NOT NULL DEFAULT '[]'::jsonb,
  readiness_score INTEGER CHECK (readiness_score IS NULL OR readiness_score BETWEEN 0 AND 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- One report per session: report.functions.ts does a select-then-upsert by
  -- session_id; without this, concurrent "generate report" requests could race
  -- and insert duplicates. Also serves as the index for session_id lookups.
  CONSTRAINT reports_session_id_key UNIQUE (session_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.reports TO authenticated;
GRANT ALL ON public.reports TO service_role;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own reports" ON public.reports FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX idx_reports_user_id ON public.reports(user_id);

-- Feedback
CREATE TABLE public.feedback (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id UUID NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  rating TEXT NOT NULL CHECK (rating IN ('up','down')),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.feedback TO authenticated;
GRANT ALL ON public.feedback TO service_role;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage feedback in own sessions" ON public.feedback FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.sessions s WHERE s.id = session_id AND s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
CREATE INDEX idx_feedback_session_id ON public.feedback(session_id);

-- updated_at trigger. SECURITY INVOKER: this function doesn't need elevated
-- privileges, and its EXECUTE is revoked from public roles below so it can
-- only ever run via the trigger.
CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Auto-create profile on signup. Must remain SECURITY DEFINER (called from
-- the auth.users trigger, which runs as the user being inserted), but EXECUTE
-- is revoked from public roles so it can only run via the trigger.
CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END; $$;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
