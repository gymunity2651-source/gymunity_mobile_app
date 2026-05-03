export type PlannerRequestType = "workout_plan_draft" | "plan_review";
export type PlannerStatus =
  | "success"
  | "needs_more_context"
  | "blocked_for_safety"
  | "error";
export type Confidence = "low" | "medium" | "high";

export type PlannerContext = {
  member_id: string;
  role: "member";
  profile: {
    goal: string;
    fitness_level: string;
    injuries: string[];
  };
  preferences: {
    available_days: number | null;
    session_minutes: number | null;
    available_equipment: string[];
    training_location: string;
    training_style: string;
    focus_areas: string[];
    preferred_days: string[];
    exercise_dislikes: string[];
    preferred_language: string;
    measurement_unit: string;
  };
  readiness: {
    score: number | null;
    sleep_hours: number | null;
    energy_level: string;
    soreness_level: string;
    stress_level: string;
    trend: string;
    notes: string;
  };
  active_plan_summary: Record<string, unknown>;
  recent_adherence: {
    planned_workouts: number;
    completed_workouts: number;
    adherence_rate: number;
  };
  recent_workouts: Record<string, unknown>[];
  nutrition_status: Record<string, unknown>;
  memories: Record<string, unknown>;
  current_draft: Record<string, unknown>;
  safety_flags: string[];
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
};

export type NormalizedWorkoutPlanner = {
  request_type: PlannerRequestType;
  status: PlannerStatus;
  result: {
    plan_goal: string;
    summary: string;
    weekly_structure: Array<Record<string, unknown>>;
    safety_notes: string[];
    progression_rule: string;
    deload_rule: string;
    activation_allowed: boolean;
  };
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
  metadata: {
    source: "supabase_edge_function";
    generated_at: string;
    persisted?: boolean;
    draft_id?: string;
    session_id?: string;
    plan_json?: Record<string, unknown>;
    extracted_profile?: Record<string, unknown>;
    debug_context?: PlannerContext;
    raw_text?: string;
  };
  plan_json: Record<string, unknown>;
  extracted_profile: Record<string, unknown>;
  assistant_message: string;
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
  return Array.from(
    new Set(
      value
        .map((item) => typeof item === "string" ? item.trim() : "")
        .filter(Boolean),
    ),
  );
}

export function num(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function int(value: unknown): number | null {
  const parsed = num(value);
  return parsed == null ? null : Math.round(parsed);
}

export function dateOnly(value: Date | string | null | undefined): string {
  if (!value) return new Date().toISOString().split("T")[0];
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return new Date().toISOString().split("T")[0];
  }
  return date.toISOString().split("T")[0];
}

export function supportedRequestType(value: unknown): PlannerRequestType {
  const resolved = str(value) || "workout_plan_draft";
  if (resolved === "workout_plan_draft" || resolved === "plan_review") {
    return resolved;
  }
  throw new Error("Unsupported request_type.");
}

export function missingCriticalPlannerAnswers(
  plannerAnswers: Record<string, unknown>,
) {
  return compactStrings([
    str(plannerAnswers.goal) ? null : "goal",
    str(plannerAnswers.experience_level) || str(plannerAnswers.fitness_level)
      ? null
      : "experience_level",
    int(plannerAnswers.days_per_week) != null ||
      int(plannerAnswers.available_days) != null
      ? null
      : "days_per_week",
    int(plannerAnswers.session_minutes) == null ? "session_minutes" : null,
    strings(plannerAnswers.equipment).length ? null : "equipment",
  ]);
}

export function buildPlannerContext(
  memberId: string,
  rawContext: unknown,
  plannerAnswers: Record<string, unknown>,
): PlannerContext {
  const raw = obj(rawContext);
  const coachContext = obj(raw.coach_context);
  const memberProfile = obj(coachContext.member_profile);
  const preferences = obj(coachContext.preferences);
  const readiness = obj(coachContext.readiness);
  const recentSessions = arr(coachContext.recent_sessions).map(obj);
  const recentTaskLogs = arr(coachContext.recent_task_logs).map(obj);
  const todayTasks = arr(coachContext.today_tasks).map(obj);
  const nutrition = obj(coachContext.nutrition);
  const memories = memoryRowsToMap(raw.memories || coachContext.memories);
  const currentDraft = obj(raw.current_draft);

  const goal = normalizeGoal(
    str(plannerAnswers.goal) || str(memberProfile.goal),
  );
  const fitnessLevel = normalizeFitnessLevel(
    str(plannerAnswers.experience_level) ||
      str(plannerAnswers.fitness_level) ||
      str(memberProfile.experience_level),
  );
  const injuries = compactStrings([
    ...strings(memberProfile.injuries),
    ...strings(memberProfile.limitations),
    ...strings(plannerAnswers.limitations),
    ...strings(plannerAnswers.injuries),
    ...memoryValues(obj(memories).limitations),
    ...memoryValues(obj(memories).injuries),
  ]);

  const safetyFlags = safetyFlagsFrom({
    readiness,
    recentTaskLogs,
    injuries,
    plannerAnswers,
  });
  const missingFields = Array.from(
    new Set([
      ...missingCriticalPlannerAnswers(plannerAnswers),
      goal === "unknown" ? "profile.goal" : null,
      fitnessLevel === "unknown" ? "profile.fitness_level" : null,
    ].filter(Boolean) as string[]),
  );

  const readinessScore = num(readiness.readiness_score);
  return {
    member_id: memberId,
    role: "member",
    profile: {
      goal,
      fitness_level: fitnessLevel,
      injuries,
    },
    preferences: {
      available_days: int(plannerAnswers.days_per_week) ||
        int(plannerAnswers.available_days) ||
        int(memberProfile.days_per_week),
      session_minutes: int(plannerAnswers.session_minutes) ||
        int(memberProfile.session_minutes),
      available_equipment: compactStrings([
        ...strings(plannerAnswers.equipment),
        ...strings(memberProfile.equipment),
      ]),
      training_location: str(plannerAnswers.training_location) ||
        str(memberProfile.training_place) ||
        "unknown",
      training_style: str(plannerAnswers.workout_style) ||
        str(plannerAnswers.intensity) ||
        "unknown",
      focus_areas: strings(plannerAnswers.focus_areas),
      preferred_days: strings(plannerAnswers.preferred_days),
      exercise_dislikes: strings(plannerAnswers.exercise_dislikes),
      preferred_language: str(plannerAnswers.preferred_language) ||
        str(memberProfile.preferred_language) ||
        str(preferences.language) ||
        "en",
      measurement_unit: str(plannerAnswers.measurement_unit) ||
        str(preferences.measurement_unit) ||
        "metric",
    },
    readiness: {
      score: readinessScore,
      sleep_hours: num(readiness.sleep_hours),
      energy_level: levelFromFivePoint(readiness.energy_level),
      soreness_level: levelFromFivePoint(readiness.soreness_level),
      stress_level: levelFromFivePoint(readiness.stress_level),
      trend: readinessTrend(arr(raw.recent_readiness).map(obj)),
      notes: str(readiness.note) || "",
    },
    active_plan_summary: compactActivePlan(
      obj(coachContext.active_plan || coachContext.active_ai_plan),
    ),
    recent_adherence: weeklyAdherence(recentTaskLogs, todayTasks),
    recent_workouts: recentSessions.slice(0, 6).map(compactWorkoutSession),
    nutrition_status: compactNutrition(nutrition),
    memories,
    current_draft: compactDraft(currentDraft),
    safety_flags: safetyFlags,
    data_quality: {
      missing_fields: missingFields,
      confidence: confidenceFor(missingFields, readinessScore),
    },
  };
}

export function buildOrchestratorInput(
  requestType: PlannerRequestType,
  plannerContext: PlannerContext,
  plannerAnswers: Record<string, unknown>,
) {
  return {
    request_type: requestType,
    user_role: "member",
    planner_context: plannerContext,
    planner_answers: plannerAnswers,
    response_format: "json",
    instruction:
      "Return only valid JSON matching expected_response_shape. Do not return markdown. Draft only. Do not activate the plan. Include a concrete weekly_structure with days and tasks that can be reviewed before activation. Set activation_allowed=true when the draft is complete, low-risk, and safe for the app to show on the review screen for later user approval. Set activation_allowed=false only when safety risk, missing context, or malformed planning makes later activation unsafe.",
    expected_response_shape: {
      request_type: requestType,
      status: "success | needs_more_context | blocked_for_safety | error",
      result: {
        plan_goal: "string",
        title: "string",
        summary: "string",
        duration_weeks: "number",
        level: "beginner | intermediate | advanced",
        weekly_structure: [
          {
            week_number: "number",
            days: [
              {
                day_number: "number",
                label: "string",
                focus: "string",
                tasks: [
                  {
                    type: "workout | cardio | mobility | recovery",
                    title: "string",
                    instructions: "string",
                    sets: "number or null",
                    reps: "number or null",
                    duration_minutes: "number or null",
                    target_value: "number or null",
                    target_unit: "string or null",
                    scheduled_time: "HH:MM or null",
                    reminder_time: "HH:MM or null",
                    is_required: "boolean",
                  },
                ],
              },
            ],
          },
        ],
        safety_notes: ["string"],
        progression_rule: "string",
        deload_rule: "string",
        activation_allowed: "boolean",
      },
      data_quality: {
        missing_fields: ["string"],
        confidence: "low | medium | high",
      },
    },
  };
}

export function needsMoreContextResponse(
  requestType: PlannerRequestType,
  plannerContext: PlannerContext,
  missingFields: string[],
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedWorkoutPlanner {
  const generatedAt = options.generatedAt || new Date().toISOString();
  const mergedMissing = Array.from(
    new Set([...missingFields, ...plannerContext.data_quality.missing_fields]),
  );
  return {
    request_type: requestType,
    status: "needs_more_context",
    result: {
      plan_goal: plannerContext.profile.goal,
      summary: "TAIYO needs a little more planner detail before drafting.",
      weekly_structure: [],
      safety_notes: [],
      progression_rule: "",
      deload_rule: "",
      activation_allowed: false,
    },
    data_quality: {
      missing_fields: mergedMissing,
      confidence: confidenceFor(mergedMissing, plannerContext.readiness.score),
    },
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(options.debug ? { debug_context: plannerContext } : {}),
    },
    plan_json: {},
    extracted_profile: extractedProfile(plannerContext),
    assistant_message:
      "TAIYO needs a little more planner detail before drafting.",
  };
}

export function blockedForSafetyResponse(
  requestType: PlannerRequestType,
  plannerContext: PlannerContext,
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedWorkoutPlanner {
  const generatedAt = options.generatedAt || new Date().toISOString();
  const notes = safetyNotesFor(plannerContext.safety_flags);
  return {
    request_type: requestType,
    status: "blocked_for_safety",
    result: {
      plan_goal: plannerContext.profile.goal,
      summary:
        "TAIYO cannot safely draft a workout plan from the current risk signals.",
      weekly_structure: [],
      safety_notes: notes,
      progression_rule: "",
      deload_rule: "",
      activation_allowed: false,
    },
    data_quality: plannerContext.data_quality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(options.debug ? { debug_context: plannerContext } : {}),
    },
    plan_json: {},
    extracted_profile: extractedProfile(plannerContext),
    assistant_message: notes.join(" ") ||
      "TAIYO found safety flags that need attention before planning.",
  };
}

export function normalizeWorkoutPlannerResponse(
  aiOutput: unknown,
  plannerContext: PlannerContext,
  requestType: PlannerRequestType,
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedWorkoutPlanner {
  const generatedAt = options.generatedAt || new Date().toISOString();
  const parsed = typeof aiOutput === "string"
    ? parseJsonFromText(aiOutput)
    : aiOutput;
  const raw = obj(parsed);
  if (!Object.keys(raw).length) {
    return errorResponse(
      requestType,
      plannerContext,
      "TAIYO could not return a valid workout plan right now.",
      generatedAt,
      options.debug,
      typeof aiOutput === "string" ? aiOutput : undefined,
    );
  }

  const result = obj(raw.result);
  const status = normalizeStatus(
    str(raw.status),
    plannerContext.safety_flags,
  );
  if (status === "blocked_for_safety") {
    return blockedForSafetyResponse(requestType, plannerContext, {
      generatedAt,
      debug: options.debug,
    });
  }

  const missingFields = compactStrings([
    ...strings(raw.missing_fields),
    ...strings(result.missing_fields),
    ...plannerContext.data_quality.missing_fields,
  ]);
  const planJson = normalizePlanJson(result, raw, plannerContext);
  const validPlan = isValidPlanJson(planJson);
  const activationAllowed = status === "success" &&
    validPlan &&
    rawBool(result.activation_allowed, true);
  const responseStatus: PlannerStatus = status === "success" && !validPlan
    ? (missingFields.length ? "needs_more_context" : "error")
    : status;

  return {
    request_type: requestType,
    status: responseStatus,
    result: {
      plan_goal: str(result.plan_goal) || str(raw.plan_goal) ||
        plannerContext.profile.goal,
      summary: str(result.summary) || str(raw.summary) ||
        str(planJson.summary) || "",
      weekly_structure: publicWeeklyStructure(planJson),
      safety_notes: compactStrings([
        ...strings(result.safety_notes),
        ...strings(raw.safety_notes),
        ...strings(planJson.safety_notes),
      ]),
      progression_rule: str(result.progression_rule) ||
        str(raw.progression_rule) || "",
      deload_rule: str(result.deload_rule) || str(raw.deload_rule) || "",
      activation_allowed: activationAllowed,
    },
    data_quality: {
      missing_fields: missingFields,
      confidence: confidenceFor(missingFields, plannerContext.readiness.score),
    },
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(options.debug ? { debug_context: plannerContext } : {}),
    },
    plan_json: activationAllowed ? planJson : {},
    extracted_profile: extractedProfile(plannerContext),
    assistant_message: str(result.assistant_message) ||
      str(raw.assistant_message) ||
      str(result.summary) ||
      str(planJson.summary) ||
      "TAIYO prepared your workout plan draft.",
  };
}

export function shouldPersistDraft(normalized: NormalizedWorkoutPlanner) {
  if (normalized.status === "success") {
    return normalized.result.activation_allowed &&
      isValidPlanJson(normalized.plan_json);
  }
  return normalized.status === "blocked_for_safety";
}

export function draftPersistencePayload(
  memberId: string,
  sessionId: string,
  normalized: NormalizedWorkoutPlanner,
) {
  const status = normalized.status === "success"
    ? normalized.request_type === "plan_review" ? "plan_updated" : "plan_ready"
    : normalized.status === "blocked_for_safety"
    ? "unsafe_request"
    : normalized.status === "error"
    ? "error"
    : "collecting_info";
  return {
    user_id: memberId,
    session_id: sessionId,
    status,
    assistant_message: normalized.assistant_message,
    missing_fields: normalized.data_quality.missing_fields,
    extracted_profile_json: normalized.extracted_profile,
    plan_json: status === "plan_ready" || status === "plan_updated"
      ? normalized.plan_json
      : {},
  };
}

export function publicResponse(
  normalized: NormalizedWorkoutPlanner,
  persistence: {
    persisted: boolean;
    draft_id?: string | null;
    session_id?: string | null;
  },
) {
  return {
    request_type: normalized.request_type,
    status: normalized.status,
    result: normalized.result,
    data_quality: normalized.data_quality,
    metadata: {
      ...normalized.metadata,
      persisted: persistence.persisted,
      draft_id: persistence.draft_id || undefined,
      session_id: persistence.session_id || undefined,
      plan_json: Object.keys(normalized.plan_json).length
        ? normalized.plan_json
        : undefined,
      extracted_profile: normalized.extracted_profile,
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

function normalizePlanJson(
  result: Record<string, unknown>,
  raw: Record<string, unknown>,
  plannerContext: PlannerContext,
) {
  const candidate = obj(
    result.plan_json || result.plan || raw.plan_json || raw.plan,
  );
  const source = Object.keys(candidate).length ? candidate : result;
  const weeks = normalizeWeeks(
    source.weekly_structure || result.weekly_structure || raw.weekly_structure,
  );
  return removeUndefined({
    title: str(source.title) || "TAIYO Workout Plan",
    summary: str(source.summary) || str(result.summary) || "",
    duration_weeks: Math.max(
      int(source.duration_weeks) || weeks.length || 1,
      1,
    ),
    level: normalizeFitnessLevel(
      str(source.level) || plannerContext.profile.fitness_level,
    ),
    start_date_suggestion: str(source.start_date_suggestion),
    safety_notes: compactStrings([
      ...strings(source.safety_notes),
      ...strings(result.safety_notes),
    ]),
    rest_guidance: str(source.rest_guidance) || str(result.rest_guidance),
    nutrition_guidance: str(source.nutrition_guidance) ||
      str(result.nutrition_guidance),
    hydration_guidance: str(source.hydration_guidance) ||
      str(result.hydration_guidance),
    sleep_guidance: str(source.sleep_guidance) || str(result.sleep_guidance),
    step_target: str(source.step_target) || str(result.step_target),
    weekly_structure: weeks,
  });
}

function normalizeWeeks(value: unknown) {
  const rows = arr(value);
  if (!rows.length) return [];
  if (rows.some((row) => arr(obj(row).days).length)) {
    return rows.map(obj).map((week, index) => ({
      week_number: Math.max(int(week.week_number) || index + 1, 1),
      days: arr(week.days).map(obj).map((day, dayIndex) =>
        normalizeDay(day, index + 1, dayIndex + 1)
      ).filter((day) => arr(day.tasks).length),
    })).filter((week) => week.days.length);
  }
  return [{
    week_number: 1,
    days: rows.map(obj).map((day, index) => normalizeDay(day, 1, index + 1))
      .filter((day) => arr(day.tasks).length),
  }].filter((week) => week.days.length);
}

function normalizeDay(
  day: Record<string, unknown>,
  weekNumber: number,
  dayNumber: number,
) {
  const label = str(day.label) || str(day.day) || `Day ${dayNumber}`;
  const tasks = arr(day.tasks).map(normalizeTask).filter((task) =>
    task !== null
  );
  return {
    week_number: Math.max(int(day.week_number) || weekNumber, 1),
    day_number: Math.max(int(day.day_number) || dayNumber, 1),
    label,
    focus: str(day.focus) || str(day.intensity) || "",
    tasks,
  };
}

function normalizeTask(raw: unknown) {
  if (typeof raw === "string") {
    const title = raw.trim();
    if (!title) return null;
    return {
      type: "workout",
      title,
      instructions: "",
      sets: null,
      reps: null,
      duration_minutes: null,
      target_value: null,
      target_unit: null,
      scheduled_time: null,
      reminder_time: null,
      is_required: true,
    };
  }
  const task = obj(raw);
  const title = str(task.title) || str(task.exercise) || str(task.name);
  if (!title) return null;
  return {
    type: normalizeTaskType(str(task.type)),
    title,
    instructions: str(task.instructions) || str(task.notes) || "",
    sets: nonNegativeInt(task.sets),
    reps: nonNegativeInt(task.reps),
    duration_minutes: nonNegativeInt(task.duration_minutes),
    target_value: nonNegativeNum(task.target_value),
    target_unit: str(task.target_unit),
    scheduled_time: timeString(task.scheduled_time),
    reminder_time: timeString(task.reminder_time),
    is_required: typeof task.is_required === "boolean"
      ? task.is_required
      : true,
  };
}

function publicWeeklyStructure(planJson: Record<string, unknown>) {
  const days: Array<Record<string, unknown>> = [];
  for (const week of arr(planJson.weekly_structure).map(obj)) {
    for (const day of arr(week.days).map(obj)) {
      days.push({
        day: str(day.label) || `Day ${days.length + 1}`,
        focus: str(day.focus) || "",
        intensity: "",
        tasks: arr(day.tasks),
        notes: "",
      });
    }
  }
  return days;
}

function isValidPlanJson(planJson: Record<string, unknown>) {
  return Boolean(
    str(planJson.title) &&
      str(planJson.summary) &&
      arr(planJson.weekly_structure).some((week) =>
        arr(obj(week).days).some((day) => arr(obj(day).tasks).length)
      ),
  );
}

function errorResponse(
  requestType: PlannerRequestType,
  plannerContext: PlannerContext,
  message: string,
  generatedAt: string,
  debug = false,
  rawText?: string,
): NormalizedWorkoutPlanner {
  return {
    request_type: requestType,
    status: "error",
    result: {
      plan_goal: plannerContext.profile.goal,
      summary: message,
      weekly_structure: [],
      safety_notes: [],
      progression_rule: "",
      deload_rule: "",
      activation_allowed: false,
    },
    data_quality: plannerContext.data_quality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(debug
        ? {
          debug_context: plannerContext,
          raw_text: rawText?.slice(0, 2000),
        }
        : {}),
    },
    plan_json: {},
    extracted_profile: extractedProfile(plannerContext),
    assistant_message: message,
  };
}

function extractedProfile(plannerContext: PlannerContext) {
  return {
    goal: plannerContext.profile.goal,
    experience_level: plannerContext.profile.fitness_level,
    days_per_week: plannerContext.preferences.available_days,
    session_minutes: plannerContext.preferences.session_minutes,
    equipment: plannerContext.preferences.available_equipment,
    limitations: plannerContext.profile.injuries,
    preferred_language: plannerContext.preferences.preferred_language,
    measurement_unit: plannerContext.preferences.measurement_unit,
  };
}

function normalizeStatus(
  value: string | null,
  safetyFlags: string[],
): PlannerStatus {
  if (
    value === "success" ||
    value === "needs_more_context" ||
    value === "blocked_for_safety" ||
    value === "error"
  ) {
    return value;
  }
  return hasHighRiskSafetyFlags(safetyFlags) ? "blocked_for_safety" : "success";
}

export function hasHighRiskSafetyFlags(flags: string[]) {
  const highRisk = new Set([
    "chest_pain",
    "dizziness",
    "fainting",
    "severe_pain",
    "breathing_difficulty",
    "serious_injury",
  ]);
  return flags.some((flag) => highRisk.has(flag));
}

function safetyFlagsFrom(input: {
  readiness: Record<string, unknown>;
  recentTaskLogs: Record<string, unknown>[];
  injuries: string[];
  plannerAnswers: Record<string, unknown>;
}) {
  const flags = new Set<string>();
  const readinessScore = num(input.readiness.readiness_score);
  if (readinessScore != null && readinessScore < 30) {
    flags.add("very_low_readiness");
  }
  for (const injury of input.injuries) {
    addTextSafetyFlags(injury.toLowerCase(), flags);
  }
  for (const value of Object.values(input.plannerAnswers)) {
    if (typeof value === "string") {
      addTextSafetyFlags(value.toLowerCase(), flags);
    }
    if (Array.isArray(value)) {
      addTextSafetyFlags(value.join(" ").toLowerCase(), flags);
    }
  }
  for (const log of input.recentTaskLogs) {
    const painScore = num(log.pain_score);
    if (painScore != null && painScore >= 7) flags.add("severe_pain");
    addTextSafetyFlags(
      [str(log.note), str(log.swap_reason)].filter(Boolean).join(" ")
        .toLowerCase(),
      flags,
    );
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
  if (text.includes("serious injury")) flags.add("serious_injury");
  if (text.includes("breathing") || text.includes("shortness of breath")) {
    flags.add("breathing_difficulty");
  }
}

function safetyNotesFor(flags: string[]) {
  if (!flags.length) return ["Review current safety signals before training."];
  return flags.map((flag) => {
    switch (flag) {
      case "chest_pain":
      case "fainting":
      case "breathing_difficulty":
        return "Do not start a workout plan with urgent symptoms. Seek qualified medical support.";
      case "dizziness":
        return "Pause training plans until dizziness is resolved and safety is clear.";
      case "severe_pain":
      case "serious_injury":
        return "Avoid loading painful or injured areas until cleared by a qualified professional.";
      default:
        return "Use a conservative approach and review readiness before training.";
    }
  });
}

function weeklyAdherence(
  recentTaskLogs: Record<string, unknown>[],
  todayTasks: Record<string, unknown>[],
) {
  const sevenDaysAgo = Date.now() - 7 * 86400000;
  const recent = recentTaskLogs.filter((log) => {
    const loggedAt = str(log.logged_at);
    if (!loggedAt) return false;
    const timestamp = new Date(loggedAt).getTime();
    return Number.isFinite(timestamp) && timestamp >= sevenDaysAgo;
  });
  const planned = Math.max(recent.length, todayTasks.length);
  const completed = recent.filter((log) =>
    ["completed", "partial"].includes(
      (str(log.completion_status) || "").toLowerCase(),
    )
  ).length;
  return {
    planned_workouts: planned,
    completed_workouts: completed,
    adherence_rate: planned ? Number((completed / planned).toFixed(2)) : 0,
  };
}

function compactActivePlan(plan: Record<string, unknown>) {
  if (!Object.keys(plan).length) return {};
  return {
    id: str(plan.id),
    title: str(plan.title),
    status: str(plan.status),
    start_date: str(plan.start_date),
    end_date: str(plan.end_date),
    plan_version: int(plan.plan_version),
  };
}

function compactWorkoutSession(row: Record<string, unknown>) {
  return {
    title: str(row.title),
    performed_at: str(row.performed_at),
    duration_minutes: int(row.duration_minutes),
    readiness_score: int(row.readiness_score),
    difficulty_score: int(row.difficulty_score),
    completion_rate: num(row.completion_rate),
  };
}

function compactNutrition(nutrition: Record<string, unknown>) {
  return {
    target: obj(nutrition.target),
    hydration_ml_today: int(nutrition.hydration_ml_today),
    meal_logs_today: int(nutrition.meal_logs_today),
    planned_meals_today: int(nutrition.planned_meals_today),
    last_nutrition_checkin: obj(nutrition.last_nutrition_checkin),
  };
}

function compactDraft(draft: Record<string, unknown>) {
  if (!Object.keys(draft).length) return {};
  return {
    id: str(draft.id),
    status: str(draft.status),
    missing_fields: strings(draft.missing_fields),
    extracted_profile_json: obj(draft.extracted_profile_json),
    plan_title: str(obj(draft.plan_json).title),
  };
}

function memoryRowsToMap(value: unknown): Record<string, unknown> {
  if (!Array.isArray(value)) return obj(value);
  const result: Record<string, unknown> = {};
  for (const row of value.map(obj)) {
    const key = str(row.memory_key);
    if (key) result[key] = row.memory_value_json;
  }
  return result;
}

function memoryValues(value: unknown): string[] {
  const raw = obj(value);
  return compactStrings([str(raw.value), ...strings(raw.values)]);
}

function readinessTrend(rows: Record<string, unknown>[]) {
  const scores = rows.map((row) => num(row.readiness_score)).filter((
    score,
  ): score is number => score != null);
  if (scores.length < 2) return "unknown";
  const delta = scores[0] - scores[scores.length - 1];
  if (Math.abs(delta) < 5) return "stable";
  return delta > 0 ? "up" : "down";
}

function confidenceFor(
  missingFields: string[],
  readinessScore: number | null,
): Confidence {
  if (missingFields.length >= 4 || readinessScore == null) return "low";
  if (missingFields.length >= 2) return "medium";
  return "high";
}

function normalizeGoal(value: string | null) {
  const normalized = (value || "").toLowerCase();
  if (["fat_loss", "weight_loss", "lose_weight"].includes(normalized)) {
    return "fat_loss";
  }
  if (["muscle_gain", "hypertrophy", "build_muscle"].includes(normalized)) {
    return "muscle_gain";
  }
  if (["strength", "strength_gain"].includes(normalized)) return "strength";
  if (["general_fitness", "fitness", "health"].includes(normalized)) {
    return "general_fitness";
  }
  return normalized || "unknown";
}

function normalizeFitnessLevel(value: string | null) {
  const normalized = (value || "").toLowerCase();
  if (["beginner", "intermediate", "advanced"].includes(normalized)) {
    return normalized;
  }
  if (normalized === "athlete") return "advanced";
  return "beginner";
}

function levelFromFivePoint(value: unknown) {
  const resolved = num(value);
  if (resolved == null) return "unknown";
  if (resolved <= 2) return "low";
  if (resolved === 3) return "medium";
  return "high";
}

function normalizeTaskType(value: string | null) {
  const normalized = (value || "").toLowerCase();
  const allowed = [
    "workout",
    "cardio",
    "mobility",
    "nutrition",
    "hydration",
    "sleep",
    "steps",
    "recovery",
    "measurement",
  ];
  return allowed.includes(normalized) ? normalized : "workout";
}

function nonNegativeInt(value: unknown) {
  const parsed = int(value);
  return parsed == null || parsed < 0 ? null : parsed;
}

function nonNegativeNum(value: unknown) {
  const parsed = num(value);
  return parsed == null || parsed < 0 ? null : parsed;
}

function timeString(value: unknown) {
  const resolved = str(value);
  return resolved && /^\d{2}:\d{2}(:\d{2})?$/.test(resolved) ? resolved : null;
}

function rawBool(value: unknown, fallback: boolean) {
  return typeof value === "boolean" ? value : fallback;
}

function removeUndefined(value: Record<string, unknown>) {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => entry !== undefined),
  );
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
