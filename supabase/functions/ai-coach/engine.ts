export const memoryAllowlist = [
  "preferred_workout_style",
  "disliked_exercise_types",
  "best_duration_minutes",
  "consistency_blockers",
  "motivation_triggers",
  "schedule_constraints",
  "nutrition_issues",
  "preferred_coaching_tone",
] as const;

export type CoachContext = Record<string, unknown>;

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

export function intish(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? Math.round(parsed) : null;
}

export function numish(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function boolish(value: unknown): boolean {
  return value === true || value === "true";
}

export function dateOnly(value: Date | string | null | undefined): string {
  if (!value) return new Date().toISOString().split("T")[0];
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return new Date().toISOString().split("T")[0];
  }
  return date.toISOString().split("T")[0];
}

export function startOfWeek(value: Date | string | null | undefined): string {
  const base = new Date(`${dateOnly(value)}T00:00:00Z`);
  const weekday = base.getUTCDay() || 7;
  base.setUTCDate(base.getUTCDate() - weekday + 1);
  return dateOnly(base);
}

export function signalsForBrief(context: CoachContext): {
  readinessScore: number;
  intensityBand: "green" | "yellow" | "red";
  adherenceRatio: number;
  missedLast7d: number;
  coachMode: boolean;
  avgSessionMinutes: number | null;
} {
  const readiness = obj(context.readiness);
  const activePlan = obj(context.active_plan);
  const recentSessions = arr(context.recent_sessions).map(obj);
  const recentTaskLogs = arr(context.recent_task_logs).map(obj);

  const readinessScore = clamp(
    intish(readiness.readiness_score) ?? inferReadinessScore(recentSessions),
    0,
    100,
  );
  const intensityBand = readinessScore >= 70
    ? "green"
    : readinessScore >= 45
    ? "yellow"
    : "red";

  const recent7dLogs = recentTaskLogs.filter((log) => {
    const loggedAt = str(log.logged_at);
    if (!loggedAt) return false;
    const logged = new Date(loggedAt);
    const daysAgo = (Date.now() - logged.getTime()) / 86400000;
    return daysAgo <= 7;
  });
  const completedWeight = recent7dLogs.reduce((sum, log) => {
    const status = (str(log.completion_status) || "").toLowerCase();
    if (status === "completed") return sum + 1;
    if (status === "partial") return sum + 0.5;
    return sum;
  }, 0);
  const missedLast7d = recent7dLogs.filter((log) => {
    const status = (str(log.completion_status) || "").toLowerCase();
    return status === "missed" || status === "skipped";
  }).length;
  const adherenceRatio = recent7dLogs.length
    ? Number((completedWeight / recent7dLogs.length).toFixed(2))
    : 0;

  const avgSessionMinutes = recentSessions.length
    ? Math.round(
      recentSessions.reduce(
        (sum, session) => sum + (intish(session.duration_minutes) ?? 0),
        0,
      ) / recentSessions.length,
    )
    : null;

  const coachMode = Boolean(
    str(obj(context.active_subscription).coach_id) ||
      str(activePlan.coach_id) ||
      str(activePlan.source) !== "ai" ||
      str(activePlan.adaptation_mode) === "coach_locked",
  );

  return {
    readinessScore,
    intensityBand,
    adherenceRatio,
    missedLast7d,
    coachMode,
    avgSessionMinutes,
  };
}

export function buildDailyBrief(context: CoachContext, targetDate: string) {
  const signals = signalsForBrief(context);
  const todayDay = obj(context.today_day);
  const todayTasks = arr(context.today_tasks).map(obj);
  const nutrition = obj(context.nutrition);
  const primaryTask = todayTasks.find((task) => boolish(task.is_required)) ||
    todayTasks[0] ||
    {};
  const target = obj(nutrition.target);
  const plannedMeals = intish(nutrition.planned_meals_today) ?? 0;
  const loggedMeals = intish(nutrition.meal_logs_today) ?? 0;
  const hydrationMl = intish(nutrition.hydration_ml_today) ?? 0;
  const hydrationTarget = intish(target.hydration_ml) ?? 2500;
  const focus = str(todayDay.focus) || str(primaryTask.title) || "Daily movement";
  const durationMinutes = clamp(
    intish(obj(context.readiness).available_minutes) ??
      intish(primaryTask.duration_minutes) ??
      signals.avgSessionMinutes ??
      35,
    12,
    90,
  );

  const habitFocus = signals.missedLast7d >= 3
    ? {
      title: "Remove the start barrier",
      body:
        "Win the first 10 minutes. Show up, start the warm-up, and let the rest of the session follow.",
    }
    : {
      title: "Protect the planned training window",
      body:
        "Keep today anchored to the time you already have instead of negotiating with the session later.",
    };

  const nutritionPriority = hydrationMl < Math.round(hydrationTarget * 0.4)
    ? {
      title: "Front-load hydration",
      body:
        "You are behind your hydration target, so get water in early to keep training quality steady.",
    }
    : loggedMeals < plannedMeals
    ? {
      title: "Hit your next protein meal",
      body:
        "Meal adherence is lagging, so prioritize a simple protein-forward meal after training.",
    }
    : {
      title: "Keep meal rhythm stable",
      body:
        "Nutrition is mostly on track. Keep the timing predictable so recovery stays easy.",
    };

  const completed = todayTasks
    .filter((task) => ["completed", "partial"].includes((str(task.completion_status) || str(task.effective_status) || "").toLowerCase()))
    .map((task) => str(task.title) || "Completed task");
  const missed = todayTasks
    .filter((task) => ["missed", "skipped"].includes((str(task.completion_status) || str(task.effective_status) || "").toLowerCase()))
    .map((task) => str(task.title) || "Missed task");

  const recommendedWorkout = {
    "title": str(primaryTask.title) || str(todayDay.label) || "Recovery session",
    "focus": focus,
    "duration_minutes": durationMinutes,
    "task_id": str(primaryTask.id),
    "task_type": str(primaryTask.task_type) || "workout",
  };

  const whyShort = buildWhyShort({
    intensityBand: signals.intensityBand,
    readinessScore: signals.readinessScore,
    adherenceRatio: signals.adherenceRatio,
    hydrationMl,
    hydrationTarget,
    loggedMeals,
    plannedMeals,
    durationMinutes,
  });

  return {
    "brief_date": targetDate,
    "plan_id": str(obj(context.active_plan).id),
    "day_id": str(todayDay.id),
    "primary_task_id": str(primaryTask.id),
    "readiness_score": signals.readinessScore,
    "intensity_band": signals.intensityBand,
    "coach_mode": signals.coachMode,
    "recommended_workout_json": recommendedWorkout,
    "habit_focus_json": habitFocus,
    "nutrition_priority_json": nutritionPriority,
    "recap_json": {
      "completed": completed,
      "missed": missed,
      "tomorrow_focus": signals.missedLast7d >= 3
        ? "Use the easiest version of the next session to restart momentum."
        : "Keep tomorrow simple and repeat the same consistency standard.",
    },
    "recommended_actions_json": [
      "start_workout",
      "shorten_workout",
      "swap_workout",
      "move_to_tomorrow",
      "log_meal",
      "log_hydration",
      "ask_ai_why",
    ],
    "why_short": whyShort,
    "signals_used": compactStrings([
      "daily readiness",
      signals.missedLast7d >= 3 ? "recent adherence drop" : "recent consistency",
      hydrationMl < Math.round(hydrationTarget * 0.4)
        ? "hydration status"
        : loggedMeals < plannedMeals
        ? "meal adherence"
        : "current nutrition rhythm",
    ]),
    "confidence": signals.coachMode ? 0.82 : 0.89,
    "source_context_json": {
      "target_date": targetDate,
      "available_minutes": intish(obj(context.readiness).available_minutes),
      "planned_meals": plannedMeals,
      "meal_logs": loggedMeals,
      "hydration_ml": hydrationMl,
      "adherence_ratio_7d": signals.adherenceRatio,
    },
  };
}

export function buildAccountabilityNudges(
  context: CoachContext,
  targetDate: string,
) {
  const signals = signalsForBrief(context);
  const activePlan = obj(context.active_plan);
  const todayDay = obj(context.today_day);
  const nutrition = obj(context.nutrition);
  const nudges: Record<string, unknown>[] = [];
  const lastNutritionCheckin = obj(nutrition.last_nutrition_checkin);
  const mealLogs = intish(nutrition.meal_logs_today) ?? 0;
  const plannedMeals = intish(nutrition.planned_meals_today) ?? 0;

  if (signals.missedLast7d >= 4) {
    nudges.push({
      "nudge_type": "restart_week",
      "title": "Restart with the easy win",
      "body":
        "You have missed multiple planned tasks. TAIYO is recommending a lighter restart instead of another all-or-nothing day.",
      "action_type": "shorten_workout",
      "action_payload_json": {
        "plan_id": str(activePlan.id),
        "day_id": str(todayDay.id),
      },
      "why_short": "Recent adherence is sliding, so the next best move is to reduce friction.",
      "signals_used": ["missed workout streak", "recent adherence drop"],
      "confidence": 0.9,
      "external_key": `coach-nudge:${targetDate}:restart_week`,
    });
  }

  if (
    mealLogs < plannedMeals &&
    (plannedMeals > 0 || (intish(lastNutritionCheckin.adherence_score) ?? 100) < 60)
  ) {
    nudges.push({
      "nudge_type": "nutrition_inconsistency",
      "title": "Nutrition needs the easy version today",
      "body":
        "Keep today simple: log the next meal and close the gap before it turns into another missed day.",
      "action_type": "log_meal",
      "action_payload_json": { "target_date": targetDate },
      "why_short": "Meal completion is inconsistent, so TAIYO is pushing the smallest useful action.",
      "signals_used": ["meal adherence", "nutrition check-in"],
      "confidence": 0.84,
      "external_key": `coach-nudge:${targetDate}:nutrition_inconsistency`,
    });
  }

  if (signals.intensityBand === "red") {
    nudges.push({
      "nudge_type": "recovery_recommendation",
      "title": "Recovery should win today",
      "body":
        "Readiness is trending low. TAIYO recommends a lighter session or mobility block before pushing intensity.",
      "action_type": "open_ai",
      "action_payload_json": {
        "plan_id": str(activePlan.id),
        "day_id": str(todayDay.id),
      },
      "why_short": "Daily readiness suggests that pushing volume today will cost tomorrow.",
      "signals_used": ["daily readiness", "recent fatigue"],
      "confidence": 0.88,
      "external_key": `coach-nudge:${targetDate}:recovery_recommendation`,
    });
  }

  if (nudges.length === 0 && new Date(`${targetDate}T00:00:00Z`).getUTCDay() === 0) {
    nudges.push({
      "nudge_type": "weekly_reflection",
      "title": "Close the week on purpose",
      "body":
        "Take 60 seconds to review the week so TAIYO can tighten next week around your real adherence pattern.",
      "action_type": "share_weekly_summary",
      "action_payload_json": { "week_start": startOfWeek(targetDate) },
      "why_short": "Weekly reflection helps TAIYO adjust structure instead of just generating more content.",
      "signals_used": ["weekly cadence"],
      "confidence": 0.76,
      "external_key": `coach-nudge:${targetDate}:weekly_reflection`,
    });
  }

  return nudges.slice(0, 3);
}

export function buildWorkoutPrompt(input: {
  context: CoachContext;
  session: Record<string, unknown>;
  promptKind: string;
}) {
  const signals = signalsForBrief(input.context);
  const session = obj(input.session);
  const dayLabel = str(obj(session.summary_json).day_label) || "This session";
  const focus = str(obj(session.summary_json).day_focus) || "consistency";
  const paceDelta = numish(session.pace_delta_percent);

  if (input.promptKind === "post_workout") {
    return {
      "title": "Recovery next",
      "message":
        "Nice work. Log hydration, get a protein-forward meal in, and keep the rest of today low-friction so recovery is easy.",
      "why_short": "Post-workout recovery is the highest-value next action.",
      "signals_used": ["session completion", "nutrition coupling"],
      "confidence": 0.9,
    };
  }

  const paceLine = paceDelta == null
    ? "You are setting the tone for the rest of the session."
    : paceDelta >= 5
    ? "You are a little ahead of your usual pace, so keep rest honest."
    : paceDelta <= -5
    ? "You are a little behind your usual pace, so protect form and cut accessories if needed."
    : "You are close to your usual pace, so stay steady.";

  return {
    "title": `${dayLabel} prompt`,
    "message":
      `${paceLine} Today is about ${focus.toLowerCase()}, and TAIYO is keeping intensity ${signals.intensityBand}.`,
    "why_short": "The prompt is based on pace, readiness, and today\'s training focus.",
    "signals_used": compactStrings([
      paceDelta == null ? null : "pace vs usual",
      "daily readiness",
      "session focus",
    ]),
    "confidence": 0.86,
  };
}

export function buildMemoryUpserts(context: CoachContext) {
  const recentSessions = arr(context.recent_sessions).map(obj);
  const recentTaskLogs = arr(context.recent_task_logs).map(obj);
  const nutrition = obj(context.nutrition);
  const workoutTitles = recentSessions
    .map((session) => (str(session.title) || "").toLowerCase())
    .filter(Boolean);
  const avgSessionMinutes = recentSessions.length
    ? Math.round(
      recentSessions.reduce(
        (sum, session) => sum + (intish(session.duration_minutes) ?? 0),
        0,
      ) / recentSessions.length,
    )
    : null;
  const missedCount = recentTaskLogs.filter((log) => {
    const status = (str(log.completion_status) || "").toLowerCase();
    return status === "missed" || status === "skipped";
  }).length;
  const swapHeavy = recentTaskLogs.filter((log) => boolish(log.was_substituted));
  const mealLogs = intish(nutrition.meal_logs_today) ?? 0;
  const plannedMeals = intish(nutrition.planned_meals_today) ?? 0;

  const rows: Array<Record<string, unknown>> = [];
  if (avgSessionMinutes != null) {
    rows.push({
      "memory_key": "best_duration_minutes",
      "memory_value_json": { "value": avgSessionMinutes },
      "confidence": 0.77,
    });
  }
  if (missedCount >= 3) {
    rows.push({
      "memory_key": "consistency_blockers",
      "memory_value_json": { "values": ["time pressure", "decision fatigue"] },
      "confidence": 0.82,
    });
    rows.push({
      "memory_key": "schedule_constraints",
      "memory_value_json": { "value": "Shorter sessions work better on busy weeks." },
      "confidence": 0.8,
    });
  }
  if (mealLogs < plannedMeals) {
    rows.push({
      "memory_key": "nutrition_issues",
      "memory_value_json": { "value": "Meal completion becomes inconsistent on training days." },
      "confidence": 0.75,
    });
  }
  if (swapHeavy.length >= 2) {
    rows.push({
      "memory_key": "disliked_exercise_types",
      "memory_value_json": {
        "values": compactStrings(
          swapHeavy
            .map((log) => str(log.actual_exercise_title) || str(log.swap_reason))
            .slice(0, 3),
        ),
      },
      "confidence": 0.72,
    });
  }
  if (workoutTitles.length) {
    rows.push({
      "memory_key": "preferred_workout_style",
      "memory_value_json": {
        "value": workoutTitles.some((title) => title.includes("strength"))
          ? "strength-focused sessions"
          : "structured mixed sessions",
      },
      "confidence": 0.68,
    });
  }
  rows.push({
    "memory_key": "preferred_coaching_tone",
    "memory_value_json": { "value": "direct and concise" },
    "confidence": 0.66,
  });
  return rows.filter((row) => memoryAllowlist.includes(String(row.memory_key)));
}

export function compactStrings(values: Array<string | null | undefined>) {
  return Array.from(new Set(values.filter((value): value is string => Boolean(value && value.trim()))));
}

export function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function inferReadinessScore(recentSessions: Record<string, unknown>[]) {
  if (!recentSessions.length) {
    return 58;
  }
  const latest = recentSessions[0];
  const latestDuration = intish(latest.duration_minutes) ?? 35;
  return clamp(45 + Math.round(latestDuration * 0.4), 35, 78);
}

function buildWhyShort(input: {
  intensityBand: "green" | "yellow" | "red";
  readinessScore: number;
  adherenceRatio: number;
  hydrationMl: number;
  hydrationTarget: number;
  loggedMeals: number;
  plannedMeals: number;
  durationMinutes: number;
}) {
  if (input.intensityBand === "red") {
    return `Recovery wins today because readiness is ${input.readinessScore} and pushing harder would likely hurt adherence tomorrow.`;
  }
  if (input.adherenceRatio < 0.6) {
    return `Today stays focused and finishable because recent adherence has dipped and TAIYO is reducing decision fatigue first.`;
  }
  if (input.hydrationMl < Math.round(input.hydrationTarget * 0.4)) {
    return `Today keeps intensity controlled because hydration is lagging and TAIYO wants training quality without extra recovery cost.`;
  }
  if (input.loggedMeals < input.plannedMeals) {
    return `TAIYO kept today simple so training and nutrition can close the loop instead of competing for attention.`;
  }
  return `Your recent pattern supports a ${input.durationMinutes}-minute session today, so TAIYO is keeping the plan moving without unnecessary changes.`;
}
