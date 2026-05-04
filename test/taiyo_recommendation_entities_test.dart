import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/nutrition/domain/entities/nutrition_entities.dart';
import 'package:my_app/features/store/domain/entities/store_recommendation_entity.dart';

void main() {
  test('maps TAIYO store recommendation response', () {
    final recommendations = StoreRecommendationsEntity.fromResponse(
      <String, dynamic>{
        'status': 'success',
        'result': <String, dynamic>{
          'recommendation_type': 'equipment_gap',
          'reason': 'Useful for home sessions.',
          'products': <Map<String, dynamic>>[
            <String, dynamic>{
              'product_id': 'product-1',
              'name': 'Resistance Band',
              'why_recommended': 'Supports warm-ups.',
              'priority': 'high',
              'price': 30,
              'currency': 'EGP',
            },
          ],
          'disclaimer':
              'Recommendations are based on fitness context, not medical advice.',
        },
        'data_quality': <String, dynamic>{'confidence': 'high'},
      },
    );

    expect(recommendations.status, 'success');
    expect(recommendations.products.single.productId, 'product-1');
    expect(recommendations.products.single.priority, 'high');
    expect(recommendations.confidence, 'high');
  });

  test('maps TAIYO nutrition guidance response', () {
    final guidance = NutritionGuidanceEntity.fromResponse(<String, dynamic>{
      'result': <String, dynamic>{
        'nutrition_status': 'hydration_gap',
        'calorie_guidance': 'Stay close to target.',
        'protein_focus': 'Add protein next meal.',
        'hydration_focus': 'Front-load water.',
        'meal_suggestion': 'Simple rice, chicken, and vegetables.',
        'warning': 'General guidance only.',
        'confidence': 'medium',
      },
    });

    expect(guidance.nutritionStatus, 'hydration_gap');
    expect(guidance.hydrationFocus, 'Front-load water.');
    expect(guidance.warning, 'General guidance only.');
  });
}
