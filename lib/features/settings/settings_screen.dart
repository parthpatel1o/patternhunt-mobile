import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  bool _designer = false;
  String _category = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _syncFromProfile(UserProfile profile) {
    _name.text = profile.displayName ?? '';
    _designer = profile.isPatternDesigner;
    _category = profile.defaultCategorySlug ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (profile) {
        if (profile != null && _name.text.isEmpty && (profile.displayName?.isNotEmpty ?? false)) {
          _syncFromProfile(profile);
        } else if (profile != null && !_designer && profile.isPatternDesigner) {
          _syncFromProfile(profile);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (profile?.email != null) Text(profile!.email!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            if (profile?.isPatternDesigner ?? false)
              ListTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: const Text('My patterns'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/mine'),
              ),
            if (profile != null && !profile.hasSubmittedPatterns)
              SwitchListTile(
                title: const Text('Register as a pattern designer'),
                value: _designer,
                onChanged: (v) => setState(() => _designer = v),
              ),
            if (_designer || (profile?.hasSubmittedPatterns ?? false)) ...[
              const SizedBox(height: 8),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Designer name')),
            ],
            const SizedBox(height: 12),
        DropdownMenu<String>(
          initialSelection: _category,
          label: const Text('Default category'),
          dropdownMenuEntries: [
            DropdownMenuEntry(value: 'all', label: 'All categories'),
            for (final c in AppConstants.instance.categories)
              DropdownMenuEntry(value: c.slug, label: c.name),
          ],
          onSelected: (v) => setState(() => _category = v ?? 'all'),
        ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _saving ? null : () => _save(profile), child: Text(_saving ? 'Saving…' : 'Save settings')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('Log out'),
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
        'defaultCategorySlug': _category,
      });
      ref.invalidate(profileProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
