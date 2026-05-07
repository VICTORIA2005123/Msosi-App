import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/restaurant.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/vendor_onboarding_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/home/chatbot_screen.dart';
import '../screens/orders/order_history_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/restaurant/restaurant_list_screen.dart';
import '../screens/restaurant/menu_screen.dart';
import '../screens/vendor/vendor_scan_screen.dart';
import '../screens/vendor/vendor_stats_screen.dart';
import '../screens/vendor/vendor_menu_screen.dart';
import '../widgets/student_shell.dart';
import '../widgets/vendor_shell.dart';

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
      final vendorOnboarding = path == '/vendor-onboarding';

      // Not logged in → force to login (unless already on auth route)
      if (user == null) {
        return authRoute ? null : '/login';
      }

      // Vendor role → vendor dashboard
      if (user.isVendor) {
        if (path.startsWith('/vendor')) return null;
        if (authRoute) return '/vendor';
        // Allow access to vendor onboarding even though already vendor
        return null;
      }

      // Admin role → vendor dashboard (admins can manage too)
      if (user.isAdmin) {
        if (path.startsWith('/vendor')) return null;
        return '/vendor';
      }

      // Student role
      if (authRoute || path == '/') return '/restaurants';
      if (vendorOnboarding) return null; // Allow students to access onboarding
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
        path: '/vendor-onboarding',
        builder: (context, state) => const VendorOnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return VendorShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vendor',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vendor/menu',
                builder: (context, state) => const VendorMenuScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vendor/stats',
                builder: (context, state) => const VendorStatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vendor/scan',
                builder: (context, state) => const VendorScanScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/menu/:restaurantId',
        builder: (context, state) {
          final restaurantId = state.pathParameters['restaurantId']!;
          final restaurant = state.extra as Restaurant?;
          return MenuScreen(
            restaurantId: restaurantId,
            restaurant: restaurant,
          );
        },
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
