// Edge Function: create_student
// Handles: Auth user creation, student code generation, and students table insert.
// Invoked by: Admin only

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

    // Verify admin
    const authHeader = req.headers.get("Authorization");
    const { data: { user } } = await supabaseAdmin.auth.getUser(
      authHeader?.replace("Bearer ", "") ?? ""
    );
    if (!user) throw new Error("Unauthorized");

    const { data: callerProfile } = await supabaseAdmin
      .from("users").select("role").eq("auth_user_id", user.id).single();
    if (callerProfile?.role !== "admin") throw new Error("Forbidden: Admin only");

    const {
      full_name, email, password,
      roll_number, class_id, dob,
      guardian_name, guardian_phone, admission_date,
    } = await req.json();

    // Generate unique student code: STD-{YEAR}-{SEQUENCE}
    const year = new Date().getFullYear();
    const { count } = await supabaseAdmin.from("students").select("*", { count: "exact", head: true });
    const sequence = String((count ?? 0) + 1).padStart(4, "0");
    const student_code = `STD-${year}-${sequence}`;

    // Create auth user
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name, role: "student" },
    });
    if (createError) throw createError;

    // Get the public.users row created by trigger
    const { data: publicUser } = await supabaseAdmin
      .from("users").select("id").eq("auth_user_id", newUser.user!.id).single();

    // Insert into students
    const { error: studentError } = await supabaseAdmin.from("students").insert({
      user_id: publicUser!.id,
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
