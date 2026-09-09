import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

/// Account avatar + dropdown matching web AccountMenu (minus Admin).
Future<void> showAccountMenu(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider).valueOrNull;
  final session = ref.read(sessionProvider);
  final email = profile?.email ?? session?.user.email;
  final isDesigner = profile?.isPatternDesigner ?? false;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (email != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    email,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              if (isDesigner) ...[
                _MenuTile(
                  icon: Icons.grid_view_rounded,
                  label: 'My patterns',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/mine');
                  },
                ),
                _MenuTile(
                  icon: Icons.insights_outlined,
                  label: 'Insights',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/insights');
                  },
                ),
              ],
              _MenuTile(
                icon: Icons.bookmark_outline,
                label: 'Saved',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/saved');
                },
              ),
              _MenuTile(
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/profile');
                },
              ),
              const Divider(height: 20),
              _MenuTile(
                icon: Icons.logout,
                label: 'Log out',
                destructive: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.destructive : AppColors.foreground;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
