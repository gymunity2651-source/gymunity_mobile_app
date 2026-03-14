import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";

type SessionType = "general" | "planner";
type TurnStatus =
  | "general_response"
  | "needs_more_info"
  | "plan_ready"
  | "plan_updated"
  | "unsafe_request";
type PlannerAction = "reply" | "regenerate_plan";
type LanguageCode = "en" | "ar";
type MeasurementUnit = "metric" | "imperial";

type PlannerProfile = {
  goal: string | null;
  experience_level: string | null;
  days_per_week: number | null;
  session_minutes: number | null;
  equipment: string[];
  limitations: string[];
  preferred_language: LanguageCode | null;
  measurement_unit: MeasurementUnit | null;
};

type PlanTask = {
  type: string;
  title: string;
  instructions: string;
  sets: number | null;
  reps: number | null;
  duration_minutes: number | null;
  target_value: number | null;
  target_unit: string | null;
  scheduled_time: string | null;
  reminder_time: string | null;
  is_required: boolean;
};

type PlanDay = {
  week_number: number;
  day_number: number;
  label: string;
  focus: string;
  tasks: PlanTask[];
};

type PlanWeek = {
  week_number: number;
  days: PlanDay[];
};

type NormalizedPlan = {
  title: string;
  summary: string;
  duration_weeks: number;
  level: string;
  start_date_suggestion: string | null;
  safety_notes: string[];
  rest_guidance: string | null;
  nutrition_guidance: string | null;
  hydration_guidance: string | null;
  sleep_guidance: string | null;
  step_target: string | null;
  weekly_structure: PlanWeek[];
};

type TurnResult = {
  assistant_message: string;
  status: TurnStatus;
  missing_fields: string[];
  extracted_profile: PlannerProfile;
  plan: NormalizedPlan | null;
  draft_id?: string | null;
  assistant_message_id?: string;
};

type SessionRecord = {
  id: string;
  user_id: string;
  title: string | null;
  session_type: SessionType;
  planner_status: string | null;
  planner_profile_json: unknown;
  latest_draft_id: string | null;
};

type HistoryMessage = {
  sender: string;
  content: string;
};

type PlannerContext = {
  role: string | null;
  member_profile: Record<string, unknown>;
  preferences: Record<string, unknown>;
  latest_weight: Record<string, unknown>;
  latest_measurement: Record<string, unknown>;
  recent_sessions: Record<string, unknown>[];
  active_ai_plan: Record<string, unknown>;
  prior_profile: PlannerProfile;
  current_draft: Record<string, unknown>;
};

const nullableStringSchema = { anyOf: [{ type: "string" }, { type: "null" }] };
const nullableIntegerSchema = { anyOf: [{ type: "integer" }, { type: "null" }] };
const nullableNumberSchema = { anyOf: [{ type: "number" }, { type: "null" }] };

const responseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    assistant_message: { type: "string" },
    status: {
      type: "string",
      enum: ["general_response", "needs_more_info", "plan_ready", "plan_updated", "unsafe_request"],
    },
    missing_fields: { type: "array", items: { type: "string" } },
    extracted_profile: { type: "object" },
    plan: {
      anyOf: [
        { type: "object" },
        { type: "null" },
      ],
    },
  },
  required: ["assistant_message", "status", "missing_fields", "extracted_profile", "plan"],
};

const planSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
    duration_weeks: { type: "integer" },
    level: { type: "string" },
    start_date_suggestion: nullableStringSchema,
    safety_notes: { type: "array", items: { type: "string" } },
    rest_guidance: nullableStringSchema,
    nutrition_guidance: nullableStringSchema,
    hydration_guidance: nullableStringSchema,
    sleep_guidance: nullableStringSchema,
    step_target: nullableStringSchema,
    weekly_structure: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          week_number: { type: "integer" },
          days: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                week_number: { type: "integer" },
                day_number: { type: "integer" },
                label: { type: "string" },
                focus: { type: "string" },
                tasks: {
                  type: "array",
                  items: {
                    type: "object",
                    additionalProperties: false,
                    properties: {
                      type: { type: "string" },
                      title: { type: "string" },
                      instructions: { type: "string" },
                      sets: nullableIntegerSchema,
                      reps: nullableIntegerSchema,
                      duration_minutes: nullableIntegerSchema,
                      target_value: nullableNumberSchema,
                      target_unit: nullableStringSchema,
                      scheduled_time: nullableStringSchema,
                      reminder_time: nullableStringSchema,
                      is_required: { type: "boolean" },
                    },
                    required: ["type", "title", "instructions", "sets", "reps", "duration_minutes", "target_value", "target_unit", "scheduled_time", "reminder_time", "is_required"],
                  },
                },
              },
              required: ["week_number", "day_number", "label", "focus", "tasks"],
            },
          },
        },
        required: ["week_number", "days"],
      },
    },
  },
  required: ["title", "summary", "duration_weeks", "level", "start_date_suggestion", "safety_notes", "rest_guidance", "nutrition_guidance", "hydration_guidance", "sleep_guidance", "step_target", "weekly_structure"],
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const supabase = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
      auth: { persistSession: false },
    });
    const apiKey = env("GROQ_API_KEY");
    const model = Deno.env.get("GROQ_MODEL")?.trim() || "openai/gpt-oss-120b";
    const user = await authUser(supabase, bearer(req));
    const body = obj(await req.json().catch(() => ({})));
    const actionValue = str(body.action) || "reply";
    if (actionValue !== "reply" && actionValue !== "regenerate_plan") {
      return jsonResponse({ error: "Unsupported action." }, 400);
    }
    const action: PlannerAction = actionValue;
    const sessionId = str(body.session_id);
    if (!sessionId) return jsonResponse({ error: "session_id is required." }, 400);

    const session = await getSession(supabase, sessionId, user.id);
    const ctx = await getContext(supabase, user.id, session);
    if (session.session_type === "planner" && ctx.role !== "member") {
      return jsonResponse({ error: "AI planning is available for member accounts only." }, 403);
    }

    let replyToMessageId = null;
    let regenerateFromDraftId = null;
    let draftRef: Record<string, unknown> | null = null;
    if (action === "reply") {
      replyToMessageId = str(body.message_id);
      if (!replyToMessageId) return jsonResponse({ error: "message_id is required for reply." }, 400);
      await requireUserMessage(supabase, sessionId, replyToMessageId);
      const existing = await existingAssistantReply(supabase, sessionId, replyToMessageId);
      if (existing) return jsonResponse(existing);
    } else {
      regenerateFromDraftId = str(body.draft_id);
      if (!regenerateFromDraftId) {
        return jsonResponse({ error: "draft_id is required for regenerate_plan." }, 400);
      }
      draftRef = await getDraft(supabase, regenerateFromDraftId, sessionId, user.id);
    }

    const history = await getHistory(supabase, sessionId, 18);
    const systemPrompt = session.session_type === "planner"
      ? plannerPrompt(ctx, action, draftRef)
      : generalPrompt(ctx);
    const extraUserInstruction = action === "regenerate_plan" && draftRef
      ? `Regenerate the plan using this current draft JSON: ${JSON.stringify(draftRef)}`
      : null;
    const raw = await groqJson({ apiKey, model, systemPrompt, history, extraUserInstruction });
    let turn = session.session_type === "planner"
      ? sanitizePlanner(raw, ctx, action === "regenerate_plan")
      : sanitizeGeneral(raw);
    if (
      session.session_type === "planner" &&
      turn.status === "needs_more_info" &&
      turn.missing_fields.length === 0 &&
      !turn.plan
    ) {
      const forcedPlan = await groqPlanJson({
        apiKey,
        model,
        ctx,
        profile: turn.extracted_profile,
        draftRef,
      });
      const normalizedPlan = normalizePlan(forcedPlan);
      if (normalizedPlan) {
        turn = {
          ...turn,
          status: action === "regenerate_plan" ? "plan_updated" : "plan_ready",
          plan: normalizedPlan,
          assistant_message: turn.assistant_message || defaultAssistant(action === "regenerate_plan" ? "plan_updated" : "plan_ready"),
        };
      }
    }

    let draftId: string | null = null;
    if (session.session_type === "planner") {
      draftId = await saveDraft(supabase, user.id, sessionId, turn);
    }
    const response: TurnResult = { ...turn, draft_id: draftId };

    const metadata = {
      planner_status: response.status,
      draft_id: draftId,
      missing_fields: response.missing_fields,
      extracted_profile: response.extracted_profile,
      plan: response.plan,
      turn_result: response,
      reply_to_message_id: replyToMessageId,
      regenerated_from_draft_id: regenerateFromDraftId,
    };
    const { data: assistantRow, error: assistantError } = await supabase
      .from("chat_messages")
      .insert({ session_id: sessionId, sender: "assistant", content: response.assistant_message, metadata })
      .select("id")
      .single();
    if (assistantError || !assistantRow?.id) throw new Error(assistantError?.message || "Unable to save AI response.");

    const finalResponse: TurnResult = {
      ...response,
      assistant_message_id: String(assistantRow.id),
    };
    await updateSession(supabase, session, finalResponse, draftId, history);
    return jsonResponse(finalResponse);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const status = errorStatus(message);
    return jsonResponse(
      {
        error: publicError(message, status),
        details: status >= 500 || status === 429 ? message : undefined,
      },
      status,
    );
  }
});

function env(name: string) {
  const value = Deno.env.get(name)?.trim() || "";
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function errorStatus(message: string) {
  const lower = message.toLowerCase();
  if (message === "Unauthorized" || message === "Missing auth token") return 401;
  if (lower.includes("member accounts only")) return 403;
  if (lower.includes("not found")) return 404;
  if (
    lower.includes("\"code\": 429") ||
    lower.includes("quota exceeded") ||
    lower.includes("resource_exhausted") ||
    lower.includes("rate limit")
  ) {
    return 429;
  }
  return 500;
}

function publicError(message: string, status: number) {
  if (status === 429) {
    return "Groq API quota or rate limit is exhausted for the configured API key.";
  }
  return status >= 500 ? "Unhandled ai-chat function error" : message;
}

function bearer(req: Request) {
  const token = req.headers.get("Authorization")?.replace("Bearer ", "").trim();
  if (!token) throw new Error("Missing auth token");
  return token;
}
async function authUser(supabase: SupabaseClient, token: string) {
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) throw new Error("Unauthorized");
  return data.user;
}
function str(v: unknown) {
  return typeof v === "string" && v.trim() ? v.trim() : null;
}
function obj(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" && !Array.isArray(v) ? v as Record<string, unknown> : {};
}
function strings(v: unknown): string[] {
  return Array.isArray(v)
    ? Array.from(
        new Set(
          v
            .map((item: unknown) => String(item || "").trim())
            .filter(Boolean),
        ),
      )
    : [];
}
function posInt(v: unknown) {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) && n > 0 ? Math.round(n) : null;
}
function nonNegInt(v: unknown) {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) && n >= 0 ? Math.round(n) : null;
}
function nonNegNum(v: unknown) {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) && n >= 0 ? n : null;
}
function clamp(n: number, min: number, max: number) { return Math.min(max, Math.max(min, n)); }
function time(v: unknown) {
  const s = str(v);
  if (!s) return null;
  const m = s.match(/^(\d{1,2}):(\d{2})/);
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  return h >= 0 && h <= 23 && min >= 0 && min <= 59 ? `${String(h).padStart(2, "0")}:${String(min).padStart(2, "0")}` : null;
}
function dateOnly(v: unknown) {
  const s = str(v);
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d.toISOString().split("T")[0];
}
function parseJson(s: string): unknown { try { return JSON.parse(s); } catch { return null; } }

async function getSession(
  supabase: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<SessionRecord> {
  const { data, error } = await supabase
    .from("chat_sessions")
    .select("id,user_id,title,session_type,planner_status,planner_profile_json,latest_draft_id")
    .eq("id", sessionId)
    .single();
  const row = obj(data);
  if (error || !data || str(row.user_id) !== userId) throw new Error("Session not found.");
  return {
    id: str(row.id) || sessionId,
    user_id: userId,
    title: str(row.title),
    session_type: row.session_type === "planner" ? "planner" : "general",
    planner_status: str(row.planner_status),
    planner_profile_json: row.planner_profile_json,
    latest_draft_id: str(row.latest_draft_id),
  };
}
async function requireUserMessage(supabase: SupabaseClient, sessionId: string, messageId: string) {
  const { data, error } = await supabase
    .from("chat_messages")
    .select("id")
    .eq("id", messageId)
    .eq("session_id", sessionId)
    .eq("sender", "user")
    .single();
  if (error || !data) throw new Error("User message not found.");
}
async function getDraft(supabase: SupabaseClient, draftId: string, sessionId: string, userId: string) {
  const { data, error } = await supabase
    .from("ai_plan_drafts")
    .select("id,status,assistant_message,missing_fields,extracted_profile_json,plan_json")
    .eq("id", draftId)
    .eq("session_id", sessionId)
    .eq("user_id", userId)
    .single();
  if (error || !data) throw new Error("Planner draft not found.");
  return obj(data);
}
async function existingAssistantReply(
  supabase: SupabaseClient,
  sessionId: string,
  messageId: string,
): Promise<TurnResult | null> {
  const { data } = await supabase
    .from("chat_messages")
    .select("id,content,metadata")
    .eq("session_id", sessionId)
    .eq("sender", "assistant")
    .order("created_at", { ascending: false })
    .limit(20);
  for (const row of data || []) {
    const messageRow = obj(row);
    const metadata = obj(messageRow.metadata);
    if (str(metadata.reply_to_message_id) !== messageId) continue;
    const turn = obj(metadata.turn_result);
    return {
      assistant_message: str(turn.assistant_message) || str(messageRow.content) || "I could not generate a response right now.",
      status: toStatus(str(turn.status) || str(metadata.planner_status)) || "general_response",
      missing_fields: strings(turn.missing_fields || metadata.missing_fields),
      extracted_profile: normalizeProfile(turn.extracted_profile || metadata.extracted_profile, null),
      plan: normalizePlan(turn.plan || metadata.plan),
      draft_id: str(turn.draft_id || metadata.draft_id),
      assistant_message_id: str(messageRow.id) || undefined,
    };
  }
  return null;
}
async function getHistory(
  supabase: SupabaseClient,
  sessionId: string,
  limit: number,
): Promise<HistoryMessage[]> {
  const { data } = await supabase
    .from("chat_messages")
    .select("sender,content")
    .eq("session_id", sessionId)
    .order("created_at", { ascending: false })
    .limit(limit);
  return (data || [])
    .slice()
    .reverse()
    .map((row: unknown): HistoryMessage => {
      const value = obj(row);
      return {
        sender: str(value.sender) || "",
        content: str(value.content) || "",
      };
    })
    .filter((row) => row.sender.length > 0);
}
async function getContext(
  supabase: SupabaseClient,
  userId: string,
  session: SessionRecord,
): Promise<PlannerContext> {
  const [profileRes, memberRes, prefsRes, weightRes, measurementRes, sessionsRes, activePlanRes, currentDraftRes] = await Promise.all([
    supabase.from("profiles").select("role_id,roles(code)").eq("user_id", userId).maybeSingle(),
    supabase.from("member_profiles").select("*").eq("user_id", userId).maybeSingle(),
    supabase.from("user_preferences").select("*").eq("user_id", userId).maybeSingle(),
    supabase.from("member_weight_entries").select("weight_kg,recorded_at").eq("member_id", userId).order("recorded_at", { ascending: false }).limit(1).maybeSingle(),
    supabase.from("member_body_measurements").select("recorded_at,waist_cm,chest_cm,hips_cm,arm_cm,thigh_cm,body_fat_percent").eq("member_id", userId).order("recorded_at", { ascending: false }).limit(1).maybeSingle(),
    supabase.from("workout_sessions").select("title,performed_at,duration_minutes,workout_plan_id").eq("member_id", userId).order("performed_at", { ascending: false }).limit(3),
    supabase.from("workout_plans").select("id,title,plan_json,start_date,end_date").eq("member_id", userId).eq("source", "ai").eq("status", "active").order("assigned_at", { ascending: false }).limit(1).maybeSingle(),
    str(session.latest_draft_id)
      ? supabase.from("ai_plan_drafts").select("id,status,assistant_message,missing_fields,extracted_profile_json,plan_json").eq("id", String(session.latest_draft_id)).eq("user_id", userId).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);
  const priorProfile = normalizeProfile(session.planner_profile_json, null);
  const prefs = obj(prefsRes.data);
  if (!priorProfile.preferred_language) priorProfile.preferred_language = lang(prefs.language);
  if (!priorProfile.measurement_unit) priorProfile.measurement_unit = unit(prefs.measurement_unit);
  if (!priorProfile.goal) priorProfile.goal = str(obj(memberRes.data).goal);
  if (!priorProfile.experience_level) priorProfile.experience_level = levelish(obj(memberRes.data).experience_level);
  return {
    role: str(obj(profileRes.data?.roles).code),
    member_profile: obj(memberRes.data),
    preferences: prefs,
    latest_weight: obj(weightRes.data),
    latest_measurement: obj(measurementRes.data),
    recent_sessions: Array.isArray(sessionsRes.data)
      ? sessionsRes.data.map((sessionRow: unknown) => obj(sessionRow))
      : [],
    active_ai_plan: obj(activePlanRes.data),
    prior_profile: priorProfile,
    current_draft: obj(currentDraftRes.data),
  };
}

function generalPrompt(ctx: PlannerContext) {
  const language = ctx.prior_profile.preferred_language === "ar" ? "Arabic" : "English";
  return [
    "You are GymUnity AI, a concise and practical fitness assistant.",
    "Do not mention your backend provider, model vendor, or API platform.",
    "Avoid diagnosis and unsafe medical advice. If there is a medical-risk request, advise consulting a qualified professional.",
    `Respond in ${language}.`,
    "Return only JSON matching the schema. Use status 'general_response'. Leave missing_fields empty and plan null.",
    `Known member context JSON: ${JSON.stringify({ member_profile: ctx.member_profile, preferences: ctx.preferences, latest_weight: ctx.latest_weight, latest_measurement: ctx.latest_measurement, recent_sessions: ctx.recent_sessions })}`,
  ].join("\n");
}
function plannerPrompt(
  ctx: PlannerContext,
  action: PlannerAction,
  draftRef: Record<string, unknown> | null,
) {
  const language = ctx.prior_profile.preferred_language === "ar" ? "Arabic" : "English";
  const measurement = ctx.prior_profile.measurement_unit || "metric";
  return [
    "You are GymUnity Planner, a safe production fitness planning assistant for members.",
    "Ask only for information that is truly missing. Reuse the supplied context and avoid redundant questions.",
    "Critical fields before finalizing a plan: goal, experience_level, days_per_week, session_minutes, equipment.",
    "If critical data is missing, use status 'needs_more_info' and ask the next concise follow-up question.",
    "If a request is medically risky or asks for diagnosis, use status 'unsafe_request' and do not produce a plan.",
    "If enough information exists, you must return status 'plan_ready' or 'plan_updated' and populate the full plan object.",
    "Do not leave plan null once the critical planning fields are available.",
    "Return a realistic day-by-day plan with conservative volume for beginners, safety notes, rest guidance, and trackable tasks.",
    `Respond in ${language}. Use ${measurement} units.`,
    action === "regenerate_plan" ? "This is a regenerate request. Return a full updated plan if enough information exists." : "This is a normal conversation turn.",
    "Return only JSON matching the schema.",
    `Member context JSON: ${JSON.stringify({ member_profile: ctx.member_profile, preferences: ctx.preferences, latest_weight: ctx.latest_weight, latest_measurement: ctx.latest_measurement, recent_sessions: ctx.recent_sessions, active_ai_plan: ctx.active_ai_plan, prior_profile: ctx.prior_profile, current_draft: ctx.current_draft, referenced_draft: draftRef })}`,
  ].join("\n");
}
function forcePlanInstruction(
  profile: PlannerProfile,
  draftRef: Record<string, unknown> | null,
) {
  return [
    "All critical planning fields are already available.",
    "Return a full structured plan now.",
    "Set status to 'plan_ready' unless this is clearly a regenerate request, in which case set 'plan_updated'.",
    "Do not ask any follow-up question.",
    `Use this extracted profile JSON: ${JSON.stringify(profile)}`,
    `Use this referenced draft JSON if available: ${JSON.stringify(draftRef || {})}`,
  ].join("\n");
}
function planOnlyPrompt(
  ctx: PlannerContext,
  profile: PlannerProfile,
  draftRef: Record<string, unknown> | null,
) {
  const language = profile.preferred_language === "ar" ? "Arabic" : "English";
  const measurement = profile.measurement_unit || "metric";
  return [
    "You are GymUnity Planner.",
    "All critical planning fields are already known.",
    "Return only a full structured plan JSON matching the requested schema.",
    "Do not ask follow-up questions and do not return any prose outside the JSON.",
    "Keep the plan practical, day-by-day, conservative for beginners, and safe.",
    `Respond in ${language}. Use ${measurement} units.`,
    `Use this extracted profile JSON: ${JSON.stringify(profile)}`,
    `Use this broader context JSON: ${JSON.stringify({ member_profile: ctx.member_profile, preferences: ctx.preferences, latest_weight: ctx.latest_weight, latest_measurement: ctx.latest_measurement, recent_sessions: ctx.recent_sessions, active_ai_plan: ctx.active_ai_plan, current_draft: ctx.current_draft, referenced_draft: draftRef })}`,
  ].join("\n");
}

async function groqJson(input: {
  apiKey: string;
  model: string;
  systemPrompt: string;
  history: HistoryMessage[];
  extraUserInstruction: string | null;
}): Promise<Record<string, unknown>> {
  const base = await groqRequest(input.apiKey, {
    model: input.model,
    messages: [
      { role: "system", content: input.systemPrompt },
      ...input.history.map((message) => ({
        role: message.sender === "user" ? "user" : "assistant",
        content: String(message.content || ""),
      })),
      ...(input.extraUserInstruction ? [{ role: "user", content: input.extraUserInstruction }] : []),
    ],
    temperature: 0.2,
    max_tokens: 2200,
    include_reasoning: false,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "gymunity_turn",
        strict: false,
        schema: responseSchema,
      },
    },
  });
  const body = await base.text();
  if (!base.ok) throw new Error(`Groq request failed: ${body}`);
  const text = choiceText(parseJson(body));
  const direct = text ? parseTurn(text) : null;
  if (direct) return direct;
  const repair = await groqRequest(input.apiKey, {
    model: input.model,
    messages: [
      {
        role: "system",
        content: "Repair malformed JSON into valid JSON matching the required schema. Return only JSON.",
      },
      { role: "user", content: `Malformed JSON:\n${text || body}` },
    ],
    temperature: 0,
    max_tokens: 2200,
    include_reasoning: false,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "gymunity_turn_repair",
        strict: false,
        schema: responseSchema,
      },
    },
  });
  const repairBody = await repair.text();
  if (!repair.ok) throw new Error(`Groq repair request failed: ${repairBody}`);
  const repaired = choiceText(parseJson(repairBody));
  const parsed = repaired ? parseTurn(repaired) : null;
  if (!parsed) throw new Error("Groq returned malformed structured output.");
  return parsed;
}
async function groqPlanJson(input: {
  apiKey: string;
  model: string;
  ctx: PlannerContext;
  profile: PlannerProfile;
  draftRef: Record<string, unknown> | null;
}): Promise<Record<string, unknown>> {
  const base = await groqRequest(input.apiKey, {
    model: input.model,
    messages: [
      { role: "system", content: planOnlyPrompt(input.ctx, input.profile, input.draftRef) },
    ],
    temperature: 0.2,
    max_tokens: 2600,
    include_reasoning: false,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "gymunity_plan",
        strict: false,
        schema: planSchema,
      },
    },
  });
  const body = await base.text();
  if (!base.ok) throw new Error(`Groq plan request failed: ${body}`);
  const parsed = parseTurn(choiceText(parseJson(body)));
  if (!Object.keys(parsed).length) throw new Error("Groq returned an empty plan payload.");
  return parsed;
}
async function groqRequest(apiKey: string, payload: Record<string, unknown>): Promise<Response> {
  let attempt = 0;
  while (true) {
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
    if (response.status !== 429 || attempt >= 2) {
      return response;
    }
    const waitMs = retryDelayMs(response.headers.get("retry-after"), attempt);
    await sleep(waitMs);
    attempt += 1;
  }
}
function retryDelayMs(retryAfter: string | null, attempt: number) {
  const parsedSeconds = Number(retryAfter);
  if (Number.isFinite(parsedSeconds) && parsedSeconds > 0) {
    return Math.round(parsedSeconds * 1000);
  }
  return 1500 * (attempt + 1);
}
function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
function choiceText(data: unknown): string {
  const choices = Array.isArray(obj(data).choices) ? obj(data).choices as unknown[] : [];
  for (const choice of choices) {
    const message = obj(obj(choice).message);
    const direct = str(message.content);
    if (direct) return direct;

    const contentParts = Array.isArray(message.content) ? message.content as unknown[] : [];
    const text = contentParts
      .map((part: unknown) => str(obj(part).text))
      .filter(Boolean)
      .join("\n")
      .trim();
    if (text) return text;
  }
  return "";
}
function parseTurn(text: string): Record<string, unknown> {
  return obj(parseJson(text.replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(/```$/i, "").trim()));
}

function sanitizeGeneral(raw: Record<string, unknown>): TurnResult {
  return {
    assistant_message: str(raw.assistant_message) || "I could not generate a response right now.",
    status: "general_response",
    missing_fields: [],
    extracted_profile: emptyProfile(),
    plan: null,
  };
}
function sanitizePlanner(
  raw: Record<string, unknown>,
  ctx: PlannerContext,
  regenerated: boolean,
): TurnResult {
  const profile = normalizeProfile(raw.extracted_profile, ctx.prior_profile);
  const missing = Array.from(new Set([...criticalMissing(profile), ...strings(raw.missing_fields)]));
  let status = toStatus(str(raw.status)) || "needs_more_info";
  let plan = normalizePlan(raw.plan);
  if (status === "unsafe_request") plan = null;
  else if (missing.length) { status = "needs_more_info"; plan = null; }
  else if (plan) status = regenerated ? "plan_updated" : "plan_ready";
  else status = "needs_more_info";
  return {
    assistant_message: str(raw.assistant_message) || defaultAssistant(status),
    status,
    missing_fields: status === "unsafe_request" ? [] : missing,
    extracted_profile: profile,
    plan,
  };
}
function defaultAssistant(status: string) {
  if (status === "unsafe_request") return "This request needs a safer path. Please consult a qualified professional before acting on it.";
  if (status === "plan_ready" || status === "plan_updated") return "Your plan is ready to review.";
  return "I need a little more information before I can generate the plan.";
}
function persistencePlannerStatus(status: TurnStatus) {
  if (status === "needs_more_info") return "collecting_info";
  return status;
}
function emptyProfile(): PlannerProfile {
  return { goal: null, experience_level: null, days_per_week: null, session_minutes: null, equipment: [], limitations: [], preferred_language: null, measurement_unit: null };
}
function toStatus(value: string | null): TurnStatus | null {
  if (
    value === "general_response" ||
    value === "needs_more_info" ||
    value === "plan_ready" ||
    value === "plan_updated" ||
    value === "unsafe_request"
  ) {
    return value;
  }
  return null;
}
function lang(v: unknown): LanguageCode | null { const s = str(v)?.toLowerCase(); return s === "arabic" || s === "ar" ? "ar" : s === "english" || s === "en" ? "en" : null; }
function unit(v: unknown): MeasurementUnit | null { const s = str(v)?.toLowerCase(); return s === "metric" || s === "imperial" ? s : null; }
function levelish(v: unknown) { const s = str(v)?.toLowerCase(); return s === "beginner" || s === "intermediate" || s === "advanced" ? s : s === "athlete" ? "advanced" : null; }
function normalizeProfile(raw: unknown, base: PlannerProfile | null): PlannerProfile {
  const r = obj(raw);
  const b = base || emptyProfile();
  const profile = {
    goal: str(r.goal) || str(b.goal),
    experience_level: levelish(r.experience_level) || levelish(b.experience_level),
    days_per_week: posInt(r.days_per_week) || posInt(b.days_per_week),
    session_minutes: posInt(r.session_minutes) || posInt(b.session_minutes),
    equipment: strings(r.equipment).length ? strings(r.equipment) : strings(b.equipment),
    limitations: r.limitations === undefined ? strings(b.limitations) : strings(r.limitations),
    preferred_language: lang(r.preferred_language) || lang(b.preferred_language),
    measurement_unit: unit(r.measurement_unit) || unit(b.measurement_unit),
  };
  return profile;
}
function criticalMissing(profile: PlannerProfile): string[] {
  const out: string[] = [];
  if (!str(profile.goal)) out.push("goal");
  if (!str(profile.experience_level)) out.push("experience_level");
  if (!posInt(profile.days_per_week)) out.push("days_per_week");
  if (!posInt(profile.session_minutes)) out.push("session_minutes");
  if (strings(profile.equipment).length === 0) out.push("equipment");
  return out;
}
function normalizePlan(raw: unknown): NormalizedPlan | null {
  const r = obj(raw);
  const weeks = Array.isArray(r.weekly_structure)
    ? r.weekly_structure
        .map((week: unknown, index: number) => normalizeWeek(week, index + 1))
        .filter((week): week is PlanWeek => week !== null)
    : [];
  if (!weeks.length) return null;
  return {
    title: str(r.title) || "AI Workout Plan",
    summary: str(r.summary) || "",
    duration_weeks: clamp(posInt(r.duration_weeks) || weeks.length, 1, 24),
    level: levelish(r.level) || "beginner",
    start_date_suggestion: dateOnly(r.start_date_suggestion),
    safety_notes: strings(r.safety_notes),
    rest_guidance: str(r.rest_guidance),
    nutrition_guidance: str(r.nutrition_guidance),
    hydration_guidance: str(r.hydration_guidance),
    sleep_guidance: str(r.sleep_guidance),
    step_target: str(r.step_target),
    weekly_structure: weeks,
  };
}
function normalizeWeek(raw: unknown, fallbackWeek: number): PlanWeek | null {
  const r = obj(raw);
  const weekNumber = clamp(posInt(r.week_number) || fallbackWeek, 1, 24);
  const days = Array.isArray(r.days)
    ? r.days
        .map((day: unknown, index: number) => normalizeDay(day, weekNumber, index + 1))
        .filter((day): day is PlanDay => day !== null)
    : [];
  return days.length ? { week_number: weekNumber, days } : null;
}
function normalizeDay(raw: unknown, weekNumber: number, fallbackDay: number): PlanDay | null {
  const r = obj(raw);
  const tasks = Array.isArray(r.tasks)
    ? r.tasks
        .map((task: unknown) => normalizeTask(task))
        .filter((task): task is PlanTask => task !== null)
    : [];
  return {
    week_number: clamp(posInt(r.week_number) || weekNumber, 1, 24),
    day_number: clamp(posInt(r.day_number) || fallbackDay, 1, 7),
    label: str(r.label) || `Day ${fallbackDay}`,
    focus: str(r.focus) || "",
    tasks,
  };
}
function normalizeTask(raw: unknown): PlanTask | null {
  const r = obj(raw);
  const title = str(r.title);
  if (!title) return null;
  const type = ["workout", "cardio", "mobility", "nutrition", "hydration", "sleep", "steps", "recovery", "measurement"].includes(String(r.type || "").trim().toLowerCase()) ? String(r.type).trim().toLowerCase() : "workout";
  return {
    type,
    title,
    instructions: str(r.instructions) || "",
    sets: nonNegInt(r.sets),
    reps: nonNegInt(r.reps),
    duration_minutes: nonNegInt(r.duration_minutes),
    target_value: nonNegNum(r.target_value),
    target_unit: str(r.target_unit),
    scheduled_time: time(r.scheduled_time),
    reminder_time: time(r.reminder_time),
    is_required: typeof r.is_required === "boolean" ? r.is_required : true,
  };
}
async function saveDraft(
  supabase: SupabaseClient,
  userId: string,
  sessionId: string,
  turn: TurnResult,
) {
  const { data, error } = await supabase.from("ai_plan_drafts").insert({
    user_id: userId,
    session_id: sessionId,
    status: persistencePlannerStatus(turn.status),
    assistant_message: turn.assistant_message,
    missing_fields: turn.missing_fields,
    extracted_profile_json: turn.extracted_profile,
    plan_json: turn.plan || {},
  }).select("id").single();
  if (error || !data?.id) throw new Error(error?.message || "Unable to persist AI plan draft.");
  return String(data.id);
}
async function updateSession(
  supabase: SupabaseClient,
  session: SessionRecord,
  turn: TurnResult,
  draftId: string | null,
  history: HistoryMessage[],
) {
  const defaultTitles = new Set(["New chat", "AI Plan", "AI Planner"]);
  const latestUser = [...history].reverse().find((m) => m.sender === "user");
  const nextTitle = turn.plan?.title
    || (!defaultTitles.has(session.title || "") ? session.title : latestUser?.content)
    || (session.session_type === "planner" ? "AI Planner" : "New chat");
  const patch: Record<string, unknown> = { updated_at: new Date().toISOString(), title: nextTitle?.slice(0, 80) || "New chat" };
  if (session.session_type === "planner") {
    patch.planner_status = persistencePlannerStatus(turn.status);
    patch.latest_draft_id = draftId;
    patch.planner_profile_json = turn.extracted_profile;
  }
  const { error } = await supabase.from("chat_sessions").update(patch).eq("id", session.id);
  if (error) throw new Error(error.message);
}
