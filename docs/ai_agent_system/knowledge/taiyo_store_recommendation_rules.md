# TAIYO Store Recommendation Rules

## Purpose

This file defines how TAIYO recommends store products to members based on fitness context, goals, and nutrition gaps. Recommendations are fitness support, never medical advice.

## 1. Core Principles

- Recommend only active, in-stock products from the Supabase product catalog.
- Never recommend products that are archived, out of stock, or from inactive sellers.
- Every recommendation must explain WHY the product supports the member's fitness or nutrition goal.
- Products are fitness support tools, not medical treatments.
- Maximum recommendations per request: 5 products.

## 2. Recommendation Categories

| Category | When to Recommend | Example Products |
| --- | --- | --- |
| Protein support | Low protein intake, muscle gain goal, post-workout nutrition gap | Protein powder, protein bars, high-protein snacks |
| Hydration support | Low hydration signals, high-intensity training days | Electrolyte supplements, water bottles, hydration tablets |
| Recovery support | High soreness, post-intense training, active recovery days | Foam rollers, massage balls, recovery bands |
| Training equipment | Home training, equipment upgrade needs, plan adaptation | Resistance bands, dumbbells, yoga mats, jump ropes |
| Nutrition support | Meal prep needs, calorie tracking, nutrition gaps | Meal prep containers, food scales, vitamin supplements |
| Performance support | Advanced members, progressive overload phase | Lifting belts, wrist wraps, training gloves |

## 3. Goal-Product Mapping

| Member Goal | Priority Recommendations |
| --- | --- |
| Fat loss | Protein supplements, portion control tools, hydration support |
| Muscle gain | Protein supplements, creatine, training accessories |
| Strength | Performance accessories (belts, wraps), protein support |
| General fitness | Hydration support, basic equipment, recovery tools |
| Endurance | Electrolytes, hydration support, energy supplements |

## 4. Context Signals for Recommendations

TAIYO uses these signals to personalize recommendations:

- **Training focus today**: recommend products relevant to today's workout.
- **Nutrition gaps**: if protein or hydration is low, suggest relevant products.
- **Recent purchases**: avoid recommending products the member already bought recently.
- **Favorites**: boost products the member has favorited but not purchased.
- **Cart items**: do not re-recommend items already in the cart.
- **Recommendation history**: avoid repetitive recommendations.

## 5. Prohibited Claims

TAIYO must never:

- Recommend products as treatment for any disease or medical condition.
- Claim a product will cure pain, injury, or illness.
- Use clinical or pharmaceutical language ("this will reduce inflammation").
- Recommend weight-loss pills, fat burners, or appetite suppressants.
- Frame supplements as mandatory ("you need this supplement").
- Make guaranteed outcome claims ("this will help you lose 5kg").

## 6. Recommendation Priority

Each recommended product must have a priority level:

| Priority | Meaning |
| --- | --- |
| `high` | Directly addresses a current gap (e.g., protein powder when protein intake is very low) |
| `medium` | Supports the current goal or training phase |
| `low` | Nice to have, general fitness support |

## 7. Disclaimer Requirements

Every recommendation response must include:

```
"Recommendations are based on fitness context, not medical advice."
```

If supplements are recommended:

```
"Supplements support a balanced diet and training program. They do not replace proper nutrition or medical advice."
```

## 8. Output Schema

```json
{
  "recommendation_type": "fitness_support | nutrition_support | recovery_support | equipment",
  "reason": "Why these products were recommended based on context",
  "products": [
    {
      "product_id": "uuid",
      "name": "Product name",
      "why_recommended": "Specific reason for this member",
      "priority": "low | medium | high"
    }
  ],
  "disclaimer": "Recommendations are based on fitness context, not medical advice."
}
```

## 9. Recommendation Limits

- Maximum 5 products per request.
- Avoid recommending products from the same category more than twice.
- Rotate recommendations across sessions to avoid fatigue.
- If no relevant products match the context, return an empty list with a note rather than forcing irrelevant recommendations.

## 10. Member History Awareness

- Check `product_favorites` to boost favorited items.
- Check `store_cart_items` to avoid duplicating cart items.
- Check `orders` and `order_items` to avoid recommending recently purchased items.
- Check `member_product_recommendations` to avoid repeating recent recommendations.
