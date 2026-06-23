// Edge Function: upload_assignment
// Handles: File validation, upload to Supabase Storage, and assignment record creation.
// Invoked by: Teacher

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const ALLOWED_TYPES = [
  "application/pdf",
  "image/jpeg",
  "image/png",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
];

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const formData = await req.formData();
    const file = formData.get("file") as File | null;
    const title = formData.get("title") as string;
    const description = formData.get("description") as string;
    const class_id = formData.get("class_id") as string;
    const teacher_id = formData.get("teacher_id") as string;
    const due_date = formData.get("due_date") as string;

    if (!file) throw new Error("No file provided");
    if (!ALLOWED_TYPES.includes(file.type)) throw new Error("Invalid file type");
    if (file.size > 20 * 1024 * 1024) throw new Error("File exceeds 20MB limit");

    // Build storage path
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
    const path = `${year}/${month}/${Date.now()}_${safeName}`;

    // Upload to storage
    const { error: uploadError } = await supabaseAdmin.storage
      .from("assignments")
      .upload(path, file, { contentType: file.type });
    if (uploadError) throw uploadError;

    // Get public URL
    const { data: { publicUrl } } = supabaseAdmin.storage.from("assignments").getPublicUrl(path);

    // Insert assignment record
    const { data: assignment, error: insertError } = await supabaseAdmin
      .from("assignments")
      .insert({ teacher_id, class_id, title, description, file_url: publicUrl, due_date })
      .select()
      .single();
    if (insertError) throw insertError;

    return new Response(JSON.stringify({ success: true, assignment }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
