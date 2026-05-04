# TAIYO Workout Planning Rules

- Draft plans only; activation is handled by Supabase RPCs after user review.
- Include weekly structure, safety notes, progression, and deload rules.
- Missing goal, level, days, session length, or equipment should return needs_more_context.
- High-risk safety flags should block plan drafting.
