# TAIYO Context Schemas

This document defines the input/output schemas for every TAIYO Edge Function context endpoint.

---

## 1. Member Daily Context

**Edge Function:** `taiyo-member-context`

**Input:**

```json
{
  "date": "2026-05-22"
}
```

**Output:**

```json
{
  "member_id": "uuid",
  "role": "member",
  "profile": {
    "goal": "fat_loss | muscle_gain | strength | general_fitness",
    "fitness_level": "beginner | intermediate | advanced",
    "injuries": ["lower_back", "left_knee"]
  },
  "readiness": {
    "score": 72,
    "sleep_hours": 7.5,
    "energy_level": "medium | high | low",
    "soreness_level": "low | medium | high",
    "stress_level": "low | medium | high",
    "notes": "Feeling good but left shoulder is tight"
  },
  "latest_workout": {
    "date": "2026-05-21",
    "focus": "Upper Body Push",
    "completed": true,
    "difficulty_score": 7
  },
  "weekly_adherence": {
    "planned_workouts": 4,
    "completed_workouts": 3,
    "adherence_rate": 0.75
  },
  "nutrition_status": {
    "calorie_signal": "on_track | low | high",
    "protein_signal": "on_track | low | high",
    "hydration_signal": "on_track | low",
    "latest_checkin_note": "Feeling hungry in the evenings"
  },
  "progress": {
    "latest_weight": 78.5,
    "weight_trend": "stable | up | down",
    "progress_note": "Hit a new PR on bench press"
  },
  "safety_flags": ["pain_during_movement"],
  "data_quality": {
    "missing_fields": ["nutrition_target"],
    "confidence": "medium"
  }
}
```

---

## 2. Daily Brief

**Edge Function:** `taiyo-daily-brief`

**Input:**

```json
{
  "date": "2026-05-22"
}
```

**Output:**

```json
{
  "request_type": "daily_member_brief",
  "status": "success | needs_more_context | blocked_for_safety | error",
  "result": {
    "training_decision": "train_as_planned | reduce_intensity | active_recovery | rest",
    "workout_focus": "Upper body push and mobility work",
    "nutrition_focus": "Increase protein intake and stay hydrated",
    "risk_level": "low | medium | high",
    "motivation_message": "Consistency builds strength. You're on the right track.",
    "safety_notes": ["Watch left shoulder during overhead movements"]
  },
  "data_quality": {
    "missing_fields": [],
    "confidence": "high"
  },
  "metadata": {
    "source": "supabase_edge_function",
    "generated_at": "2026-05-22T08:30:00.000Z",
    "persisted": true
  }
}
```

---

## 3. Nutrition Context

**Edge Function:** `taiyo-nutrition-context`

**Input (Context Only):**

```json
{
  "request_type": "nutrition_context",
  "date": "2026-05-22"
}
```

**Output (Context Only):**

```json
{
  "request_type": "nutrition_context",
  "status": "success",
  "result": {
    "member_id": "uuid",
    "target_date": "2026-05-22",
    "profile": { "dietary_preferences": "balanced" },
    "target": { "target_calories": 2200, "protein_g": 150, "hydration_ml": 3000 },
    "active_meal_plan": { "id": "uuid", "title": "Balanced Cutting Plan" },
    "day": { "target_calories": 2200, "hydration_ml": 3000 },
    "planned_meals": [],
    "meal_logs": [],
    "hydration_logs": [],
    "recent_checkins": [],
    "summary": {
      "planned_meals": 4,
      "logged_meals": 2,
      "calories_logged": 1100,
      "protein_logged_g": 65,
      "hydration_logged_ml": 1200,
      "calorie_target": 2200,
      "protein_target_g": 150,
      "hydration_target_ml": 3000
    }
  }
}
```

**Input (Guidance):**

```json
{
  "request_type": "nutrition_guidance",
  "date": "2026-05-22"
}
```

**Output (Guidance):**

```json
{
  "request_type": "nutrition_guidance",
  "status": "success",
  "result": {
    "nutrition_status": "on_track | under_logged | hydration_gap | needs_setup",
    "calorie_guidance": "You're on track. Aim for 1100 more calories today.",
    "protein_focus": "Add a protein-rich meal to close the 85g gap.",
    "hydration_focus": "You need about 1800ml more water today.",
    "meal_suggestion": "Grilled chicken, rice, and steamed vegetables.",
    "warning": "General fitness nutrition guidance only, not medical nutrition advice.",
    "confidence": "high"
  },
  "data_quality": {
    "missing_fields": [],
    "confidence": "high"
  }
}
```

---

## 4. Store Recommendations

**Edge Function:** `taiyo-store-recommendations`

**Input:**

```json
{
  "request_type": "store_recommendations",
  "limit": 3
}
```

**Output:**

```json
{
  "request_type": "store_recommendations",
  "status": "success",
  "result": {
    "recommendation_type": "fitness_support",
    "reason": "Based on your fat loss goal and low protein intake today",
    "products": [
      {
        "product_id": "uuid",
        "name": "Whey Protein Isolate",
        "why_recommended": "Supports your protein target of 150g. You're at 65g today.",
        "priority": "high"
      },
      {
        "product_id": "uuid",
        "name": "Electrolyte Tablets",
        "why_recommended": "Hydration is below 50% of target for today.",
        "priority": "medium"
      }
    ],
    "disclaimer": "Recommendations are based on fitness context, not medical advice."
  }
}
```

---

## 5. Coach Client Brief

**Edge Function:** `taiyo-coach-client-brief`

**Input:**

```json
{
  "client_id": "uuid",
  "brief_type": "weekly_summary | quick_check"
}
```

**Output:**

```json
{
  "request_type": "coach_client_brief",
  "status": "success",
  "result": {
    "client_status": "on_track | watch | at_risk",
    "summary": "Client is training consistently, 75% adherence this week.",
    "red_flags": [],
    "suggested_action": "Send a positive reinforcement message.",
    "suggested_message": "Great consistency this week! How are you feeling about the plan so far?",
    "privacy_notes": ["Nutrition data excluded: member has not enabled nutrition visibility."]
  }
}
```

---

## 6. Workout Planner

**Edge Function:** `taiyo-workout-planner`

**Input:**

```json
{
  "request_type": "workout_plan_draft",
  "planner_answers": {
    "goal": "muscle_gain",
    "level": "intermediate",
    "days_per_week": 4,
    "session_minutes": 60,
    "equipment": "full_gym",
    "injuries": ["left_knee"]
  },
  "session_id": "uuid or null",
  "draft_id": "uuid or null"
}
```

**Output:**

```json
{
  "request_type": "workout_plan_draft",
  "status": "success | needs_more_context | blocked_for_safety",
  "result": {
    "title": "Intermediate Hypertrophy 4-Day Split",
    "summary": "Upper/Lower split focused on muscle growth, avoiding left knee loading.",
    "duration_weeks": 4,
    "level": "intermediate",
    "weekly_structure": [],
    "safety_notes": ["Avoiding deep squats due to left knee limitation."],
    "progression_rule": "Increase weight by 5% when all reps are completed for 2 sessions.",
    "deload_rule": "Week 4: reduce volume by 40% and intensity by 20%.",
    "activation_allowed": true
  },
  "missing_fields": [],
  "persistence": {
    "persisted": true,
    "draft_id": "uuid",
    "session_id": "uuid"
  }
}
```

---

## 7. Admin Ops Brief

**Edge Function:** `taiyo-admin-ops-brief`

**Input:**

```json
{
  "brief_type": "daily_ops | payment_review | payout_review",
  "date_from": "2026-05-15",
  "date_to": "2026-05-22"
}
```

**Output:**

```json
{
  "request_type": "admin_ops_brief",
  "status": "success",
  "result": {
    "issue_type": "operational_summary",
    "status_summary": "14 payments processed, 2 pending payouts, no settlement gaps.",
    "risk_level": "low",
    "recommended_admin_action": "Review 2 pending payouts for coach 'Ahmed K'.",
    "audit_notes": ["All Paymob settlements matched within 24h."]
  }
}
```

---

## 8. Seller Copilot

**Edge Function:** `taiyo-seller-copilot`

**Input:**

```json
{
  "brief_type": "product_insights | order_summary",
  "date_from": "2026-05-15",
  "date_to": "2026-05-22"
}
```

**Output:**

```json
{
  "request_type": "seller_copilot",
  "status": "success",
  "result": {
    "seller_status": "healthy | needs_attention | action_required",
    "summary": "3 products active, 2 orders pending fulfillment, revenue up 12% this week.",
    "insights": [
      "Whey Protein Isolate is your top seller with 8 orders this month.",
      "Resistance Band Set has zero sales — consider updating the description or price."
    ],
    "suggested_action": "Fulfill 2 pending orders to maintain shipping ratings.",
    "order_alerts": ["Order #1234 awaiting fulfillment for 3+ days."]
  }
}
```
