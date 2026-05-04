# GymUnity App FAQ

GymUnity separates responsibilities:

- Flutter renders the app and structured TAIYO cards.
- Supabase handles auth, RLS, context, business rules, logs, and persistence.
- Azure AI Foundry handles orchestration, reasoning, knowledge, and safety review.

TAIYO Premium unlocks AI features only. Store products and coaching packages use separate purchase flows.
