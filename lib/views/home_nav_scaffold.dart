import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'budgets/budgets_screen.dart';
import 'insights/insights_screen.dart';
import 'subscriptions/subscriptions_screen.dart';
import 'categories/categories_screen.dart';
import 'widgets/floating_nav_bar.dart';

class HomeNavScaffold extends StatefulWidget {
  const HomeNavScaffold({super.key});

  @override
  State<HomeNavScaffold> createState() => _HomeNavScaffoldState();
}

class _HomeNavScaffoldState extends State<HomeNavScaffold> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    BudgetsScreen(),
    SubscriptionsScreen(),
    InsightsScreen(),
    CategoriesScreen(),
  ];

  static const _navItems = [
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
    FloatingNavItem(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      label: 'Insights',
    ),
    FloatingNavItem(
      icon: Icons.category_outlined,
      selectedIcon: Icons.category_rounded,
      label: 'Rules',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ModernFloatingNavBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: _navItems,
      ),
    );
  }
}
