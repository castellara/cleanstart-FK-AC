import { supabase } from "@/integrations/supabase/client";

export async function createSession(userId: string): Promise<string> {
  const { data, error } = await supabase
    .from("sessions")
    .insert({ user_id: userId })
    .select("id")
    .single();
  if (error || !data) throw error ?? new Error("Failed to create session");
  return data.id;
}
