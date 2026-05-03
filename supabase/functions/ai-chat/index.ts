import {
  createClient,
  type SupabaseClient,
} from "https://esm.sh/@supabase/supabase-js@2";

import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  buildMemoryPayload,
  buildPersonalizationUsed,
  buildSuggestedReplies,
  clamp,
  classifyConversationMode,
  compactPlan,
  type ConversationMode,
  criticalMissing,
  dateOnly,
  deriveSignals,
  levelish,
  memoryRowsToPayload,
  mergeProfileSources,
  nonNegInt,
  nonNegNum,
  obj,
  type PlannerAction,
  type PlannerContextLike,
  type PlannerProfile,
  posInt,
  type SessionType,
  str,
  strings,
  summarizeSessionState,
  time,
  type TurnStatus,
} from "./engine.ts";

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
  conversation_mode: ConversationMode;
  personalization_used: string[];
  suggested_replies: string[];
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

type ProviderResponse = {
  payload: Record<string, unknown>;
  provider: string;
  model: string;
};

type ProviderCallInput = {
  systemPrompt: string;
  history: HistoryMessage[];
  extraUserInstruction: string | null;
  schema: Record<string, unknown>;
  maxTokens: number;
  temperature: number;
};

type PlannerContext = PlannerContextLike & {
  role: string | null;
  profile_basics: Record<string, unknown>;
  memory_rows: Record<string, unknown>[];
};

const nullableStringSchema = { anyOf: [{ type: "string" }, { type: "null" }] };
const nullableIntegerSchema = {
  anyOf: [{ type: "integer" }, { type: "null" }],
};
const nullableNumberSchema = { anyOf: [{ type: "number" }, { type: "null" }] };

const memoryUpdateSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    preferred_days: { type: "array", items: { type: "string" } },
    exercise_dislikes: { type: "array", items: { type: "string" } },
    response_style: nullableStringSchema,
    preferred_language: nullableStringSchema,
    measurement_unit: nullableStringSchema,
  },
};

const responseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    assistant_message: { type: "string" },
    status: {
      type: "string",
      enum: [
        "general_response",
        "needs_more_info",
        "plan_ready",
        "plan_updated",
        "unsafe_request",
      ],
    },
    missing_fields: { type: "array", items: { type: "string" } },
    extracted_profile: { type: "object" },
    plan: {
      anyOf: [
        { type: "object" },
        { type: "null" },
      ],
    },
    conversation_mode: {
      type: "string",
      enum: [
        "general_coaching",
        "planner_collect",
        "planner_generate",
        "planner_refine",
        "progress_checkin",
      ],
    },
    personalization_used: { type: "array", items: { type: "string" } },
    suggested_replies: { type: "array", items: { type: "string" } },
    memory_updates: memoryUpdateSchema,
  },
  required: [
    "assistant_message",
    "status",
    "missing_fields",
    "extracted_profile",
    "plan",
  ],
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
                    required: [
                      "type",
                      "title",
                      "instructions",
                      "sets",
                      "reps",
                      "duration_minutes",
                      "target_value",
                      "target_unit",
                      "scheduled_time",
                      "reminder_time",
                      "is_required",
                    ],
                  },
                },
              },
              required: [
                "week_number",
                "day_number",
                "label",
                "focus",
                "tasks",
              ],
            },
          },
        },
        required: ["week_number", "days"],
      },
    },
  },
  required: [
    "title",
    "summary",
    "duration_weeks",
    "level",
    "start_date_suggestion",
    "safety_notes",
    "rest_guidance",
    "nutrition_guidance",
    "hydration_guidance",
    "sleep_guidance",
    "step_target",
    "weekly_structure",
  ],
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const supabase = createClient(
      env("SUPABASE_URL"),
      env("SUPABASE_SERVICE_ROLE_KEY"),
      {
        auth: { persistSession: false },
      },
    );
    const user = await authUser(supabase, bearer(req));
    const body = obj(await req.json().catch(() => ({})));
    const actionValue = str(body.action) || "reply";
    if (actionValue !== "reply" && actionValue !== "regenerate_plan") {
      return jsonResponse({ error: "Unsupported action." }, 400);
    }
    const action: PlannerAction = actionValue;
    const sessionId = str(body.session_id);
    if (!sessionId) {
      return jsonResponse({ error: "session_id is required." }, 400);
    }

    const session = await getSession(supabase, sessionId, user.id);
    const ctx = await getContext(supabase, user.id, session);
    if (session.session_type === "planner" && ctx.role !== "member") {
      return jsonResponse({
        error: "AI planning is available for member accounts only.",
      }, 403);
    }

    let replyToMessageId: string | null = null;
    let regenerateFromDraftId: string | null = null;
    let draftRef: Record<string, unknown> | null = null;
    if (action === "reply") {
      replyToMessageId = str(body.message_id);
      if (!replyToMessageId) {
        return jsonResponse(
          { error: "message_id is required for reply." },
          400,
        );
      }
      await requireUserMessage(supabase, sessionId, replyToMessageId);
      const existing = await existingAssistantReply(
        supabase,
        sessionId,
        replyToMessageId,
      );
      if (existing) return jsonResponse(existing);
    } else {
      regenerateFromDraftId = str(body.draft_id);
      if (!regenerateFromDraftId) {
        return jsonResponse({
          error: "draft_id is required for regenerate_plan.",
        }, 400);
      }
      draftRef = await getDraft(
        supabase,
        regenerateFromDraftId,
        sessionId,
        user.id,
      );
    }

    const history = await getHistory(supabase, sessionId, 18);
    const latestUserMessage = [...history].reverse().find((message) =>
      message.sender === "user"
    )?.content || "";
    const initialMode = classifyConversationMode({
      sessionType: session.session_type,
      action,
      latestUserMessage,
      ctx,
      draftRef,
    });

    const systemPrompt = session.session_type === "planner"
      ? plannerPrompt(ctx, action, draftRef, initialMode)
      : generalPrompt(ctx, initialMode);
    const extraUserInstruction = action === "regenerate_plan" && draftRef
      ? `Refine the plan using this current draft JSON: ${
        JSON.stringify(compactDraft(draftRef))
      }`
      : null;

    const providerResult = await orchestrateStructuredJson({
      systemPrompt,
      history,
      extraUserInstruction,
      schema: responseSchema,
      maxTokens: 2200,
      temperature: 0.2,
    });

    let turn = session.session_type === "planner"
      ? sanitizePlanner(
        providerResult.payload,
        ctx,
        action === "regenerate_plan",
        initialMode,
      )
      : sanitizeGeneral(providerResult.payload, ctx, initialMode);

    if (
      session.session_type === "planner" &&
      turn.status === "needs_more_info" &&
      turn.missing_fields.length === 0 &&
      !turn.plan
    ) {
      const forcedPlan = await orchestrateStructuredJson({
        systemPrompt: planOnlyPrompt(
          ctx,
          turn.extracted_profile,
          draftRef,
          turn.conversation_mode,
        ),
        history: [],
        extraUserInstruction: null,
        schema: planSchema,
        maxTokens: 2600,
        temperature: 0.2,
      });
      const normalizedPlan = normalizePlan(forcedPlan.payload);
      if (normalizedPlan) {
        turn = {
          ...turn,
          status: action === "regenerate_plan" ? "plan_updated" : "plan_ready",
          plan: normalizedPlan,
          conversation_mode: action === "regenerate_plan"
            ? "planner_refine"
            : "planner_generate",
          assistant_message: turn.assistant_message ||
            defaultAssistant(
              action === "regenerate_plan" ? "plan_updated" : "plan_ready",
            ),
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
      conversation_mode: response.conversation_mode,
      personalization_used: response.personalization_used,
      suggested_replies: response.suggested_replies,
      provider_used: providerResult.provider,
      model_used: providerResult.model,
      turn_result: response,
      reply_to_message_id: replyToMessageId,
      regenerated_from_draft_id: regenerateFromDraftId,
    };
    const { data: assistantRow, error: assistantError } = await supabase
      .from("chat_messages")
      .insert({
        session_id: sessionId,
        sender: "assistant",
        content: response.assistant_message,
        metadata,
      })
      .select("id")
      .single();
    if (assistantError || !assistantRow?.id) {
      throw new Error(assistantError?.message || "Unable to save AI response.");
    }

    if (ctx.role === "member") {
      const memoryPayload = buildMemoryPayload(
        response.extracted_profile,
        providerResult.payload.memory_updates,
      );
      await persistMemories(supabase, {
        userId: user.id,
        sessionId,
        sourceMessageId: replyToMessageId,
        memoryPayload,
      });
    }

    const finalResponse: TurnResult = {
      ...response,
      assistant_message_id: String(assistantRow.id),
    };
    await upsertSessionState(supabase, {
      sessionId,
      userId: user.id,
      latestUserMessage,
      lastUserMessageId: replyToMessageId,
      lastAssistantMessageId: String(assistantRow.id),
      turn: finalResponse,
      ctx,
    });
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

function optionalEnv(name: string) {
  return Deno.env.get(name)?.trim() || "";
}

function errorStatus(message: string) {
  const lower = message.toLowerCase();
  if (message === "Unauthorized" || message === "Missing auth token") {
    return 401;
  }
  if (lower.includes("member accounts only")) return 403;
  if (lower.includes("not found")) return 404;
  if (
    lower.includes('"code": 429') ||
    lower.includes("quota exceeded") ||
    lower.includes("resource_exhausted") ||
    lower.includes("rate limit") ||
    lower.includes("timed out")
  ) {
    return 429;
  }
  return 500;
}

function publicError(message: string, status: number) {
  if (status === 429) {
    return "Azure Foundry is rate-limited or temporarily unavailable.";
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

function parseJson(s: string): unknown {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

async function getSession(
  supabase: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<SessionRecord> {
  const { data, error } = await supabase
    .from("chat_sessions")
    .select(
      "id,user_id,title,session_type,planner_status,planner_profile_json,latest_draft_id",
    )
    .eq("id", sessionId)
    .single();
  const row = obj(data);
  if (error || !data || str(row.user_id) !== userId) {
    throw new Error("Session not found.");
  }
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

async function requireUserMessage(
  supabase: SupabaseClient,
  sessionId: string,
  messageId: string,
) {
  const { data, error } = await supabase
    .from("chat_messages")
    .select("id")
    .eq("id", messageId)
    .eq("session_id", sessionId)
    .eq("sender", "user")
    .single();
  if (error || !data) throw new Error("User message not found.");
}

async function getDraft(
  supabase: SupabaseClient,
  draftId: string,
  sessionId: string,
  userId: string,
) {
  const { data, error } = await supabase
    .from("ai_plan_drafts")
    .select(
      "id,status,assistant_message,missing_fields,extracted_profile_json,plan_json",
    )
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
      assistant_message: str(turn.assistant_message) ||
        str(messageRow.content) || "I could not generate a response right now.",
      status: toStatus(str(turn.status) || str(metadata.planner_status)) ||
        "general_response",
      missing_fields: strings(turn.missing_fields || metadata.missing_fields),
      extracted_profile: mergeProfileSources(
        turn.extracted_profile || metadata.extracted_profile,
        {},
        {},
        memoryRowsToPayload([]),
      ),
      plan: normalizePlan(turn.plan || metadata.plan),
      conversation_mode: toConversationMode(
        str(turn.conversation_mode) || str(metadata.conversation_mode),
      ) || "general_coaching",
      personalization_used: strings(
        turn.personalization_used || metadata.personalization_used,
      ),
      suggested_replies: strings(
        turn.suggested_replies || metadata.suggested_replies,
      ),
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
  const [
    profileRes,
    memberRes,
    prefsRes,
    latestWeightRes,
    measurementRes,
    sessionsRes,
    activePlanRes,
    currentDraftRes,
    memoryRes,
    sessionStateRes,
  ] = await Promise.all([
    supabase.from("profiles").select("full_name,country,role_id,roles(code)")
      .eq("user_id", userId).maybeSingle(),
    supabase.from("member_profiles").select("*").eq("user_id", userId)
      .maybeSingle(),
    supabase.from("user_preferences").select("*").eq("user_id", userId)
      .maybeSingle(),
    supabase.from("member_weight_entries").select("weight_kg,recorded_at").eq(
      "member_id",
      userId,
    ).order("recorded_at", { ascending: false }).limit(1).maybeSingle(),
    supabase.from("member_body_measurements").select(
      "recorded_at,waist_cm,chest_cm,hips_cm,arm_cm,thigh_cm,body_fat_percent",
    ).eq("member_id", userId).order("recorded_at", { ascending: false }).limit(
      1,
    ).maybeSingle(),
    supabase.from("workout_sessions").select(
      "title,performed_at,duration_minutes,workout_plan_id",
    ).eq("member_id", userId).order("performed_at", { ascending: false }).limit(
      12,
    ),
    supabase.from("workout_plans").select(
      "id,title,plan_json,start_date,end_date,plan_version,default_reminder_time,assigned_at",
    ).eq("member_id", userId).eq("source", "ai").eq("status", "active").order(
      "assigned_at",
      { ascending: false },
    ).limit(1).maybeSingle(),
    str(session.latest_draft_id)
      ? supabase.from("ai_plan_drafts").select(
        "id,status,assistant_message,missing_fields,extracted_profile_json,plan_json",
      ).eq("id", String(session.latest_draft_id)).eq("user_id", userId)
        .maybeSingle()
      : Promise.resolve({ data: null }),
    supabase.from("ai_user_memories").select("memory_key,memory_value_json").eq(
      "user_id",
      userId,
    ).order("updated_at", { ascending: false }).limit(24),
    supabase.from("ai_session_state").select(
      "summary,open_loops,last_intent,last_conversation_mode,last_turn_json",
    ).eq("session_id", session.id).maybeSingle(),
  ]);

  const activePlan = compactPlan(obj(activePlanRes.data));
  const activePlanId = str(activePlan.id);
  const [taskRowsRes, taskLogsRes] = activePlanId
    ? await Promise.all([
      supabase.from("workout_plan_tasks").select(
        "id,scheduled_date,task_type,title,is_required",
      ).eq("workout_plan_id", activePlanId).eq("member_id", userId).order(
        "scheduled_date",
        { ascending: false },
      ).limit(60),
      supabase.from("workout_task_logs").select(
        "task_id,completion_status,completion_percent,logged_at",
      ).eq("member_id", userId).order("logged_at", { ascending: false }).limit(
        60,
      ),
    ])
    : [{ data: [] }, { data: [] }];

  const memoryRows = Array.isArray(memoryRes.data)
    ? memoryRes.data.map((row: unknown) => obj(row))
    : [];
  const memory = memoryRowsToPayload(memoryRows);
  const prefs = obj(prefsRes.data);
  const memberProfile = obj(memberRes.data);
  const priorProfile = mergeProfileSources(
    session.planner_profile_json,
    memberProfile,
    prefs,
    memory,
  );
  const signals = deriveSignals({
    recentSessions: Array.isArray(sessionsRes.data)
      ? sessionsRes.data.map((row: unknown) => obj(row))
      : [],
    activePlanTasks: Array.isArray(taskRowsRes.data)
      ? taskRowsRes.data.map((row: unknown) => obj(row))
      : [],
    taskLogs: Array.isArray(taskLogsRes.data)
      ? taskLogsRes.data.map((row: unknown) => obj(row))
      : [],
  });
  const profileBasics = {
    full_name: str(obj(profileRes.data).full_name),
    country: str(obj(profileRes.data).country),
    role: extractRoleCode(obj(profileRes.data).roles),
  };
  return {
    role: extractRoleCode(obj(profileRes.data).roles),
    profile_basics: profileBasics,
    member_profile: memberProfile,
    preferences: prefs,
    latest_weight: obj(latestWeightRes.data),
    latest_measurement: obj(measurementRes.data),
    recent_sessions: Array.isArray(sessionsRes.data)
      ? sessionsRes.data.map((sessionRow: unknown) => obj(sessionRow))
      : [],
    active_ai_plan: activePlan,
    prior_profile: priorProfile,
    current_draft: compactDraft(obj(currentDraftRes.data)),
    memory,
    memory_rows: memoryRows,
    session_state: obj(sessionStateRes.data),
    signals,
  };
}

function generalPrompt(ctx: PlannerContext, mode: ConversationMode) {
  const language = ctx.prior_profile.preferred_language === "ar"
    ? "Arabic"
    : "English";
  const measurement = ctx.prior_profile.measurement_unit || "metric";
  return [
    "You are GymUnity AI, a practical personalized fitness coach.",
    "Never answer with a canned template. Two users with different context should receive different answers.",
    "Use real member context when available. If the context is missing, say what is unknown instead of inventing details.",
    "Keep assistant_message concise, specific, and actionable.",
    "If the user reveals stable fitness facts, copy them into extracted_profile when relevant and memory_updates when they are long-term preferences.",
    "Set personalization_used to 2-4 short labels for the actual user data you used.",
    "Set suggested_replies to 2-4 short tailored follow-up prompts.",
    "Set conversation_mode to the assigned mode unless safety requires otherwise.",
    "Do not mention backend providers, model vendors, or API platforms.",
    "Avoid diagnosis and unsafe medical advice. If there is medical risk, advise consulting a qualified professional.",
    `Assigned conversation_mode: ${mode}.`,
    `Respond in ${language}. Use ${measurement} units.`,
    "Return only JSON matching the schema. Use status 'general_response'. Leave plan null.",
    `Member context JSON: ${JSON.stringify(promptContext(ctx, null))}`,
  ].join("\n");
}

function plannerPrompt(
  ctx: PlannerContext,
  action: PlannerAction,
  draftRef: Record<string, unknown> | null,
  mode: ConversationMode,
) {
  const language = ctx.prior_profile.preferred_language === "ar"
    ? "Arabic"
    : "English";
  const measurement = ctx.prior_profile.measurement_unit || "metric";
  return [
    "You are GymUnity Planner, a production fitness planning assistant for members.",
    "Use the supplied member data, saved memories, adherence signals, and session state before asking any question.",
    "Critical planning fields before finalizing a plan: goal, experience_level, days_per_week, session_minutes, equipment.",
    "If critical data is missing, use status 'needs_more_info' and ask only the next best concise follow-up.",
    "If enough information exists, you must return status 'plan_ready' or 'plan_updated' and populate the full plan object.",
    "Do not ask for fields that already exist in profile, memory, or session state.",
    "Honor saved schedule preferences, exercise dislikes, and known limitations when creating or refining plans.",
    "Always keep extracted_profile up to date with the best merged planning facts from this turn.",
    "Set personalization_used to 2-4 short labels for the actual user data you used.",
    "Set suggested_replies to 2-4 short tailored follow-up prompts.",
    "Set conversation_mode to the assigned mode unless safety requires a safer path.",
    "Use memory_updates only for long-term preferences and facts that should persist across sessions.",
    "If a request is medically risky or asks for diagnosis, use status 'unsafe_request' and do not produce a plan.",
    "When refining a plan, preserve what is working and update the parts that conflict with adherence, measurements, or the user's request.",
    `Assigned conversation_mode: ${mode}.`,
    `Respond in ${language}. Use ${measurement} units.`,
    action === "regenerate_plan"
      ? "This is a plan refinement request."
      : "This is a normal planning conversation turn.",
    "Return only JSON matching the schema.",
    `Member context JSON: ${JSON.stringify(promptContext(ctx, draftRef))}`,
  ].join("\n");
}

function planOnlyPrompt(
  ctx: PlannerContext,
  profile: PlannerProfile,
  draftRef: Record<string, unknown> | null,
  mode: ConversationMode,
) {
  const language = profile.preferred_language === "ar" ? "Arabic" : "English";
  const measurement = profile.measurement_unit || "metric";
  return [
    "You are GymUnity Planner.",
    "All critical planning fields are already known.",
    "Return only a full structured plan JSON matching the requested schema.",
    "Do not ask follow-up questions and do not return any prose outside the JSON.",
    "Keep the plan practical, conservative where needed, and tied to the saved member context.",
    `Assigned conversation_mode: ${mode}.`,
    `Respond in ${language}. Use ${measurement} units.`,
    `Use this extracted profile JSON: ${JSON.stringify(profile)}`,
    `Use this broader context JSON: ${
      JSON.stringify(promptContext(ctx, draftRef))
    }`,
  ].join("\n");
}

function promptContext(
  ctx: PlannerContext,
  draftRef: Record<string, unknown> | null,
) {
  return {
    profile_basics: ctx.profile_basics,
    member_profile: ctx.member_profile,
    preferences: ctx.preferences,
    latest_weight: ctx.latest_weight,
    latest_measurement: ctx.latest_measurement,
    recent_sessions: ctx.recent_sessions,
    active_ai_plan: ctx.active_ai_plan,
    prior_profile: ctx.prior_profile,
    memory: ctx.memory,
    session_state: ctx.session_state,
    signals: ctx.signals,
    current_draft: ctx.current_draft,
    referenced_draft: compactDraft(draftRef || {}),
  };
}

async function orchestrateStructuredJson(
  input: ProviderCallInput,
): Promise<ProviderResponse> {
  return await azureFoundryJson(input);
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort("timed out"), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) {
      throw new Error("Azure Foundry request timed out.");
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

async function azureFoundryJson(
  input: ProviderCallInput,
): Promise<ProviderResponse> {
  const endpoint = env("AZURE_FOUNDRY_PROJECT_ENDPOINT").replace(/\/+$/, "");
  const apiVersion = optionalEnv("AZURE_FOUNDRY_API_VERSION") || "2025-05-01";
  const agentId = optionalEnv("AZURE_FOUNDRY_AGENT_ID") ||
    await resolveAgentIdByName(endpoint, apiVersion);
  if (!agentId) {
    throw new Error(
      "Missing required env var: AZURE_FOUNDRY_AGENT_ID or AZURE_FOUNDRY_AGENT_NAME",
    );
  }

  const token = await azureBearerToken();
  const thread = await azureJson(
    `${endpoint}/threads?api-version=${encodeURIComponent(apiVersion)}`,
    token,
    { method: "POST", body: "" },
  );
  const threadId = str(obj(thread).id);
  if (!threadId) throw new Error("Azure Foundry did not create a thread.");

  await azureJson(
    `${endpoint}/threads/${encodeURIComponent(threadId)}/messages?api-version=${
      encodeURIComponent(apiVersion)
    }`,
    token,
    {
      method: "POST",
      body: JSON.stringify({
        role: "user",
        content: JSON.stringify({
          system_prompt: input.systemPrompt,
          conversation_history: input.history,
          extra_user_instruction: input.extraUserInstruction,
          required_json_schema: input.schema,
          generation: {
            max_tokens: input.maxTokens,
            temperature: input.temperature,
          },
        }),
      }),
    },
  );

  const run = await azureJson(
    `${endpoint}/threads/${encodeURIComponent(threadId)}/runs?api-version=${
      encodeURIComponent(apiVersion)
    }`,
    token,
    {
      method: "POST",
      body: JSON.stringify({
        assistant_id: agentId,
        additional_instructions:
          "You are the GymUnity TAIYO chat orchestrator. Follow system_prompt exactly and return only one valid JSON object matching required_json_schema. Do not include markdown or prose outside JSON.",
      }),
    },
  );
  const runId = str(obj(run).id);
  if (!runId) throw new Error("Azure Foundry did not create a run.");

  await waitForRun(endpoint, apiVersion, token, threadId, runId);
  const messages = await azureJson(
    `${endpoint}/threads/${encodeURIComponent(threadId)}/messages?api-version=${
      encodeURIComponent(apiVersion)
    }`,
    token,
    { method: "GET" },
  );
  const text = extractAssistantText(messages);
  if (!text) throw new Error("Azure Foundry returned no assistant text.");
  const payload = parseTurn(text);
  if (!Object.keys(payload).length) {
    throw new Error("Azure Foundry returned malformed structured output.");
  }
  return {
    payload,
    provider: "azure_foundry",
    model: optionalEnv("AZURE_FOUNDRY_AGENT_NAME") || agentId,
  };
}

async function resolveAgentIdByName(endpoint: string, apiVersion: string) {
  const agentName = optionalEnv("AZURE_FOUNDRY_AGENT_NAME");
  if (!agentName) return "";
  const token = await azureBearerToken();
  const response = await azureJson(
    `${endpoint}/assistants?api-version=${encodeURIComponent(apiVersion)}`,
    token,
    { method: "GET" },
  );
  const agents = Array.isArray(obj(response).data)
    ? obj(response).data as unknown[]
    : [];
  const match = agents.map(obj).find((agent) => str(agent.name) === agentName);
  return str(match?.id) || "";
}

async function azureBearerToken() {
  const tenantId = optionalEnv("AZURE_TENANT_ID");
  const clientId = optionalEnv("AZURE_CLIENT_ID");
  const clientSecret = optionalEnv("AZURE_CLIENT_SECRET");
  if (tenantId && clientId && clientSecret) {
    return await azureClientCredentialsToken(tenantId, clientId, clientSecret);
  }

  const staticToken = optionalEnv("AZURE_FOUNDRY_API_KEY") ||
    optionalEnv("AZURE_FOUNDRY_AGENT_TOKEN") ||
    optionalEnv("AGENT_TOKEN");
  if (staticToken) return staticToken;

  throw new Error(
    "Missing Azure auth env vars: provide Entra credentials or an agent bearer token.",
  );
}

async function azureClientCredentialsToken(
  tenantId: string,
  clientId: string,
  clientSecret: string,
) {
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: "client_credentials",
    scope: "https://ai.azure.com/.default",
  });
  const response = await fetchWithTimeout(
    `https://login.microsoftonline.com/${
      encodeURIComponent(tenantId)
    }/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    },
    15000,
  );
  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `Azure token request failed with status ${response.status}.`,
    );
  }
  const accessToken = str(obj(parseJson(text)).access_token);
  if (!accessToken) {
    throw new Error("Azure token response did not include an access token.");
  }
  return accessToken;
}

async function waitForRun(
  endpoint: string,
  apiVersion: string,
  token: string,
  threadId: string,
  runId: string,
) {
  const started = Date.now();
  const timeoutMs = Number(optionalEnv("AZURE_FOUNDRY_RUN_TIMEOUT_MS")) ||
    60000;
  while (Date.now() - started < timeoutMs) {
    const run = obj(
      await azureJson(
        `${endpoint}/threads/${encodeURIComponent(threadId)}/runs/${
          encodeURIComponent(runId)
        }?api-version=${encodeURIComponent(apiVersion)}`,
        token,
        { method: "GET" },
      ),
    );
    const status = str(run.status) || "";
    if (status === "completed") return;
    if (["failed", "cancelled", "expired"].includes(status)) {
      throw new Error(`Azure Foundry run ended with status ${status}.`);
    }
    if (status === "requires_action") {
      throw new Error(
        "Azure Foundry run requires tool action that this Edge Function does not handle.",
      );
    }
    await sleep(1200);
  }
  throw new Error("Azure Foundry run timed out.");
}

async function azureJson(
  url: string,
  bearerToken: string,
  init: { method: string; body?: BodyInit | null },
) {
  const response = await fetchWithTimeout(
    url,
    {
      method: init.method,
      headers: {
        "Authorization": `Bearer ${bearerToken}`,
        "Content-Type": "application/json",
      },
      body: init.body,
    },
    20000,
  );
  const text = await response.text();
  if (!response.ok) {
    throw new Error(
      `Azure Foundry request failed with status ${response.status}.`,
    );
  }
  return text ? parseJson(text) : {};
}

function extractAssistantText(messages: unknown) {
  const rows = Array.isArray(obj(messages).data)
    ? obj(messages).data as unknown[]
    : [];
  for (const row of rows.map(obj)) {
    if (str(row.role) !== "assistant") continue;
    const content = row.content;
    if (typeof content === "string") return content;
    for (const part of arrContent(content)) {
      const item = obj(part);
      const text = obj(item.text);
      const value = str(text.value) || str(item.text) || str(item.content);
      if (value) return value;
    }
  }
  return "";
}

function arrContent(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function parseTurn(text: string): Record<string, unknown> {
  return obj(
    parseJson(
      text.replace(/^```json\s*/i, "").replace(/^```\s*/i, "").replace(
        /```$/i,
        "",
      ).trim(),
    ),
  );
}

function sanitizeGeneral(
  raw: Record<string, unknown>,
  ctx: PlannerContext,
  inferredMode: ConversationMode,
): TurnResult {
  const extractedProfile = mergeProfileSources(
    raw.extracted_profile,
    ctx.member_profile,
    ctx.preferences,
    ctx.memory,
  );
  const mode = toConversationMode(str(raw.conversation_mode)) || inferredMode;
  return {
    assistant_message: str(raw.assistant_message) ||
      "I could not generate a response right now.",
    status: "general_response",
    missing_fields: [],
    extracted_profile: extractedProfile,
    plan: null,
    conversation_mode: mode,
    personalization_used: strings(raw.personalization_used).length
      ? strings(raw.personalization_used)
      : buildPersonalizationUsed(ctx, mode),
    suggested_replies: strings(raw.suggested_replies).length
      ? strings(raw.suggested_replies)
      : buildSuggestedReplies({
        conversationMode: mode,
        missingFields: [],
        ctx,
      }),
  };
}

function sanitizePlanner(
  raw: Record<string, unknown>,
  ctx: PlannerContext,
  regenerated: boolean,
  inferredMode: ConversationMode,
): TurnResult {
  const profile = mergeProfileSources(
    raw.extracted_profile,
    ctx.member_profile,
    ctx.preferences,
    ctx.memory,
  );
  const missing = Array.from(
    new Set([...criticalMissing(profile), ...strings(raw.missing_fields)]),
  );
  let status = toStatus(str(raw.status)) || "needs_more_info";
  let mode = toConversationMode(str(raw.conversation_mode)) || inferredMode;
  let plan = normalizePlan(raw.plan);
  if (status === "unsafe_request") {
    plan = null;
  } else if (missing.length) {
    status = "needs_more_info";
    mode = "planner_collect";
    plan = null;
  } else if (plan) {
    status = regenerated ? "plan_updated" : "plan_ready";
    mode = regenerated ? "planner_refine" : "planner_generate";
  } else {
    status = "needs_more_info";
    mode = "planner_collect";
  }
  return {
    assistant_message: str(raw.assistant_message) || defaultAssistant(status),
    status,
    missing_fields: status === "unsafe_request" ? [] : missing,
    extracted_profile: profile,
    plan,
    conversation_mode: mode,
    personalization_used: strings(raw.personalization_used).length
      ? strings(raw.personalization_used)
      : buildPersonalizationUsed(ctx, mode),
    suggested_replies: status === "unsafe_request"
      ? []
      : strings(raw.suggested_replies).length
      ? strings(raw.suggested_replies)
      : buildSuggestedReplies({
        conversationMode: mode,
        missingFields: missing,
        ctx,
      }),
  };
}

function defaultAssistant(status: string) {
  if (status === "unsafe_request") {
    return "This request needs a safer path. Please consult a qualified professional before acting on it.";
  }
  if (status === "plan_ready" || status === "plan_updated") {
    return "Your plan is ready to review.";
  }
  return "I need a little more information before I can generate the plan.";
}

function persistencePlannerStatus(status: TurnStatus) {
  if (status === "needs_more_info") return "collecting_info";
  return status;
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

function toConversationMode(value: string | null): ConversationMode | null {
  if (
    value === "general_coaching" ||
    value === "planner_collect" ||
    value === "planner_generate" ||
    value === "planner_refine" ||
    value === "progress_checkin"
  ) {
    return value;
  }
  return null;
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
      .map((day: unknown, index: number) =>
        normalizeDay(day, weekNumber, index + 1)
      )
      .filter((day): day is PlanDay => day !== null)
    : [];
  return days.length ? { week_number: weekNumber, days } : null;
}

function normalizeDay(
  raw: unknown,
  weekNumber: number,
  fallbackDay: number,
): PlanDay | null {
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
  const type = [
      "workout",
      "cardio",
      "mobility",
      "nutrition",
      "hydration",
      "sleep",
      "steps",
      "recovery",
      "measurement",
    ].includes(String(r.type || "").trim().toLowerCase())
    ? String(r.type).trim().toLowerCase()
    : "workout";
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
  if (error || !data?.id) {
    throw new Error(error?.message || "Unable to persist AI plan draft.");
  }
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
  const latestUser = [...history].reverse().find((message) =>
    message.sender === "user"
  );
  const nextTitle = turn.plan?.title ||
    (!defaultTitles.has(session.title || "")
      ? session.title
      : latestUser?.content) ||
    (session.session_type === "planner" ? "AI Planner" : "New chat");
  const patch: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
    title: nextTitle?.slice(0, 80) || "New chat",
  };
  if (session.session_type === "planner") {
    patch.planner_status = persistencePlannerStatus(turn.status);
    patch.latest_draft_id = draftId;
    patch.planner_profile_json = turn.extracted_profile;
  }
  const { error } = await supabase.from("chat_sessions").update(patch).eq(
    "id",
    session.id,
  );
  if (error) throw new Error(error.message);
}

async function persistMemories(
  supabase: SupabaseClient,
  input: {
    userId: string;
    sessionId: string;
    sourceMessageId: string | null;
    memoryPayload: ReturnType<typeof buildMemoryPayload>;
  },
) {
  const rows: Array<Record<string, unknown>> = [];
  const pushValue = (memoryKey: string, value: unknown) => {
    const resolved = str(value);
    if (!resolved) return;
    rows.push({
      user_id: input.userId,
      memory_key: memoryKey,
      memory_value_json: { value: resolved },
      confidence: 0.88,
      source_session_id: input.sessionId,
      source_message_id: input.sourceMessageId,
    });
  };
  const pushNumber = (memoryKey: string, value: unknown) => {
    const resolved = posInt(value);
    if (!resolved) return;
    rows.push({
      user_id: input.userId,
      memory_key: memoryKey,
      memory_value_json: { value: resolved },
      confidence: 0.88,
      source_session_id: input.sessionId,
      source_message_id: input.sourceMessageId,
    });
  };
  const pushArray = (memoryKey: string, values: string[]) => {
    const resolved = strings(values);
    if (!resolved.length) return;
    rows.push({
      user_id: input.userId,
      memory_key: memoryKey,
      memory_value_json: { values: resolved },
      confidence: 0.86,
      source_session_id: input.sessionId,
      source_message_id: input.sourceMessageId,
    });
  };
  pushValue("goal", input.memoryPayload.goal);
  pushValue("experience_level", input.memoryPayload.experience_level);
  pushNumber("days_per_week", input.memoryPayload.days_per_week);
  pushNumber("session_minutes", input.memoryPayload.session_minutes);
  pushArray("equipment", input.memoryPayload.equipment);
  pushArray("limitations", input.memoryPayload.limitations);
  pushArray("preferred_days", input.memoryPayload.preferred_days);
  pushArray("exercise_dislikes", input.memoryPayload.exercise_dislikes);
  pushValue("response_style", input.memoryPayload.response_style);
  pushValue("preferred_language", input.memoryPayload.preferred_language);
  pushValue("measurement_unit", input.memoryPayload.measurement_unit);
  if (!rows.length) return;
  const { error } = await supabase.from("ai_user_memories").upsert(rows, {
    onConflict: "user_id,memory_key",
  });
  if (error) throw new Error(error.message);
}

async function upsertSessionState(
  supabase: SupabaseClient,
  input: {
    sessionId: string;
    userId: string;
    latestUserMessage: string;
    lastUserMessageId: string | null;
    lastAssistantMessageId: string;
    turn: TurnResult;
    ctx: PlannerContext;
  },
) {
  const state = summarizeSessionState({
    latestUserMessage: input.latestUserMessage,
    turnStatus: input.turn.status,
    conversationMode: input.turn.conversation_mode,
    ctx: input.ctx,
    missingFields: input.turn.missing_fields,
  });
  const { error } = await supabase.from("ai_session_state").upsert({
    session_id: input.sessionId,
    user_id: input.userId,
    summary: state.summary,
    open_loops: state.openLoops,
    last_intent: input.turn.conversation_mode,
    last_conversation_mode: input.turn.conversation_mode,
    last_user_message_id: input.lastUserMessageId,
    last_assistant_message_id: input.lastAssistantMessageId,
    last_turn_json: {
      status: input.turn.status,
      conversation_mode: input.turn.conversation_mode,
      missing_fields: input.turn.missing_fields,
      personalization_used: input.turn.personalization_used,
      suggested_replies: input.turn.suggested_replies,
      draft_id: input.turn.draft_id,
    },
  }, {
    onConflict: "session_id",
  });
  if (error) throw new Error(error.message);
}

function compactDraft(raw: Record<string, unknown>) {
  if (!Object.keys(raw).length) return {};
  return {
    id: str(raw.id),
    status: str(raw.status),
    assistant_message: str(raw.assistant_message),
    missing_fields: strings(raw.missing_fields),
    extracted_profile_json: obj(raw.extracted_profile_json),
    plan_json: obj(raw.plan_json),
  };
}

function extractRoleCode(value: unknown) {
  const direct = obj(value);
  if (str(direct.code)) return str(direct.code);
  const first = Array.isArray(value) && value.length ? obj(value[0]) : {};
  return str(first.code);
}
