// Edge Function: publish_results
// Handles: Grade calculation, marking results as published, and updating exam is_published flag.
// Invoked by: Admin or Teacher

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function computeGrade(percentage: number): string {
  if (percentage >= 90) return "A+";
  if (percentage >= 80) return "A";
  if (percentage >= 70) return "B";
  if (percentage >= 60) return "C";
  if (percentage >= 50) return "D";
  return "F";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { exam_id } = await req.json();
    if (!exam_id) throw new Error("exam_id is required");

    // Fetch all results for the exam
    const { data: results, error: fetchError } = await supabaseAdmin
      .from("results")
      .select("id, marks_obtained, total_marks")
      .eq("exam_id", exam_id);
    if (fetchError) throw fetchError;

    // Compute and update grades
    for (const result of results ?? []) {
      const pct = result.total_marks > 0
        ? (result.marks_obtained / result.total_marks) * 100
        : 0;
      await supabaseAdmin
        .from("results")
        .update({ grade: computeGrade(pct) })
        .eq("id", result.id);
    }

    // Mark exam as published
    const { error: publishError } = await supabaseAdmin
      .from("exams")
      .update({ is_published: true, published_at: new Date().toISOString() })
      .eq("id", exam_id);
    if (publishError) throw publishError;

    return new Response(JSON.stringify({ success: true, published_results: results?.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
