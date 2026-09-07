import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  bool _designer = false;
  bool _saving = false;
  bool _synced = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _syncFromProfile(UserProfile profile) {
    _name.text = profile.displayName ?? '';
    _designer = profile.isPatternDesigner;
    _synced = true;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final profileAsync = ref.watch(profileProvider);

    if (session == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text(
            'Profile',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Log in to manage your designer profile and account.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Log in'),
          ),
        ],
      );
    }

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (profile) {
        if (profile != null && !_synced) {
          _syncFromProfile(profile);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (profile?.email != null) ...[
              const SizedBox(height: 8),
              Text(profile!.email!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ],
            const SizedBox(height: 20),
            if (profile != null && !profile.hasSubmittedPatterns)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Register as a pattern designer'),
                value: _designer,
                onChanged: (v) => setState(() => _designer = v),
              ),
            if (_designer || (profile?.hasSubmittedPatterns ?? false)) ...[
              const SizedBox(height: 8),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Designer name')),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : () => _save(profile),
              child: Text(_saving ? 'Saving…' : 'Save profile'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save(UserProfile? profile) async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch('/me/settings', {
        'displayName': _name.text.trim(),
        'isPatternDesigner': profile?.hasSubmittedPatterns == true ? true : _designer,
      });
      ref.invalidate(profileProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
