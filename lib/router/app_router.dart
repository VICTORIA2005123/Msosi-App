import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/restaurant.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/home/chatbot_screen.dart';
import '../screens/orders/order_history_screen.dart';
import '../screens/restaurant/restaurant_list_screen.dart';
import '../widgets/student_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Notifies [GoRouter] when auth state changes so [redirect] runs again.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._ref) {
    _ref.listen(authProvider, (previous, next) => notifyListeners());
  }

  final Ref _ref;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = GoRouterRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: refresh,
    initialLocation: '/login',
    redirect: (context, state) {
      final user = ref.read(authProvider);
      final path = state.uri.path;

      final authRoute = path == '/login' || path == '/register';

      if (user == null) {
        return authRoute ? null : '/login';
      }

      if (user.isAdmin) {
        if (path.startsWith('/vendor')) return null;
        return '/vendor';
      }

      if (authRoute || path == '/') return '/restaurants';
      if (path == '/vendor') return '/restaurants';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/vendor',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StudentShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/restaurants',
                builder: (context, state) => const RestaurantListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) {
                  final restaurant = state.extra as Restaurant?;
                  return ChatbotScreen(restaurant: restaurant);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (context, state) => const OrderHistoryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
