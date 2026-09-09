import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintor/views/widgets/floating_nav_bar.dart';

void main() {
  testWidgets('ModernFloatingNavBar renders items and responds to taps',
      (WidgetTester tester) async {
    int selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) {
              return ModernFloatingNavBar(
                currentIndex: selected,
                onTap: (idx) => setState(() => selected = idx),
                items: const [
                  FloatingNavItem(
                    icon: Icons.dashboard_outlined,
                    selectedIcon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                  ),
                  FloatingNavItem(
                    icon: Icons.pie_chart_outline_rounded,
                    selectedIcon: Icons.pie_chart_rounded,
                    label: 'Budgets',
                  ),
                  FloatingNavItem(
                    icon: Icons.repeat_rounded,
                    selectedIcon: Icons.repeat_on_rounded,
                    label: 'Bills',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Verify all 3 labels are displayed
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);

    // Tap on 'Budgets'
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();

    expect(selected, equals(1));
  });
}
