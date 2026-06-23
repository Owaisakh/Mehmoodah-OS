// Edge Function: generate_report
// Handles: Data aggregation for attendance and result reports (stub – PDF rendering added in Phase 7)
// Invoked by: Admin

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

    const { report_type, class_id, student_id, from_date, to_date } = await req.json();

    let data: unknown = null;

    if (report_type === "attendance") {
      const query = supabaseAdmin
        .from("attendance")
        .select("date, status, students(student_code, users(full_name))")
        .gte("date", from_date)
        .lte("date", to_date);
      if (class_id) query.eq("class_id", class_id);
      if (student_id) query.eq("student_id", student_id);
      const { data: rows, error } = await query;
      if (error) throw error;
      data = rows;
    } else if (report_type === "results") {
      const { data: rows, error } = await supabaseAdmin
        .from("results")
        .select("subject, marks_obtained, total_marks, grade, exams(name, term), students(student_code, users(full_name))")
        .eq(student_id ? "student_id" : "exam_id", student_id ?? class_id);
      if (error) throw error;
      data = rows;
    } else {
      throw new Error("Invalid report_type. Must be 'attendance' or 'results'.");
    }

    return new Response(JSON.stringify({ success: true, data }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
