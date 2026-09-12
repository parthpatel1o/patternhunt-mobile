import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/category_icons.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'profile_widgets.dart';

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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final profileAsync = ref.watch(profileProvider);

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/profile');
      });
      return const Center(child: CircularProgressIndicator());
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
        final canToggleDesigner =
            profile != null && !profile.hasSubmittedPatterns;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
            if (canToggleDesigner || showDesignerFields) ...[
              const ProfileSectionLabel('Profile'),
              const SizedBox(height: 8),
              ProfileNavCard(
                children: [
                  if (canToggleDesigner)
                    _SettingsToggleTile(
                      value: _designer,
                      onChanged: (v) => setState(() => _designer = v),
                      showDividerBelow: showDesignerFields,
                    ),
                  if (showDesignerFields)
                    _SettingsInputTile(
                      label: 'Designer name',
                      subtitle: 'Shown on your patterns',
                      controller: _name,
                      hintText: 'Woolly Studio',
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            const ProfileSectionLabel('Browsing'),
            const SizedBox(height: 8),
            ProfileNavCard(
              children: [
                _SettingsCategoryTile(
                  value: _category,
                  onChanged: (v) => setState(() => _category = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : () => _save(profile),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryForeground,
                  disabledBackgroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.primaryForeground,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                child: Text(_saving ? 'Saving…' : 'Save preferences'),
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
      if (mounted) showAppSnackBar(context, message: 'Settings saved');
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, message: e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.value,
    required this.onChanged,
    this.showDividerBelow = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "I'm a pattern designer",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.foreground,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Unlock submit tools and a public name',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
        ),
        if (showDividerBelow)
          const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

class _SettingsInputTile extends StatelessWidget {
  const _SettingsInputTile({
    required this.label,
    required this.subtitle,
    required this.controller,
    required this.hintText,
  });

  final String label;
  final String subtitle;
  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              filled: true,
              fillColor: AppColors.background,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  const _SettingsCategoryTile({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Default category',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Used when you open the rank board',
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          _CategoryDropdown(
            value: value,
            onChanged: onChanged,
          ),
        ],
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
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
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
