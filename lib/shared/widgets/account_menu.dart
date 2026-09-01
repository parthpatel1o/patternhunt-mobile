import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';

void showAccountMenu(BuildContext context, WidgetRef ref) {
  final profile = ref.read(profileProvider).valueOrNull;
  final session = ref.read(sessionProvider);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session != null && profile?.email != null)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(profile!.displayName ?? profile.email!),
                subtitle: Text(profile.email!),
              ),
            if (profile?.isPatternDesigner ?? false)
              ListTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: const Text('My patterns'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/mine');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            if (session == null)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Log in'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/login');
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref.read(authSignOutProvider)();
                  if (context.mounted) context.go('/login');
                },
              ),
          ],
        ),
      );
    },
  );
}
