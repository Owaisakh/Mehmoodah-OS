// Edge Function: create_teacher
// Handles: Auth user creation, role metadata assignment, and teachers table insert.
// Invoked by: Admin only (JWT role check enforced)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // Verify calling user is admin
    const authHeader = req.headers.get("Authorization");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(
      authHeader?.replace("Bearer ", "") ?? ""
    );
    if (authError || !user) throw new Error("Unauthorized");

    const { data: callerProfile } = await supabaseAdmin
      .from("users")
      .select("role")
      .eq("auth_user_id", user.id)
      .single();
    if (callerProfile?.role !== "admin") throw new Error("Forbidden: Admin only");

    // Parse request body
    const { full_name, email, password, subject, joining_date, teacher_code } = await req.json();

    // 1. Create auth user
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name, role: "teacher" },
    });
    if (createError) throw createError;

    // 2. Wait for trigger to insert into public.users, then fetch the public user id
    const { data: publicUser, error: publicUserError } = await supabaseAdmin
      .from("users")
      .select("id")
      .eq("auth_user_id", newUser.user!.id)
      .single();
    if (publicUserError || !publicUser) throw publicUserError ?? new Error("User record not found");

    // 3. Insert teacher record
    const { error: teacherError } = await supabaseAdmin.from("teachers").insert({
      user_id: publicUser.id,
      teacher_code,
      subject,
      joining_date,
    });
    if (teacherError) throw teacherError;

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
