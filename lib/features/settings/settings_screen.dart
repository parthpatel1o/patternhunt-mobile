import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/config/env.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_icons.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  String _category = 'all';
  bool _designer = false;
  bool _saving = false;
  bool _deleting = false;
  bool _synced = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _syncFromProfile(UserProfile profile) {
    _name.text = profile.displayName ?? '';
    _designer = profile.isPatternDesigner;
    _category = profile.defaultCategorySlug ?? 'all';
    _synced = true;
  }

  Future<void> _openLegal(String path) async {
    final uri = Uri.parse('${Env.siteUrl}$path');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final profileAsync = ref.watch(profileProvider);

    if (session == null) {
      return const LoginScreen();
    }

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (profile) {
        if (profile != null && !_synced) {
          _syncFromProfile(profile);
        }

        final showDesignerFields = _designer || (profile?.hasSubmittedPatterns ?? false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
          children: [
            Text(
              'Manage your profile and browsing preferences.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            if (profile?.email != null) ...[
              const SizedBox(height: 4),
              Text(
                profile!.email!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (profile != null && !profile.hasSubmittedPatterns) ...[
                    _DesignerToggle(
                      value: _designer,
                      onChanged: (v) => setState(() => _designer = v),
                    ),
                    if (showDesignerFields) const SizedBox(height: 16),
                  ],
                  if (showDesignerFields) ...[
                    Text(
                      'Designer name',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      decoration: InputDecoration(
                        hintText: 'Woolly Studio',
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 28),
                  Text(
                    'Browsing',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Default category',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _CategoryDropdown(
                    value: _category,
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _saving || _deleting ? null : () => _save(profile),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openLegal('/privacy'),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  ListTile(
                    title: const Text('Terms of Use'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openLegal('/terms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving || _deleting
                    ? null
                    : () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) context.go('/');
                      },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving || _deleting ? null : _confirmDeleteAccount,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                child: Text(_deleting ? 'Deleting account…' : 'Delete account'),
              ),
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
        'defaultCategorySlug': _category,
        'displayName': _name.text.trim(),
        'isPatternDesigner': profile?.hasSubmittedPatterns == true ? true : _designer,
      });
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your Pattern Hunt account, saved boards, votes, and any patterns you submitted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).delete('/me');
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account has been deleted')),
        );
        context.go('/');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

/// Matches web PatternDesignerToggle: label left, themed switch right.
class _DesignerToggle extends StatelessWidget {
  const _DesignerToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "I'm a pattern designer",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.accent,
                activeThumbColor: Colors.white,
                inactiveTrackColor: AppColors.border,
                inactiveThumbColor: Colors.white,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
          borderRadius: BorderRadius.circular(14),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Row(
                children: [
                  Icon(categoryIcon('all'), size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  const Text('All categories'),
                ],
              ),
            ),
            for (final c in AppConstants.instance.categories)
              DropdownMenuItem(
                value: c.slug,
                child: Row(
                  children: [
                    Icon(categoryIcon(c.slug), size: 18, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Text(c.name),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
