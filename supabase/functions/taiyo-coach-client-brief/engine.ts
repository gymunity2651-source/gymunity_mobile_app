export type CoachCopilotRequestType =
  | "coach_client_brief"
  | "checkin_reply_draft"
  | "client_risk_summary";

export type CoachCopilotStatus =
  | "success"
  | "needs_visibility_permission"
  | "needs_more_context"
  | "blocked_for_safety"
  | "error";

export type RiskLevel = "low" | "medium" | "high";
export type Confidence = "low" | "medium" | "high";

export type CoachClientContext = {
  coach_id: string;
  role: "coach";
  target_member_id: string;
  subscription_id: string;
  request_type: CoachCopilotRequestType;
  subscription: Record<string, unknown>;
  visibility_settings: Record<string, unknown>;
  visibility_confirmed: boolean;
  shared_visibility: string[];
  client_header: Record<string, unknown>;
  consented_member_insight: Record<string, unknown>;
  latest_checkins: Record<string, unknown>[];
  client_record: Record<string, unknown>;
  coach_notes: Record<string, unknown>[];
  recent_messages: Record<string, unknown>[];
  safety_flags: string[];
  privacy_notes: string[];
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
};

export type NormalizedCoachCopilot = {
  request_type: CoachCopilotRequestType;
  status: CoachCopilotStatus;
  result: {
    client_status: "on_track" | "watch" | "at_risk";
    summary: string;
    red_flags: string[];
    suggested_action: string;
    suggested_message: string;
    privacy_notes: string[];
    risk_level: RiskLevel;
  };
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
  metadata: {
    source: "supabase_edge_function";
    generated_at: string;
    debug_context?: CoachClientContext;
    raw_text?: string;
  };
};

export function obj(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export function arr(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function str(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

export function strings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return compactStrings(value.map((item) => str(item)));
}

export function num(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function bool(value: unknown): boolean {
  return value === true;
}

export function supportedRequestType(
  value: unknown,
): CoachCopilotRequestType {
  const resolved = str(value) || "coach_client_brief";
  if (
    resolved === "coach_client_brief" ||
    resolved === "checkin_reply_draft" ||
    resolved === "client_risk_summary"
  ) {
    return resolved;
  }
  throw new Error("Unsupported request_type.");
}

export function buildCoachClientContext(
  coachId: string,
  rawContext: unknown,
  input: {
    clientId: string;
    subscriptionId: string;
    requestType: CoachCopilotRequestType;
  },
): CoachClientContext {
  const raw = obj(rawContext);
  const workspace = obj(raw.workspace);
  const client = obj(workspace.client);
  const visibility = obj(raw.visibility || workspace.visibility);
  const insight = obj(raw.member_insight);
  const checkins = arr(workspace.checkins || raw.checkins).map(obj)
    .slice(0, 6);
  const notes = visibilityAllowsNotes(visibility)
    ? arr(workspace.notes).map(compactNote).slice(0, 8)
    : [];
  const messages = visibilityAllowsMessages(visibility)
    ? arr(raw.messages).map(compactMessage).slice(0, 12)
    : [];
  const sharedVisibility = sharedVisibilityKeys(visibility);
  const visibilityConfirmed = sharedVisibility.length > 0;
  const safetyFlags = safetyFlagsFrom({ client, insight, checkins });
  const privacyNotes = privacyNotesFor(visibility, visibilityConfirmed);
  const missingFields = compactStrings([
    Object.keys(client).length ? null : "client_workspace",
    visibilityConfirmed ? null : "visibility_permission",
    Object.keys(insight).length ? null : "member_insight",
    checkins.length ? null : "weekly_checkins",
  ]);

  return {
    coach_id: coachId,
    role: "coach",
    target_member_id: input.clientId,
    subscription_id: input.subscriptionId,
    request_type: input.requestType,
    subscription: obj(raw.subscription),
    visibility_settings: compactVisibility(visibility),
    visibility_confirmed: visibilityConfirmed,
    shared_visibility: sharedVisibility,
    client_header: compactClient(client, insight),
    consented_member_insight: compactInsight(insight),
    latest_checkins: checkins.map(compactCheckin),
    client_record: compactClientRecord(client),
    coach_notes: notes,
    recent_messages: messages,
    safety_flags: safetyFlags,
    privacy_notes: privacyNotes,
    data_quality: {
      missing_fields: missingFields,
      confidence: confidenceFor(missingFields),
    },
  };
}

export function needsVisibilityPermissionResponse(
  requestType: CoachCopilotRequestType,
  context: CoachClientContext,
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedCoachCopilot {
  const generatedAt = options.generatedAt || new Date().toISOString();
  return {
    request_type: requestType,
    status: "needs_visibility_permission",
    result: {
      client_status: "watch",
      summary:
        "TAIYO needs member visibility permission before summarizing client data.",
      red_flags: [],
      suggested_action:
        "Ask the member to update coach visibility settings for this subscription.",
      suggested_message: "",
      privacy_notes: context.privacy_notes.length
        ? context.privacy_notes
        : ["No member insight categories are currently shared."],
      risk_level: "medium",
    },
    data_quality: context.data_quality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(options.debug ? { debug_context: context } : {}),
    },
  };
}

export function buildOrchestratorInput(
  requestType: CoachCopilotRequestType,
  context: CoachClientContext,
) {
  return {
    request_type: requestType,
    user_role: "coach",
    coach_context: {
      coach_id: context.coach_id,
      role: context.role,
      subscription_id: context.subscription_id,
      client_record: context.client_record,
      coach_notes: context.coach_notes,
      recent_messages: context.recent_messages,
    },
    client_context: {
      target_member_id: context.target_member_id,
      client_header: context.client_header,
      consented_member_insight: context.consented_member_insight,
      latest_checkins: context.latest_checkins,
      safety_flags: context.safety_flags,
      shared_visibility: context.shared_visibility,
    },
    visibility_confirmed: context.visibility_confirmed,
    response_format: "json",
    instruction:
      "Return only valid JSON. Do not return markdown. Respect visibility permissions. Draft suggestions only; do not send messages. Surface safety red flags conservatively and do not diagnose.",
    expected_response_shape: {
      request_type: requestType,
      status:
        "success | needs_visibility_permission | needs_more_context | blocked_for_safety | error",
      result: {
        client_status: "on_track | watch | at_risk",
        summary: "string",
        red_flags: ["string"],
        suggested_action: "string",
        suggested_message: "string",
        privacy_notes: ["string"],
        risk_level: "low | medium | high",
      },
      data_quality: {
        missing_fields: ["string"],
        confidence: "low | medium | high",
      },
    },
  };
}

export function normalizeCoachCopilotResponse(
  aiOutput: unknown,
  context: CoachClientContext,
  requestType: CoachCopilotRequestType,
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedCoachCopilot {
  const generatedAt = options.generatedAt || new Date().toISOString();
  const parsed = typeof aiOutput === "string"
    ? parseJsonFromText(aiOutput)
    : aiOutput;
  const raw = obj(parsed);
  if (!Object.keys(raw).length) {
    return errorResponse(
      requestType,
      context,
      "TAIYO could not return a valid coach brief right now.",
      generatedAt,
      options.debug,
      typeof aiOutput === "string" ? aiOutput : undefined,
    );
  }

  const result = obj(raw.result);
  const redFlags = compactStrings([
    ...strings(result.red_flags),
    ...strings(raw.red_flags),
    ...context.safety_flags,
  ]);
  const riskLevel = risk(str(result.risk_level) || str(raw.risk_level), redFlags);
  const missingFields = compactStrings([
    ...context.data_quality.missing_fields.filter((field) =>
      field !== "visibility_permission"
    ),
    ...strings(raw.missing_fields),
    ...strings(result.missing_fields),
    ...strings(obj(raw.data_quality).missing_fields),
  ]);
  const status = normalizeStatus(str(raw.status), riskLevel, redFlags);
  const suggestedMessage = str(result.suggested_message) ||
    str(raw.suggested_message) || "";

  return {
    request_type: requestType,
    status,
    result: {
      client_status: clientStatus(
        str(result.client_status) || str(raw.client_status),
        riskLevel,
      ),
      summary: str(result.summary) || str(raw.summary) || "",
      red_flags: redFlags,
      suggested_action: str(result.suggested_action) ||
        str(raw.suggested_action) || "",
      suggested_message: suggestedMessage,
      privacy_notes: compactStrings([
        ...context.privacy_notes,
        ...strings(result.privacy_notes),
        ...strings(raw.privacy_notes),
        ...(suggestedMessage ? ["Suggested message is a draft only."] : []),
      ]),
      risk_level: riskLevel,
    },
    data_quality: {
      missing_fields: missingFields,
      confidence: confidence(
        str(obj(raw.data_quality).confidence),
        confidenceFor(missingFields),
      ),
    },
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(options.debug ? { debug_context: context } : {}),
    },
  };
}

export function parseJsonFromText(text: string): unknown {
  const cleaned = text
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/```$/i, "")
    .trim();
  try {
    return JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(cleaned.slice(start, end + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}

function compactVisibility(visibility: Record<string, unknown>) {
  if (!Object.keys(visibility).length) return {};
  return {
    share_ai_plan_summary: bool(visibility.share_ai_plan_summary),
    share_workout_adherence: bool(visibility.share_workout_adherence),
    share_progress_metrics: bool(visibility.share_progress_metrics),
    share_nutrition_summary: bool(visibility.share_nutrition_summary),
    share_product_recommendations: bool(
      visibility.share_product_recommendations,
    ),
    share_relevant_purchases: bool(visibility.share_relevant_purchases),
  };
}

function sharedVisibilityKeys(visibility: Record<string, unknown>) {
  const pairs = compactVisibility(visibility);
  return Object.entries(pairs)
    .filter(([, value]) => value === true)
    .map(([key]) => key);
}

function compactClient(
  client: Record<string, unknown>,
  insight: Record<string, unknown>,
) {
  return {
    member_id: str(client.member_id) || str(insight.member_id),
    member_name_present: Boolean(str(client.member_name) || str(insight.member_name)),
    package_title: str(client.package_title) || str(insight.package_title),
    status: str(client.status) || str(insight.subscription_status),
    pipeline_stage: str(client.pipeline_stage),
    risk_status: str(client.risk_status),
    risk_flags: compactStrings([
      ...strings(client.risk_flags),
      ...strings(insight.risk_flags),
    ]),
    goal: str(client.goal) || str(insight.current_goal),
    last_checkin_at: str(client.last_checkin_at),
    unread_messages: Math.round(num(client.unread_messages) ?? 0),
  };
}

function compactInsight(insight: Record<string, unknown>) {
  if (!Object.keys(insight).length) return {};
  return {
    current_goal: str(insight.current_goal),
    plan_insight: obj(insight.plan_insight),
    adherence_insight: obj(insight.adherence_insight),
    progress_insight: obj(insight.progress_insight),
    nutrition_insight: obj(insight.nutrition_insight),
    product_insight: obj(insight.product_insight),
    risk_flags: strings(insight.risk_flags),
  };
}

function compactCheckin(row: Record<string, unknown>) {
  return {
    id: str(row.id),
    week_start: str(row.week_start),
    adherence_score: num(row.adherence_score),
    energy_score: num(row.energy_score),
    sleep_score: num(row.sleep_score),
    workouts_completed: num(row.workouts_completed),
    missed_workouts: num(row.missed_workouts),
    soreness_score: num(row.soreness_score),
    fatigue_score: num(row.fatigue_score),
    pain_warning: str(row.pain_warning),
    biggest_obstacle: str(row.biggest_obstacle),
    support_needed: str(row.support_needed),
    questions: str(row.questions),
    coach_reply_present: Boolean(str(row.coach_reply)),
  };
}

function compactClientRecord(client: Record<string, unknown>) {
  return {
    pipeline_stage: str(client.pipeline_stage),
    internal_status: str(client.internal_status),
    risk_status: str(client.risk_status),
    tags: strings(client.tags),
    coach_notes_present: Boolean(str(client.coach_notes)),
    preferred_language: str(client.language),
    follow_up_at: str(client.follow_up_at),
  };
}

function compactNote(raw: unknown) {
  const note = obj(raw);
  return {
    id: str(note.id),
    note_type: str(note.note_type),
    is_pinned: note.is_pinned === true,
    note: str(note.note),
    created_at: str(note.created_at),
  };
}

function compactMessage(raw: unknown) {
  const message = obj(raw);
  return {
    id: str(message.id),
    sender_role: str(message.sender_role),
    message_type: str(message.message_type),
    content: str(message.content),
    created_at: str(message.created_at),
  };
}

function visibilityAllowsNotes(visibility: Record<string, unknown>) {
  return sharedVisibilityKeys(visibility).length > 0;
}

function visibilityAllowsMessages(visibility: Record<string, unknown>) {
  return sharedVisibilityKeys(visibility).length > 0;
}

function safetyFlagsFrom(input: {
  client: Record<string, unknown>;
  insight: Record<string, unknown>;
  checkins: Record<string, unknown>[];
}) {
  const flags = new Set<string>();
  for (const flag of strings(input.client.risk_flags)) flags.add(flag);
  for (const flag of strings(input.insight.risk_flags)) flags.add(flag);
  const riskStatus = (str(input.client.risk_status) || "").toLowerCase();
  if (riskStatus === "at_risk" || riskStatus === "critical") {
    flags.add(riskStatus);
  }
  for (const checkin of input.checkins) {
    const text = [
      str(checkin.pain_warning),
      str(checkin.biggest_obstacle),
      str(checkin.support_needed),
      str(checkin.questions),
    ].filter(Boolean).join(" ").toLowerCase();
    const adherence = num(checkin.adherence_score);
    const fatigue = num(checkin.fatigue_score);
    if (adherence != null && adherence < 40) flags.add("low_adherence");
    if (fatigue != null && fatigue >= 8) flags.add("high_fatigue");
    addTextSafetyFlags(text, flags);
  }
  return Array.from(flags);
}

function addTextSafetyFlags(text: string, flags: Set<string>) {
  if (!text) return;
  if (text.includes("chest pain")) flags.add("chest_pain");
  if (text.includes("dizzy") || text.includes("dizziness")) {
    flags.add("dizziness");
  }
  if (text.includes("faint")) flags.add("fainting");
  if (text.includes("severe pain")) flags.add("severe_pain");
  if (text.includes("breathing") || text.includes("shortness of breath")) {
    flags.add("breathing_difficulty");
  }
  if (text.includes("depress") || text.includes("self harm")) {
    flags.add("mental_health_support");
  }
}

function privacyNotesFor(
  visibility: Record<string, unknown>,
  visibilityConfirmed: boolean,
) {
  if (!visibilityConfirmed) return ["No member insight categories are shared."];
  const notes = ["Only member-shared visibility categories were included."];
  if (!bool(visibility.share_nutrition_summary)) {
    notes.push("Nutrition details were not included.");
  }
  if (!bool(visibility.share_progress_metrics)) {
    notes.push("Progress metrics were not included.");
  }
  return notes;
}

function normalizeStatus(
  value: string | null,
  riskLevel: RiskLevel,
  flags: string[],
): CoachCopilotStatus {
  if (
    value === "success" ||
    value === "needs_visibility_permission" ||
    value === "needs_more_context" ||
    value === "blocked_for_safety" ||
    value === "error"
  ) {
    return value;
  }
  const highRiskFlags = new Set([
    "chest_pain",
    "fainting",
    "breathing_difficulty",
    "mental_health_support",
  ]);
  if (riskLevel === "high" && flags.some((flag) => highRiskFlags.has(flag))) {
    return "blocked_for_safety";
  }
  return "success";
}

function errorResponse(
  requestType: CoachCopilotRequestType,
  context: CoachClientContext,
  message: string,
  generatedAt: string,
  debug = false,
  rawText?: string,
): NormalizedCoachCopilot {
  return {
    request_type: requestType,
    status: "error",
    result: {
      client_status: "watch",
      summary: message,
      red_flags: [],
      suggested_action: "",
      suggested_message: "",
      privacy_notes: context.privacy_notes,
      risk_level: "low",
    },
    data_quality: context.data_quality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(debug
        ? {
          debug_context: context,
          raw_text: rawText?.slice(0, 2000),
        }
        : {}),
    },
  };
}

function clientStatus(value: string | null, riskLevel: RiskLevel) {
  if (value === "on_track" || value === "watch" || value === "at_risk") {
    return value;
  }
  if (riskLevel === "high") return "at_risk";
  if (riskLevel === "medium") return "watch";
  return "on_track";
}

function risk(value: string | null, flags: string[] = []): RiskLevel {
  if (value === "high" || value === "medium" || value === "low") return value;
  const highRisk = new Set([
    "at_risk",
    "critical",
    "chest_pain",
    "fainting",
    "breathing_difficulty",
    "mental_health_support",
  ]);
  if (flags.some((flag) => highRisk.has(flag))) return "high";
  if (flags.length) return "medium";
  return "low";
}

function confidence(value: string | null, fallback: Confidence): Confidence {
  if (value === "high" || value === "medium" || value === "low") {
    return value;
  }
  return fallback;
}

function confidenceFor(missingFields: string[]): Confidence {
  if (missingFields.length >= 4) return "low";
  if (missingFields.length >= 2) return "medium";
  return "high";
}

function compactStrings(values: Array<string | null | undefined>) {
  return Array.from(
    new Set(
      values
        .filter((value): value is string => Boolean(value && value.trim()))
        .map((value) => value.trim()),
    ),
  );
}
