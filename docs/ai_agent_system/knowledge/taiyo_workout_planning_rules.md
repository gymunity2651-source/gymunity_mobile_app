# TAIYO Workout Planning Rules

## Purpose

This file defines the rules TAIYO follows when creating or adapting workout plans. Plans are always drafts — activation into the database happens through Supabase RPCs after user review, never through direct AI action.

## 1. Core Principle

TAIYO drafts plans. The member reviews and activates them. TAIYO never auto-activates a plan. The `activation_allowed` flag means the plan is safe for user-reviewed activation, not automatic activation.

## 2. Required Information Before Drafting

Before generating a workout plan draft, TAIYO needs these critical inputs:

| Field | Required | Fallback |
| --- | --- | --- |
| Goal | Yes | If missing, return `needs_more_context` |
| Fitness level | Yes | If missing, return `needs_more_context` |
| Available days per week | Yes | If missing, return `needs_more_context` |
| Session duration (minutes) | Yes | If missing, return `needs_more_context` |
| Available equipment | Yes | If missing, return `needs_more_context` |
| Injuries or limitations | Recommended | If missing, apply conservative defaults |

If any of the 5 required fields are missing, TAIYO must return a `needs_more_context` response listing the missing fields.

## 3. Plan Structure Requirements

Every generated plan must include:

```json
{
  "title": "Descriptive plan name",
  "summary": "Brief plan overview",
  "duration_weeks": 4,
  "level": "beginner | intermediate | advanced",
  "weekly_structure": [
    {
      "week": 1,
      "days": [
        {
          "day_label": "Day 1",
          "focus": "Upper Body Push",
          "intensity": "moderate",
          "tasks": [
            {
              "title": "Exercise name",
              "task_type": "exercise | warmup | cooldown | rest",
              "sets": 3,
              "reps": "8-12",
              "duration_minutes": 5,
              "instructions": "Clear execution instructions"
            }
          ]
        }
      ]
    }
  ],
  "safety_notes": ["List of safety considerations"],
  "progression_rule": "How to progress week over week",
  "deload_rule": "When and how to deload",
  "activation_allowed": true
}
```

## 4. Split Patterns by Days Available

| Days/Week | Recommended Split |
| --- | --- |
| 2 | Full body A/B |
| 3 | Full body or Push/Pull/Legs |
| 4 | Upper/Lower or Push/Pull |
| 5 | Push/Pull/Legs + Upper/Lower or Body Part Split |
| 6 | Push/Pull/Legs × 2 or specialized split |

## 5. Goal-Specific Programming

| Goal | Rep Range | Rest Period | Tempo |
| --- | --- | --- | --- |
| Fat loss | 10–15 reps, circuits | 30–60 seconds | Moderate |
| Muscle gain | 8–12 reps | 60–90 seconds | Controlled |
| Strength | 3–6 reps | 2–3 minutes | Explosive |
| General fitness | 8–15 reps, mixed | 60–90 seconds | Moderate |
| Endurance | 15–20+ reps | 30–45 seconds | Steady |

## 6. Equipment Adaptation

| Equipment Available | Programming Approach |
| --- | --- |
| Full gym | Use barbells, dumbbells, cables, machines |
| Home with dumbbells | Dumbbell-focused with bodyweight accessories |
| Bodyweight only | Progressive bodyweight: push-ups, squats, lunges, planks, pull-ups |
| Resistance bands | Band-adapted compound and isolation movements |
| Minimal/travel | Bodyweight circuits, HIIT-style, no equipment needed |

## 7. Duration Scaling

| Available Time | Session Structure |
| --- | --- |
| 20–30 minutes | Compound movements only, supersets, minimal rest |
| 30–45 minutes | Compound focus with 1–2 accessories, moderate rest |
| 45–60 minutes | Full session: warmup, compounds, accessories, cooldown |
| 60–90 minutes | Extended session: warmup, compounds, accessories, isolation, cooldown |

## 8. Safety Checks Before Plan Delivery

Before returning a plan draft, TAIYO must verify:

- No exercise targets an injured or limited area listed in the member profile.
- Rest days are included (minimum 1 per week).
- Progressive overload is realistic (not exceeding 10% increase per week).
- Deload is scheduled (every 3–4 weeks for intermediate/advanced).
- Session duration matches available time.
- Equipment requirements match available equipment.

If any high-risk safety flag is present (`chest_pain`, `severe_pain`, `fainting`, `breathing_difficulty`), the plan must be blocked with `blocked_for_safety` status.

## 9. Plan Adaptation Rules

When adapting an existing plan (not creating new):

- Preserve the overall structure and goal.
- Adjust volume, intensity, or exercise selection based on the adjustment request.
- `shorten_workout`: reduce sets or remove accessory exercises.
- `swap_exercise`: replace with an equivalent exercise for the same muscle group.
- `move_to_tomorrow`: shift today's session to the next day.
- Log the reason for adaptation.

## 10. Progression and Deload Rules

Progression rule format:
```
"Increase weight by 2.5–5% when all prescribed reps are completed with good form for 2 consecutive sessions."
```

Deload rule format:
```
"Every 4th week, reduce volume by 40% and intensity by 20%. Maintain movement patterns. Focus on technique and recovery."
```
