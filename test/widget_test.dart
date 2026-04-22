import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_food_chatbot/main.dart';

void main() {
  testWidgets('App should load', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CampusFoodApp(),
      ),
    );
    expect(find.byType(CampusFoodApp), findsOneWidget);
  });
}
