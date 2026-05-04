# TAIYO Context Schemas

## Member Context

Input: `{ "date": "YYYY-MM-DD" }`

Output includes profile, readiness, latest workout, adherence, nutrition status, progress, safety flags, and data quality.

## Nutrition Guidance

Input: `{ "request_type": "nutrition_guidance", "date": "YYYY-MM-DD" }`

Output:

```json
{
  "nutrition_status": "on_track",
  "calorie_guidance": "string",
  "protein_focus": "string",
  "hydration_focus": "string",
  "meal_suggestion": "string",
  "warning": "string",
  "confidence": "low | medium | high"
}
```

## Store Recommendations

Input: `{ "request_type": "store_recommendations", "limit": 3 }`

Output:

```json
{
  "recommendation_type": "fitness_support",
  "reason": "string",
  "products": [
    {
      "product_id": "uuid",
      "name": "string",
      "why_recommended": "string",
      "priority": "low | medium | high"
    }
  ],
  "disclaimer": "Recommendations are based on fitness context, not medical advice."
}
```
