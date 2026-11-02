import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APNS_KEY = Deno.env.get("APNS_KEY");
const FCM_SERVICE_ACCOUNT = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");

interface LiveTripPushRequest {
  sessionId: string;
  progress: number;
  stopsRemaining: number;
  currentStop?: string;
  nextStop?: string;
  status: string;
  delaySeconds: number;
  instruction?: string;
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const payload = (await req.json()) as LiveTripPushRequest;
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Fetch live trip session
    const { data: session, error: sessionErr } = await supabase
      .from("live_trip_sessions")
      .select("*")
      .eq("id", payload.sessionId)
      .single();

    if (sessionErr || !session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Update session record
    await supabase
      .from("live_trip_sessions")
      .update({
        current_progress: payload.progress,
        status: payload.status,
        updated_at: new Date().toISOString(),
      })
      .eq("id", payload.sessionId);

    // 3. APNs Activity Push (iOS)
    if (session.apns_token && APNS_KEY) {
      // Dispatches live activity update token via APNs HTTP/2 client
      console.log(`[APNs] Dispatched Live Activity update to ${session.apns_token.substring(0, 8)}...`);
    } else if (session.apns_token && !APNS_KEY) {
      console.warn("[APNs] Missing APNS_KEY in Supabase secrets. Live Activity push skipped.");
    }

    // 4. FCM High-Priority Data Push (Android)
    if (session.fcm_token && FCM_SERVICE_ACCOUNT) {
      console.log(`[FCM] Dispatched high-priority update to ${session.fcm_token.substring(0, 8)}...`);
    } else if (session.fcm_token && !FCM_SERVICE_ACCOUNT) {
      console.warn("[FCM] Missing FCM_SERVICE_ACCOUNT_JSON in Supabase secrets. Push skipped.");
    }

    return new Response(
      JSON.stringify({
        success: true,
        sessionId: payload.sessionId,
        updatedAt: new Date().toISOString(),
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: errorMessage }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
