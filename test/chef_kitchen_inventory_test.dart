import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goyohaeng_app/api/api.dart';
import 'package:goyohaeng_app/screens/food/chef_kitchen_screen.dart';
import 'package:goyohaeng_app/theme/app_theme.dart';

void main() {
  Food food({required bool canMake}) => Food(
        id: 1,
        name: '계란볶음밥',
        canMake: canMake,
        isCompleted: false,
        ingredients: [
          FoodIngredient(
            id: 10,
            name: '계란',
            requiredQuantity: 2,
            ownedQuantity: canMake ? 2 : 1,
            enough: canMake,
          ),
        ],
      );

  Future<void> pumpScreen(WidgetTester tester, {required bool canMake}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ChefKitchenScreen(food: food(canMake: canMake)),
        ),
      );

  testWidgets('재료가 충분하면 준비 안내와 요리 시작 버튼이 활성화된다', (tester) async {
    await pumpScreen(tester, canMake: true);

    expect(find.text('필요한 재료가 모두 준비되었어요'), findsOneWidget);
    expect(find.text('지금 가진 재료로 만들 수 있어요.'), findsOneWidget);
    expect(find.text('사용된 재료'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '요리 시작'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('재료가 부족하면 부족 안내와 비활성 요리 시작 버튼을 표시한다', (tester) async {
    await pumpScreen(tester, canMake: false);

    expect(find.text('아직 부족한 재료가 있어요'), findsOneWidget);
    expect(find.text('부족한 재료를 모으면 요리를 시작할 수 있어요.'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, '요리 시작'),
          )
          .onPressed,
      isNull,
    );
  });
}
