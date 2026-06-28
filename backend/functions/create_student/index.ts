// Edge Function: create_student
// Handles: Auth user creation, role metadata assignment, student_code generation, and students table insert.
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
    const {
      full_name,
      email,
      password,
      roll_number,
      class_id,
      dob,
      guardian_name,
      guardian_phone,
      admission_date,
    } = await req.json();

    // Generate unique student code: STD-YYYY-NNNN
    const year = new Date().getFullYear();
    const { count } = await supabaseAdmin
      .from("students")
      .select("*", { count: "exact", head: true });
    const sequence = String((count ?? 0) + 1).padStart(4, "0");
    const student_code = `STD-${year}-${sequence}`;

    // 1. Create auth user
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name, role: "student" },
    });
    if (createError) throw createError;

    // 2. Wait for trigger to insert into public.users, then fetch the public user id
    const { data: publicUser, error: publicUserError } = await supabaseAdmin
      .from("users")
      .select("id")
      .eq("auth_user_id", newUser.user!.id)
      .single();
    if (publicUserError || !publicUser) throw publicUserError ?? new Error("User record not found");

    // 3. Insert student record
    const { error: studentError } = await supabaseAdmin.from("students").insert({
      user_id: publicUser.id,
      student_code,
      roll_number,
      class_id,
      dob,
      guardian_name,
      guardian_phone,
      admission_date,
    });
    if (studentError) throw studentError;

    return new Response(JSON.stringify({ success: true, student_code }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
