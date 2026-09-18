import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';

void main() {
  test('food history reads root madeAt and object obtainedPlace', () {
    final history = FoodHistoryDetail.fromJson({
      'food': {'id': 10, 'name': '계란볶음밥'},
      'madeAt': '2026-09-15T03:04:05.000Z',
      'specialIngredients': [
        {
          'ingredientId': 20,
          'name': '강화 순무',
          'quantity': 1,
          'rarity': 'LEGENDARY',
          'obtainedPlace': {'id': 30, 'name': '강화도'},
        },
      ],
      'normalIngredients': [],
    });

    expect(history.food.madeAt, DateTime.utc(2026, 9, 15, 3, 4, 5));
    expect(history.specialIngredients.single.obtainedPlace, '강화도');
  });

  test('my foods reads object sourcePlace and remains string compatible', () {
    final objectPlace = UserFood.fromJson({
      'id': 1,
      'foodId': 10,
      'name': '계란볶음밥',
      'specialIngredients': [
        {
          'ingredientId': 20,
          'name': '강화 순무',
          'quantity': 1,
          'sourcePlace': {'id': 30, 'name': '강화도'},
        },
      ],
    });
    final stringPlace = UserFoodSpecialIngredient.fromJson({
      'ingredientId': 20,
      'name': '강화 순무',
      'quantity': 1,
      'sourcePlace': '강화도',
    });

    expect(objectPlace.specialIngredients.single.sourcePlace, '강화도');
    expect(stringPlace.sourcePlace, '강화도');
  });

  test('ingredient drop probabilities retain server percentile bounds', () {
    final detail = IngredientDetail.fromJson({
      'id': 1,
      'name': '계란',
      'quantity': 0,
      'obtained': false,
      'acquisition': {
        'dropProbabilities': [
          {
            'policyCode': 'GAP_LOW',
            'minGapPercentile': 0.1,
            'maxGapPercentile': 0.4,
            'probability': 0.7,
          },
        ],
      },
    });

    final probability = detail.acquisition!.dropProbabilities.single;
    expect(probability.minGapPercentile, 0.1);
    expect(probability.maxGapPercentile, 0.4);
    expect(probability.probability, 0.7);
  });
}
