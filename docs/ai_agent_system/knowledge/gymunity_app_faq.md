# GymUnity App FAQ

## Purpose

This file provides answers to common questions about GymUnity and the TAIYO AI system. It serves as knowledge grounding for TAIYO when users ask app-related questions.

---

## What is GymUnity?

GymUnity is a multi-role fitness platform that connects members, coaches, sellers, and administrators. It is built with Flutter for the mobile app, Supabase for the backend, and Azure AI Foundry for the TAIYO AI system.

## What is TAIYO?

TAIYO is GymUnity's built-in AI system. It provides personalized fitness coaching, nutrition guidance, workout planning, store recommendations, and operational support. TAIYO stands for the AI brand name used across the entire GymUnity platform.

## What are the user roles?

| Role | Purpose |
| --- | --- |
| Member | Uses the app for workouts, nutrition, coaching, shopping, and AI guidance. |
| Coach | Provides coaching services, manages clients, and uses TAIYO Copilot for client insights. |
| Seller | Manages a store, lists products, and fulfills orders. |
| Admin | Manages platform operations, payments, payouts, and system health. |

## How does TAIYO work?

GymUnity separates three responsibilities:

- **Flutter** renders the app interface and displays structured TAIYO cards.
- **Supabase** handles authentication, data storage, permissions (RLS), business rules, and context building.
- **Azure AI Foundry** handles AI reasoning, knowledge retrieval, safety review, and structured response generation.

The flow is: Flutter → Supabase Edge Function → Azure AI Foundry → Structured JSON → Flutter UI.

## How do I create a workout plan?

1. Open TAIYO from the member home screen.
2. Tap the Plan Builder icon.
3. Answer the guided questionnaire: your goal, fitness level, available days, time, equipment, and any injuries.
4. TAIYO generates a personalized workout plan draft.
5. Review the plan and activate it.
6. Follow your daily agenda and log your progress.

## What is the daily brief?

The TAIYO Daily Brief is a personalized daily recommendation card that considers your readiness, sleep, workout history, nutrition, and progress to recommend today's training decision, nutrition focus, and motivation.

## How does readiness scoring work?

You can log your daily readiness by rating:

- **Energy level** (1–5)
- **Soreness level** (1–5)
- **Stress level** (1–5)
- **Available time** (minutes)
- **Training location** (gym, home, outdoor, travel)

TAIYO combines these inputs with your workout history to calculate a readiness score (0–100) and recommends appropriate training intensity.

## How do coaching subscriptions work?

1. Browse available coaches in the Coach Marketplace.
2. Review coach profiles, packages, and reviews.
3. Choose a package and request a subscription.
4. Once activated, you get access to the Coach Hub: messaging, check-ins, resources, habit tracking, and session bookings.
5. Your coach can see only the data you allow through privacy settings.

## How does coach privacy work?

Members control what data their coach can see through visibility settings:

- Workout plans and adherence
- Progress (weight, measurements)
- Nutrition data (meals, hydration)
- Store activity (purchases)

Coaches can only access data the member has explicitly allowed. TAIYO Coach Copilot also respects these settings.

## How does the store work?

1. Browse products in the store catalog.
2. Add items to favorites or cart.
3. Proceed to checkout with a shipping address.
4. Track your order status.
5. TAIYO can recommend products based on your fitness context.

## What is TAIYO Premium?

TAIYO Premium is the AI subscription tier that unlocks advanced AI features. It uses in-app purchases through Apple App Store or Google Play Store. When TAIYO Premium is enabled, some AI features require an active subscription.

## How do I delete my account?

1. Go to Settings.
2. Tap Delete Account.
3. Confirm the deletion.
4. Your account will be soft-deleted first, then hard-deleted after a grace period.

All personal data, workout history, nutrition data, and AI memories will be permanently removed.

## What happens if TAIYO is unavailable?

If Azure AI Foundry is temporarily unavailable:

- The app continues to function normally for all non-AI features.
- The daily brief falls back to a locally-built summary from your active plan and nutrition data.
- Chat features show an appropriate error message.
- No data is lost. TAIYO will resume when the service recovers.

## Is my data secure?

- All data is stored in Supabase with Row Level Security (RLS).
- Azure API keys and secrets are never stored in the mobile app.
- Coach access is controlled by member consent through visibility settings.
- Payment processing uses secure, verified integrations (Paymob for coach payments, App Store/Play Store for subscriptions).
- Admin access is controlled through explicit permission checks.
