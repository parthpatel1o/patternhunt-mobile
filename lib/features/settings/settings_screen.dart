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
import '../../core/utils/slugify.dart';
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

        final showDesignerFields =
            _designer || (profile?.hasSubmittedPatterns ?? false);
        final isDesigner = profile?.isPatternDesigner ?? false;
        final displayName = (profile?.displayName?.trim().isNotEmpty ?? false)
            ? profile!.displayName!.trim()
            : null;
        final email = profile?.email;
        final initialSource = displayName ?? email ?? '?';
        final initial = initialSource.isEmpty
            ? '?'
            : initialSource.substring(0, 1).toUpperCase();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
          children: [
            _ProfileIdentityCard(
              initial: initial,
              title: displayName ?? 'Your account',
              email: email,
              isDesigner: isDesigner,
              onViewPublicProfile: displayName != null
                  ? () => context.push(creatorPath(displayName))
                  : null,
            ),
            if (isDesigner) ...[
              const SizedBox(height: 16),
              _SectionLabel('Designer'),
              const SizedBox(height: 8),
              _NavCard(
                children: [
                  _ProfileNavTile(
                    icon: Icons.grid_view_rounded,
                    label: 'My patterns',
                    subtitle: 'Edit, archive, or delete submissions',
                    onTap: () => context.go('/mine'),
                  ),
                  _ProfileNavTile(
                    icon: Icons.insights_outlined,
                    label: 'Insights',
                    subtitle: 'Views, upvotes, saves, and clicks',
                    onTap: () => context.go('/insights'),
                    showDividerAbove: true,
                  ),
                  _ProfileNavTile(
                    icon: Icons.add_rounded,
                    label: 'Submit a pattern',
                    subtitle: 'Publish something new to the board',
                    onTap: () => context.go('/submit'),
                    showDividerAbove: true,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _SectionLabel('Settings'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 20),
                  ],
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
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed:
                        _saving || _deleting ? null : () => _save(profile),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      disabledBackgroundColor: AppColors.primary,
                      disabledForegroundColor: AppColors.primaryForeground,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _NavCard(
              children: [
                _ProfileNavTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _openLegal('/privacy'),
                ),
                _ProfileNavTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Use',
                  onTap: () => _openLegal('/terms'),
                  showDividerAbove: true,
                ),
              ],
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
                child:
                    Text(_deleting ? 'Deleting account…' : 'Delete account'),
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
        'isPatternDesigner':
            profile?.hasSubmittedPatterns == true ? true : _designer,
      });
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.6,
        color: AppColors.muted,
      ),
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.initial,
    required this.title,
    required this.email,
    required this.isDesigner,
    this.onViewPublicProfile,
  });

  final String initial;
  final String title;
  final String? email;
  final bool isDesigner;
  final VoidCallback? onViewPublicProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.9),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryForeground,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        height: 1.15,
                      ),
                ),
                if (email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                ],
                if (isDesigner) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Pattern designer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryForeground,
                          ),
                        ),
                      ),
                      if (onViewPublicProfile != null)
                        GestureDetector(
                          onTap: onViewPublicProfile,
                          child: const Text(
                            'View public page',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ProfileNavTile extends StatelessWidget {
  const _ProfileNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.showDividerAbove = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDividerAbove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDividerAbove)
          const Divider(height: 1, color: AppColors.border),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                subtitle == null ? 14 : 12,
                10,
                subtitle == null ? 14 : 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(icon, size: 20, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.foreground,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
                trackOutlineColor:
                    const WidgetStatePropertyAll(Colors.transparent),
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
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.muted,
          ),
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
                    Icon(
                      categoryIcon(c.slug),
                      size: 18,
                      color: AppColors.accent,
                    ),
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
