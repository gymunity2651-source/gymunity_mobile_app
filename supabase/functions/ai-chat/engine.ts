export type SessionType = "general" | "planner";
export type TurnStatus =
  | "general_response"
  | "needs_more_info"
  | "plan_ready"
  | "plan_updated"
  | "unsafe_request";
export type PlannerAction = "reply" | "regenerate_plan";
export type ConversationMode =
  | "general_coaching"
  | "planner_collect"
  | "planner_generate"
  | "planner_refine"
  | "progress_checkin";
export type LanguageCode = "en" | "ar";
export type MeasurementUnit = "metric" | "imperial";

export type PlannerProfile = {
  goal: string | null;
  experience_level: string | null;
  days_per_week: number | null;
  session_minutes: number | null;
  equipment: string[];
  limitations: string[];
  preferred_language: LanguageCode | null;
  measurement_unit: MeasurementUnit | null;
};

export type MemoryPayload = {
  goal: string | null;
  experience_level: string | null;
  days_per_week: number | null;
  session_minutes: number | null;
  equipment: string[];
  limitations: string[];
  preferred_days: string[];
  exercise_dislikes: string[];
  response_style: string | null;
  preferred_language: LanguageCode | null;
  measurement_unit: MeasurementUnit | null;
};

export type MemberSignals = {
  sessions_last_7d: number;
  sessions_last_30d: number;
  average_session_minutes: number | null;
  days_since_last_workout: number | null;
  active_plan_task_count: number;
  adherence_scheduled_count: number;
  adherence_completed_count: number;
  adherence_partial_count: number;
  adherence_completion_ratio: number | null;
};

export type PlannerContextLike = {
  profile_basics: Record<string, unknown>;
  member_profile: Record<string, unknown>;
  preferences: Record<string, unknown>;
  latest_weight: Record<string, unknown>;
  latest_measurement: Record<string, unknown>;
  recent_sessions: Record<string, unknown>[];
  active_ai_plan: Record<string, unknown>;
  prior_profile: PlannerProfile;
  current_draft: Record<string, unknown>;
  memory: MemoryPayload;
  session_state: Record<string, unknown>;
  signals: MemberSignals;
};

export function str(v: unknown) {
  return typeof v === "string" && v.trim() ? v.trim() : null;
}

export function obj(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" && !Array.isArray(v) ? v as Record<string, unknown> : {};
}

export function strings(v: unknown): string[] {
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

export function posInt(v: unknown) {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) && n > 0 ? Math.round(n) : null;
}

export function nonNegInt(v: unknown) {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) && n >= 0 ? Math.round(n) : null;
}

export function nonNegNum(v: unknown) {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) && n >= 0 ? n : null;
}

export function clamp(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n));
}

export function time(v: unknown) {
  const s = str(v);
  if (!s) return null;
  const m = s.match(/^(\d{1,2}):(\d{2})/);
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  return h >= 0 && h <= 23 && min >= 0 && min <= 59
    ? `${String(h).padStart(2, "0")}:${String(min).padStart(2, "0")}`
    : null;
}

export function dateOnly(v: unknown) {
  const s = str(v);
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d.toISOString().split("T")[0];
}

export function lang(v: unknown): LanguageCode | null {
  const s = str(v)?.toLowerCase();
  return s === "arabic" || s === "ar"
    ? "ar"
    : s === "english" || s === "en"
    ? "en"
    : null;
}

export function unit(v: unknown): MeasurementUnit | null {
  const s = str(v)?.toLowerCase();
  return s === "metric" || s === "imperial" ? s : null;
}

export function levelish(v: unknown) {
  const s = str(v)?.toLowerCase();
  return s === "beginner" || s === "intermediate" || s === "advanced"
    ? s
    : s === "athlete"
    ? "advanced"
    : null;
}

export function emptyProfile(): PlannerProfile {
  return {
    goal: null,
    experience_level: null,
    days_per_week: null,
    session_minutes: null,
    equipment: [],
    limitations: [],
    preferred_language: null,
    measurement_unit: null,
  };
}

export function emptyMemory(): MemoryPayload {
  return {
    goal: null,
    experience_level: null,
    days_per_week: null,
    session_minutes: null,
    equipment: [],
    limitations: [],
    preferred_days: [],
    exercise_dislikes: [],
    response_style: null,
    preferred_language: null,
    measurement_unit: null,
  };
}

export function normalizeProfile(raw: unknown, base: PlannerProfile | null): PlannerProfile {
  const r = obj(raw);
  const b = base || emptyProfile();
  return {
    goal: str(r.goal) || str(b.goal),
    experience_level: levelish(r.experience_level) || levelish(b.experience_level),
    days_per_week: posInt(r.days_per_week) || posInt(b.days_per_week),
    session_minutes: posInt(r.session_minutes) || posInt(b.session_minutes),
    equipment: strings(r.equipment).length ? strings(r.equipment) : strings(b.equipment),
    limitations: r.limitations === undefined ? strings(b.limitations) : strings(r.limitations),
    preferred_language: lang(r.preferred_language) || lang(b.preferred_language),
    measurement_unit: unit(r.measurement_unit) || unit(b.measurement_unit),
  };
}

export function criticalMissing(profile: PlannerProfile): string[] {
  const out: string[] = [];
  if (!str(profile.goal)) out.push("goal");
  if (!str(profile.experience_level)) out.push("experience_level");
  if (!posInt(profile.days_per_week)) out.push("days_per_week");
  if (!posInt(profile.session_minutes)) out.push("session_minutes");
  if (strings(profile.equipment).length === 0) out.push("equipment");
  return out;
}

export function memoryRowsToPayload(rows: Record<string, unknown>[]): MemoryPayload {
  const payload = emptyMemory();
  for (const row of rows) {
    const key = str(row.memory_key);
    const value = obj(row.memory_value_json);
    if (!key) continue;
    switch (key) {
      case "goal":
        payload.goal = str(value.value) || payload.goal;
        break;
      case "experience_level":
        payload.experience_level = levelish(value.value) || payload.experience_level;
        break;
      case "days_per_week":
        payload.days_per_week = posInt(value.value) || payload.days_per_week;
        break;
      case "session_minutes":
        payload.session_minutes = posInt(value.value) || payload.session_minutes;
        break;
      case "equipment":
        payload.equipment = strings(value.values);
        break;
      case "limitations":
        payload.limitations = strings(value.values);
        break;
      case "preferred_days":
        payload.preferred_days = strings(value.values);
        break;
      case "exercise_dislikes":
        payload.exercise_dislikes = strings(value.values);
        break;
      case "response_style":
        payload.response_style = str(value.value) || payload.response_style;
        break;
      case "preferred_language":
        payload.preferred_language = lang(value.value) || payload.preferred_language;
        break;
      case "measurement_unit":
        payload.measurement_unit = unit(value.value) || payload.measurement_unit;
        break;
      default:
        break;
    }
  }
  return payload;
}

export function mergeProfileSources(
  sessionProfile: unknown,
  memberProfile: Record<string, unknown>,
  preferences: Record<string, unknown>,
  memory: MemoryPayload,
): PlannerProfile {
  const merged = normalizeProfile(sessionProfile, null);
  if (!merged.goal) merged.goal = str(memberProfile.goal) || memory.goal;
  if (!merged.experience_level) merged.experience_level = levelish(memberProfile.experience_level) || memory.experience_level;
  if (!merged.days_per_week) merged.days_per_week = posInt(memory.days_per_week);
  if (!merged.session_minutes) merged.session_minutes = posInt(memory.session_minutes);
  if (!merged.equipment.length) merged.equipment = strings(memory.equipment);
  if (!merged.limitations.length) merged.limitations = strings(memory.limitations);
  if (!merged.preferred_language) merged.preferred_language = lang(preferences.language) || memory.preferred_language;
  if (!merged.measurement_unit) merged.measurement_unit = unit(preferences.measurement_unit) || memory.measurement_unit;
  return merged;
}

export function deriveSignals(input: {
  recentSessions: Record<string, unknown>[];
  activePlanTasks: Record<string, unknown>[];
  taskLogs: Record<string, unknown>[];
  now?: Date;
}): MemberSignals {
  const now = input.now || new Date();
  const sessionDates = input.recentSessions
    .map((session) => {
      const value = str(session.performed_at);
      return value ? new Date(value) : null;
    })
    .filter((value): value is Date => value instanceof Date && !Number.isNaN(value.getTime()));
  const avgDuration = input.recentSessions.length
    ? Math.round(
        input.recentSessions
          .map((session) => posInt(session.duration_minutes) || 0)
          .reduce((sum, value) => sum + value, 0) / input.recentSessions.length,
      )
    : null;
  const sessionsLast7d = sessionDates.filter((date) => dayDiff(date, now) <= 7).length;
  const sessionsLast30d = sessionDates.filter((date) => dayDiff(date, now) <= 30).length;
  const lastWorkout = sessionDates[0] || null;
  const taskMap = new Map<string, Record<string, unknown>>();
  for (const task of input.activePlanTasks) {
    const id = str(task.id);
    if (id) taskMap.set(id, task);
  }
  const relevantTasks = input.activePlanTasks.filter((task) => {
    const scheduled = str(task.scheduled_date);
    if (!scheduled) return false;
    return new Date(`${scheduled}T00:00:00Z`).getTime() <= now.getTime();
  });
  let completed = 0;
  let partial = 0;
  for (const log of input.taskLogs) {
    const taskId = str(log.task_id);
    if (!taskId || !taskMap.has(taskId)) continue;
    const status = str(log.completion_status)?.toLowerCase();
    if (status === "completed") completed++;
    else if (status === "partial") partial++;
  }
  const adherenceScheduled = relevantTasks.length;
  const ratio = adherenceScheduled
    ? Number(((completed + partial * 0.5) / adherenceScheduled).toFixed(2))
    : null;
  return {
    sessions_last_7d: sessionsLast7d,
    sessions_last_30d: sessionsLast30d,
    average_session_minutes: avgDuration,
    days_since_last_workout: lastWorkout ? dayDiff(lastWorkout, now) : null,
    active_plan_task_count: input.activePlanTasks.length,
    adherence_scheduled_count: adherenceScheduled,
    adherence_completed_count: completed,
    adherence_partial_count: partial,
    adherence_completion_ratio: ratio,
  };
}

export function classifyConversationMode(input: {
  sessionType: SessionType;
  action: PlannerAction;
  latestUserMessage: string;
  ctx: PlannerContextLike;
  draftRef: Record<string, unknown> | null;
}): ConversationMode {
  const message = input.latestUserMessage.toLowerCase();
  if (input.sessionType === "planner") {
    if (input.action === "regenerate_plan") return "planner_refine";
    if (hasRefineSignal(message) || Object.keys(input.draftRef || {}).length > 0) {
      return "planner_refine";
    }
    return criticalMissing(input.ctx.prior_profile).length ? "planner_collect" : "planner_generate";
  }
  if (
    message.includes("progress") ||
    message.includes("check in") ||
    message.includes("check-in") ||
    message.includes("today") ||
    message.includes("this week") ||
    message.includes("why am i") ||
    message.includes("plateau") ||
    message.includes("consistency") ||
    (input.ctx.signals.adherence_scheduled_count > 0 && (
      message.includes("plan") ||
      message.includes("session") ||
      message.includes("workout")
    ))
  ) {
    return "progress_checkin";
  }
  return "general_coaching";
}

export function buildPersonalizationUsed(ctx: PlannerContextLike, mode: ConversationMode): string[] {
  const used: string[] = [];
  if (str(ctx.profile_basics.full_name)) used.push("profile basics");
  if (str(ctx.prior_profile.goal)) used.push("goal");
  if (ctx.memory.preferred_days.length) used.push("saved schedule preferences");
  if (ctx.memory.exercise_dislikes.length) used.push("exercise dislikes");
  if (ctx.recent_sessions.length) used.push("recent workouts");
  if (ctx.active_ai_plan.id) used.push("active plan");
  if (ctx.latest_weight.weight_kg) used.push("latest weight");
  if (ctx.latest_measurement.recorded_at) used.push("latest measurements");
  if (ctx.signals.adherence_scheduled_count > 0 && mode !== "general_coaching") {
    used.push("plan adherence");
  }
  if (ctx.session_state.summary) used.push("session memory");
  return used.slice(0, 4);
}

export function buildSuggestedReplies(input: {
  conversationMode: ConversationMode;
  missingFields: string[];
  ctx: PlannerContextLike;
}): string[] {
  if (input.missingFields.length) {
    return input.missingFields.map(templateForMissingField).filter(Boolean).slice(0, 4);
  }
  switch (input.conversationMode) {
    case "planner_collect":
      return [
        "Main goal: fat loss.",
        "Days per week: 4.",
        "Session minutes: 45.",
      ];
    case "planner_generate":
      return [
        "Make it lower impact.",
        "Shift it to 4 days per week.",
        "Add home-gym alternatives.",
      ];
    case "planner_refine":
      return [
        "Reduce lower-body volume.",
        "Shorten sessions to 40 minutes.",
        "Replace burpees with low-impact cardio.",
      ];
    case "progress_checkin":
      return [
        "Compare this week to last week.",
        "Adjust next week based on my consistency.",
        "Make today's session easier.",
      ];
    case "general_coaching":
    default:
      return input.ctx.active_ai_plan.id
        ? [
            "Adjust today's workout around my plan.",
            "What should I do on rest days?",
            "How can I improve consistency this week?",
          ]
        : [
            "Give me a simple 30-minute workout.",
            "Help me structure this week.",
            "What should I focus on next?",
          ];
  }
}

export function summarizeSessionState(input: {
  latestUserMessage: string;
  turnStatus: TurnStatus;
  conversationMode: ConversationMode;
  ctx: PlannerContextLike;
  missingFields: string[];
}): { summary: string; openLoops: string[] } {
  const parts: string[] = [];
  const name = str(input.ctx.profile_basics.full_name);
  if (name) parts.push(`Member ${name}`);
  if (str(input.ctx.prior_profile.goal)) parts.push(`goal ${input.ctx.prior_profile.goal}`);
  if (input.conversationMode === "progress_checkin" && input.ctx.signals.adherence_completion_ratio !== null) {
    parts.push(`adherence ${(input.ctx.signals.adherence_completion_ratio * 100).toFixed(0)}%`);
  }
  if (input.ctx.active_ai_plan.title) parts.push(`active plan ${str(input.ctx.active_ai_plan.title)}`);
  if (input.turnStatus === "needs_more_info" && input.missingFields.length) {
    parts.push(`waiting for ${input.missingFields.join(", ")}`);
  }
  if (input.latestUserMessage.trim()) {
    parts.push(`latest request: ${truncate(input.latestUserMessage.trim(), 100)}`);
  }
  return {
    summary: truncate(parts.filter(Boolean).join(" | "), 320),
    openLoops: input.missingFields.slice(0, 8),
  };
}

export function buildMemoryPayload(
  profile: PlannerProfile,
  rawUpdates: unknown,
): MemoryPayload {
  const updates = obj(rawUpdates);
  return {
    goal: profile.goal,
    experience_level: profile.experience_level,
    days_per_week: profile.days_per_week,
    session_minutes: profile.session_minutes,
    equipment: profile.equipment,
    limitations: profile.limitations,
    preferred_days: strings(updates.preferred_days),
    exercise_dislikes: strings(updates.exercise_dislikes),
    response_style: str(updates.response_style),
    preferred_language: profile.preferred_language || lang(updates.preferred_language),
    measurement_unit: profile.measurement_unit || unit(updates.measurement_unit),
  };
}

export function compactPlan(raw: Record<string, unknown>) {
  const planJson = obj(raw.plan_json);
  return {
    id: str(raw.id),
    title: str(raw.title),
    start_date: dateOnly(raw.start_date),
    end_date: dateOnly(raw.end_date),
    plan_version: posInt(raw.plan_version),
    default_reminder_time: time(raw.default_reminder_time),
    summary: str(planJson.summary),
    duration_weeks: posInt(planJson.duration_weeks),
    level: str(planJson.level),
  };
}

function templateForMissingField(field: string) {
  switch (field) {
    case "goal":
      return "Main goal: fat loss.";
    case "experience_level":
      return "Experience level: beginner.";
    case "days_per_week":
      return "Days per week: 4.";
    case "session_minutes":
      return "Session minutes: 45.";
    case "equipment":
      return "Equipment available: dumbbells, bench, bands.";
    case "limitations":
      return "Injuries or limitations: none.";
    default:
      return `${field.replaceAll("_", " ")}: `;
  }
}

function hasRefineSignal(message: string) {
  return (
    message.includes("change") ||
    message.includes("adjust") ||
    message.includes("replace") ||
    message.includes("harder") ||
    message.includes("easier") ||
    message.includes("shorter") ||
    message.includes("longer") ||
    message.includes("refine")
  );
}

function dayDiff(date: Date, now: Date) {
  return Math.max(0, Math.floor((now.getTime() - date.getTime()) / 86400000));
}

function truncate(value: string, max: number) {
  return value.length <= max ? value : `${value.slice(0, max - 1)}…`;
}
