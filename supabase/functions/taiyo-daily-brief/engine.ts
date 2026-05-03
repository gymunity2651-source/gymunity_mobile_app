export type DailyBriefStatus =
  | "success"
  | "needs_more_context"
  | "blocked_for_safety"
  | "error";

export type RiskLevel = "low" | "medium" | "high";
export type Confidence = "low" | "medium" | "high";

export type MemberDailyContext = {
  member_id: string;
  role: "member";
  profile: {
    goal: string;
    fitness_level: string;
    injuries: string[];
  };
  readiness: {
    score: number | null;
    sleep_hours: number | null;
    energy_level: string;
    soreness_level: string;
    stress_level: string;
    notes: string;
  };
  latest_workout: {
    date: string | null;
    focus: string;
    completed: boolean;
    difficulty_score: number | null;
  };
  weekly_adherence: {
    planned_workouts: number;
    completed_workouts: number;
    adherence_rate: number;
  };
  nutrition_status: {
    calorie_signal: string;
    protein_signal: string;
    hydration_signal: string;
    latest_checkin_note: string;
  };
  progress: {
    latest_weight: number | null;
    weight_trend: string;
    progress_note: string;
  };
  safety_flags: string[];
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
};

export type NormalizedDailyBrief = {
  request_type: "daily_member_brief";
  status: DailyBriefStatus;
  result: {
    training_decision: string;
    workout_focus: string;
    nutrition_focus: string;
    risk_level: RiskLevel;
    motivation_message: string;
    safety_notes: string[];
  };
  data_quality: {
    missing_fields: string[];
    confidence: Confidence;
  };
  metadata: {
    source: "supabase_edge_function";
    generated_at: string;
    debug_context?: MemberDailyContext;
    raw_text?: string;
    persisted?: boolean;
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

export function dateOnly(value: Date | string | null | undefined): string {
  if (!value) return new Date().toISOString().split("T")[0];
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return new Date().toISOString().split("T")[0];
  }
  return date.toISOString().split("T")[0];
}

export function buildMemberContext(
  memberId: string,
  rawContext: unknown,
): MemberDailyContext {
  const raw = obj(rawContext);
  const memberProfile = obj(raw.member_profile);
  const readiness = obj(raw.readiness);
  const recentSessions = arr(raw.recent_sessions).map(obj);
  const recentTaskLogs = arr(raw.recent_task_logs).map(obj);
  const todayTasks = arr(raw.today_tasks).map(obj);
  const nutrition = obj(raw.nutrition);
  const nutritionTarget = obj(nutrition.target);
  const latestWeight = obj(raw.latest_weight);
  const memories = obj(raw.memories);

  const goal = normalizeGoal(str(memberProfile.goal));
  const fitnessLevel = normalizeFitnessLevel(
    str(memberProfile.experience_level),
  );
  const injuries = compactStrings([
    ...strings(memberProfile.injuries),
    ...strings(memberProfile.limitations),
    ...memoryValues(memories.limitations),
    ...memoryValues(memories.injuries),
  ]);

  const latestWorkout = recentSessions[0] || {};
  const adherence = weeklyAdherence(recentTaskLogs, todayTasks);
  const safetyFlags = safetyFlagsFrom({
    readiness,
    recentTaskLogs,
    injuries,
  });

  const missingFields = compactStrings([
    goal === "unknown" ? "profile.goal" : null,
    fitnessLevel === "unknown" ? "profile.fitness_level" : null,
    Object.keys(readiness).length ? null : "readiness",
    todayTasks.length || recentTaskLogs.length ? null : "workout_activity",
    Object.keys(nutritionTarget).length ? null : "nutrition_target",
    Object.keys(latestWeight).length ? null : "latest_weight",
  ]);

  const readinessScore = num(readiness.readiness_score);
  const hydrationMl = num(nutrition.hydration_ml_today);
  const hydrationTarget = num(nutritionTarget.hydration_ml);
  const plannedMeals = num(nutrition.planned_meals_today);
  const loggedMeals = num(nutrition.meal_logs_today);

  return {
    member_id: memberId,
    role: "member",
    profile: {
      goal,
      fitness_level: fitnessLevel,
      injuries,
    },
    readiness: {
      score: readinessScore,
      sleep_hours: num(readiness.sleep_hours),
      energy_level: levelFromFivePoint(readiness.energy_level),
      soreness_level: levelFromFivePoint(readiness.soreness_level),
      stress_level: levelFromFivePoint(readiness.stress_level),
      notes: str(readiness.note) || "",
    },
    latest_workout: {
      date: dateOnlyOrNull(latestWorkout.performed_at),
      focus: str(obj(latestWorkout.summary_json).day_focus) ||
        str(obj(latestWorkout.summary_json).focus) ||
        str(latestWorkout.title) ||
        "unknown",
      completed: latestWorkout.completed === true ||
        (num(latestWorkout.completion_rate) ?? 0) >= 80 ||
        Boolean(str(latestWorkout.performed_at)),
      difficulty_score: num(latestWorkout.difficulty_score),
    },
    weekly_adherence: adherence,
    nutrition_status: {
      calorie_signal: mealSignal(loggedMeals, plannedMeals),
      protein_signal: mealSignal(loggedMeals, plannedMeals, "unknown"),
      hydration_signal: hydrationSignal(hydrationMl, hydrationTarget),
      latest_checkin_note: str(obj(nutrition.last_nutrition_checkin).notes) ||
        "",
    },
    progress: {
      latest_weight: num(latestWeight.weight_kg),
      weight_trend: weightTrend(
        num(latestWeight.weight_kg),
        num(memberProfile.current_weight_kg),
      ),
      progress_note: str(obj(raw.latest_checkin).wins) || "",
    },
    safety_flags: safetyFlags,
    data_quality: {
      missing_fields: missingFields,
      confidence: confidenceFor(missingFields, readinessScore),
    },
  };
}

export function buildOrchestratorInput(memberContext: MemberDailyContext) {
  return {
    request_type: "daily_member_brief",
    user_role: "member",
    member_context: memberContext,
    response_format: "json",
    instruction: "Return only valid JSON. Do not return markdown.",
  };
}

export function normalizeAiDailyBrief(
  aiOutput: unknown,
  memberContext: MemberDailyContext,
  options: { generatedAt?: string; debug?: boolean } = {},
): NormalizedDailyBrief {
  const generatedAt = options.generatedAt || new Date().toISOString();
  const parsed = typeof aiOutput === "string"
    ? parseJsonFromText(aiOutput)
    : aiOutput;
  const raw = obj(parsed);

  if (!Object.keys(raw).length) {
    return {
      request_type: "daily_member_brief",
      status: "error",
      result: emptyResult(
        "TAIYO could not return a valid daily brief right now.",
      ),
      data_quality: memberContext.data_quality,
      metadata: {
        source: "supabase_edge_function",
        generated_at: generatedAt,
        ...(options.debug
          ? {
            debug_context: memberContext,
            raw_text: typeof aiOutput === "string"
              ? aiOutput.slice(0, 2000)
              : undefined,
          }
          : {}),
      },
    };
  }

  const result = obj(raw.result);
  const riskLevel = risk(str(result.risk_level) || str(raw.risk_level));
  const status = normalizeStatus(
    str(raw.status),
    riskLevel,
    memberContext.safety_flags,
  );

  return {
    request_type: "daily_member_brief",
    status,
    result: {
      training_decision: str(result.training_decision) ||
        str(raw.training_decision) || "",
      workout_focus: str(result.workout_focus) || str(raw.workout_focus) || "",
      nutrition_focus: str(result.nutrition_focus) ||
        str(raw.nutrition_focus) || "",
      risk_level: riskLevel,
      motivation_message: str(result.motivation_message) ||
        str(raw.motivation_message) || "",
      safety_notes: compactStrings([
        ...strings(result.safety_notes),
        ...strings(raw.safety_notes),
      ]),
    },
    data_quality: memberContext.data_quality,
    metadata: {
      source: "supabase_edge_function",
      generated_at: generatedAt,
      ...(options.debug ? { debug_context: memberContext } : {}),
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

export function briefPersistencePayload(
  memberId: string,
  targetDate: string,
  rawContext: unknown,
  brief: NormalizedDailyBrief,
) {
  const raw = obj(rawContext);
  const activePlan = obj(raw.active_plan);
  const todayDay = obj(raw.today_day);
  const primaryTask =
    arr(raw.today_tasks).map(obj).find((task) => task.is_required === true) ||
    arr(raw.today_tasks).map(obj)[0] ||
    {};
  const readinessScore = num(obj(raw.readiness).readiness_score) ?? 50;

  return {
    member_id: memberId,
    brief_date: targetDate,
    plan_id: str(activePlan.id),
    day_id: str(todayDay.id),
    primary_task_id: str(primaryTask.id),
    readiness_score: Math.round(Math.max(0, Math.min(100, readinessScore))),
    intensity_band: brief.result.risk_level === "high"
      ? "red"
      : brief.result.risk_level === "medium"
      ? "yellow"
      : "green",
    coach_mode: Boolean(
      str(activePlan.coach_id) || str(obj(raw.active_subscription).coach_id),
    ),
    recommended_workout_json: {
      training_decision: brief.result.training_decision,
      workout_focus: brief.result.workout_focus,
    },
    habit_focus_json: {
      motivation_message: brief.result.motivation_message,
    },
    nutrition_priority_json: {
      nutrition_focus: brief.result.nutrition_focus,
    },
    recap_json: {
      safety_notes: brief.result.safety_notes,
      status: brief.status,
    },
    recommended_actions_json: [],
    why_short: brief.result.motivation_message ||
      brief.result.training_decision || "",
    signals_used: compactStrings([
      "daily readiness",
      "workout adherence",
      "nutrition status",
      "progress signals",
    ]),
    confidence: brief.data_quality.confidence === "high"
      ? 0.88
      : brief.data_quality.confidence === "medium"
      ? 0.68
      : 0.45,
    source_context_json: {
      request_type: brief.request_type,
      status: brief.status,
      result: brief.result,
      data_quality: brief.data_quality,
      generated_at: brief.metadata.generated_at,
    },
  };
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
  return "unknown";
}

function levelFromFivePoint(value: unknown) {
  const resolved = num(value);
  if (resolved == null) return "unknown";
  if (resolved <= 2) return "low";
  if (resolved === 3) return "medium";
  return "high";
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

function mealSignal(
  loggedMeals: number | null,
  plannedMeals: number | null,
  missing: "unknown" | "low" = "unknown",
) {
  if (loggedMeals == null || plannedMeals == null || plannedMeals <= 0) {
    return missing;
  }
  const ratio = loggedMeals / plannedMeals;
  if (ratio < 0.6) return "low";
  if (ratio > 1.2) return "high";
  return "on_track";
}

function hydrationSignal(
  hydrationMl: number | null,
  hydrationTarget: number | null,
) {
  if (hydrationMl == null || hydrationTarget == null || hydrationTarget <= 0) {
    return "unknown";
  }
  return hydrationMl >= hydrationTarget * 0.65 ? "on_track" : "low";
}

function weightTrend(latest: number | null, profileWeight: number | null) {
  if (latest == null || profileWeight == null) return "unknown";
  const delta = latest - profileWeight;
  if (Math.abs(delta) < 0.5) return "stable";
  return delta > 0 ? "up" : "down";
}

function safetyFlagsFrom(input: {
  readiness: Record<string, unknown>;
  recentTaskLogs: Record<string, unknown>[];
  injuries: string[];
}) {
  const flags = new Set<string>();
  if (!Object.keys(input.readiness).length) flags.add("missing_readiness_data");
  const readinessScore = num(input.readiness.readiness_score);
  if (readinessScore != null && readinessScore < 35) {
    flags.add("very_low_readiness");
  }

  for (const log of input.recentTaskLogs) {
    const painScore = num(log.pain_score);
    const text = [
      str(log.note),
      str(log.swap_reason),
      str(log.actual_exercise_title),
    ].filter(Boolean).join(" ").toLowerCase();
    if (painScore != null && painScore >= 7) flags.add("severe_pain");
    if (painScore != null && painScore >= 4) flags.add("pain_during_movement");
    addTextSafetyFlags(text, flags);
  }

  addTextSafetyFlags(input.injuries.join(" ").toLowerCase(), flags);
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
}

function confidenceFor(
  missingFields: string[],
  readinessScore: number | null,
): Confidence {
  if (missingFields.length >= 4 || readinessScore == null) return "low";
  if (missingFields.length >= 2) return "medium";
  return "high";
}

function normalizeStatus(
  value: string | null,
  riskLevel: RiskLevel,
  safetyFlags: string[],
): DailyBriefStatus {
  if (
    value === "success" ||
    value === "needs_more_context" ||
    value === "blocked_for_safety" ||
    value === "error"
  ) {
    return value;
  }
  const highRiskFlags = [
    "chest_pain",
    "fainting",
    "breathing_difficulty",
    "severe_pain",
  ];
  if (
    riskLevel === "high" &&
    safetyFlags.some((flag) => highRiskFlags.includes(flag))
  ) {
    return "blocked_for_safety";
  }
  return "success";
}

function risk(value: string | null): RiskLevel {
  if (value === "high" || value === "medium" || value === "low") return value;
  return "low";
}

function emptyResult(message: string) {
  return {
    training_decision: "",
    workout_focus: "",
    nutrition_focus: "",
    risk_level: "low" as const,
    motivation_message: message,
    safety_notes: [],
  };
}

function dateOnlyOrNull(value: unknown) {
  const resolved = str(value);
  if (!resolved) return null;
  return dateOnly(resolved);
}

function memoryValues(value: unknown): string[] {
  const raw = obj(value);
  return compactStrings([
    str(raw.value),
    ...strings(raw.values),
  ]);
}

function compactStrings(values: Array<string | null | undefined>) {
  return Array.from(
    new Set(
      values.filter((value): value is string => Boolean(value && value.trim())),
    ),
  );
}
