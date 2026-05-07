import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () async => await ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), width: 2),
              ),
              child: const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.deepOrange,
                child: Icon(Icons.person_rounded, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              user.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            Text(
              user.email,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                user.role.name.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 40),
            _buildProfileItem(
              context,
              icon: Icons.history_rounded,
              title: 'Order History',
              onTap: () => context.push('/orders'),
            ),
            _buildProfileItem(
              context,
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              onTap: () {},
            ),
            if (!user.isVendor && !user.isAdmin)
              _buildProfileItem(
                context,
                icon: Icons.storefront_rounded,
                title: 'Become a Vendor',
                subtitle: 'Manage your own restaurant',
                onTap: () => context.push('/vendor-onboarding'),
                highlight: true,
              ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: highlight 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.02),
        border: Border.all(
          color: highlight 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(
            icon, 
            color: highlight 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          title: Text(
            title, 
            style: TextStyle(
              fontWeight: FontWeight.w700, 
              fontSize: 15,
              color: highlight ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          subtitle: subtitle != null 
            ? Text(
                subtitle, 
                style: TextStyle(
                  fontSize: 12, 
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ) 
            : null,
          trailing: Icon(
            Icons.arrow_forward_ios_rounded, 
            size: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
