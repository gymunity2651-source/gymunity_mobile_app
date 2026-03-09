import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type ChatPayload = {
  session_id?: string;
  message?: string;
  context?: Record<string, unknown>;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const openAiApiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
    const openAiModel = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

    if (!supabaseUrl || !supabaseServiceRoleKey || !openAiApiKey) {
      return new Response(
        JSON.stringify({
          error:
            "Missing required env vars: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, OPENAI_API_KEY",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const authHeader = req.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "").trim();
    if (!token) {
      return new Response(JSON.stringify({ error: "Missing auth token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    });

    const { data: authData, error: authError } = await supabase.auth.getUser(
      token,
    );
    if (authError || !authData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload = (await req.json()) as ChatPayload;
    const sessionId = payload.session_id;
    const userMessage = payload.message?.trim();

    if (!sessionId || !userMessage) {
      return new Response(
        JSON.stringify({ error: "session_id and message are required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const { data: session, error: sessionError } = await supabase
      .from("chat_sessions")
      .select("id,user_id")
      .eq("id", sessionId)
      .single();

    if (sessionError || !session || session.user_id !== authData.user.id) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: historyRows } = await supabase
      .from("chat_messages")
      .select("sender,content")
      .eq("session_id", sessionId)
      .order("created_at", { ascending: false })
      .limit(12);

    const history = (historyRows ?? []).reverse().map((row) => ({
      role: row.sender === "user" ? "user" : "assistant",
      content: row.content,
    }));

    const lastHistoryMessage = history.length > 0 ? history[history.length - 1] : null;
    const shouldAppendUserMessage =
      !lastHistoryMessage ||
      lastHistoryMessage.role !== "user" ||
      lastHistoryMessage.content !== userMessage;

    const promptMessages = [
      {
        role: "system",
        content:
          "You are GymUnity AI. Give safe, practical fitness guidance. Keep answers concise and actionable.",
      },
      ...history,
      ...(shouldAppendUserMessage
        ? [{ role: "user" as const, content: userMessage }]
        : []),
    ];

    const openAiResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openAiApiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: openAiModel,
          temperature: 0.3,
          messages: promptMessages,
        }),
      },
    );

    if (!openAiResponse.ok) {
      const errorBody = await openAiResponse.text();
      return new Response(
        JSON.stringify({
          error: "LLM request failed",
          details: errorBody,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const completion = await openAiResponse.json();
    const assistantMessage =
      completion?.choices?.[0]?.message?.content?.trim() ||
      "I could not generate a response right now.";

    await supabase
      .from("chat_sessions")
      .update({ updated_at: new Date().toISOString() })
      .eq("id", sessionId);

    return new Response(
      JSON.stringify({
        assistant_message: assistantMessage,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: "Unhandled ai-chat function error",
        details: String(error),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
