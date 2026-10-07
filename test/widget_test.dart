import 'package:flutter_test/flutter_test.dart';
import 'package:fintor/main.dart';

void main() {
  testWidgets('FintorApp basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FintorApp());
    expect(find.byType(FintorApp), findsOneWidget);
  });
}
