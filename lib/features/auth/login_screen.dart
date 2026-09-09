import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/signup_welcome.dart';
import '../../core/config/env.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/google_logo.dart';

enum _AuthMode { login, signup, forgot }

/// Space below the status bar / screen top for all login ListViews.
const double _loginTopInset = 28;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.nextPath});

  /// Fallback post-login path when the route has no `?next=` query param
  /// (e.g. when embedded from Profile).
  final String? nextPath;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _designer = false;
  bool _loading = false;
  String? _error;
  String? _signupSuccessEmail;
  String? _forgotSuccessEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _resetSignupSuccess() {
    setState(() {
      _signupSuccessEmail = null;
      _mode = _AuthMode.login;
      _error = null;
      _password.clear();
      _name.clear();
    });
  }

  void _resetForgotSuccess() {
    setState(() {
      _forgotSuccessEmail = null;
      _mode = _AuthMode.login;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_mode == _AuthMode.forgot) {
        final email = _email.text.trim();
        await auth.resetPasswordForEmail(
          email,
          redirectTo: Env.authRedirectUrl,
        );
        setState(() {
          _forgotSuccessEmail = email;
        });
        return;
      }

      if (_mode == _AuthMode.signup) {
        final email = _email.text.trim();
        final response = await auth.signUp(
          email: email,
          password: _password.text,
          emailRedirectTo: Env.authRedirectUrl,
          data: {
            'is_pattern_designer': _designer,
            if (_designer) 'display_name': _name.text.trim(),
          },
        );
        if (response.session == null) {
          ref.read(pendingSignupWelcomeProvider.notifier).state = true;
          await markPendingSignupWelcome();
          setState(() {
            _signupSuccessEmail = email;
            _password.clear();
            _name.clear();
          });
          return;
        }
      } else {
        final response = await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (response.session == null) {
          setState(() => _error = 'Could not start a session. Check your email is confirmed.');
          return;
        }
      }
      if (mounted) context.go(_resolveNextPath());
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Prefer `?next=` from the current route, then [LoginScreen.nextPath], else `/`.
  String _resolveNextPath() {
    String? fromQuery;
    try {
      fromQuery = GoRouterState.of(context).uri.queryParameters['next'];
    } catch (_) {
      fromQuery = null;
    }
    return _safeInternalPath(fromQuery) ??
        _safeInternalPath(widget.nextPath) ??
        '/';
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Env.authRedirectUrl,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildEmailSuccess({
    required String title,
    required String body,
    required String hint,
    required VoidCallback onBack,
    String buttonLabel = 'Back to log in',
  }) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.foreground,
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, _loginTopInset, 24, 24),
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.mark_email_read_outlined, size: 32, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          Text(title, style: titleStyle),
          const SizedBox(height: 12),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: onBack, child: Text(buttonLabel)),
        ],
      ),
    );
  }

  Widget _buildSignupSuccess() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, _loginTopInset, 24, 24),
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.mark_email_read_outlined, size: 32, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          Text(
            'Check your email',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We sent a confirmation link to $_signupSuccessEmail. Tap it to confirm and log in.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _resetSignupSuccess, child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _buildForgotSuccess() {
    return _buildEmailSuccess(
      title: 'Check your email',
      body: 'If an account exists for $_forgotSuccessEmail, we sent a password reset link.',
      hint: 'Open the link in that email to choose a new password.',
      onBack: _resetForgotSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_signupSuccessEmail != null) {
      return _buildSignupSuccess();
    }
    if (_forgotSuccessEmail != null) {
      return _buildForgotSuccess();
    }

    final title = switch (_mode) {
      _AuthMode.login => 'Welcome back',
      _AuthMode.signup => 'Create account',
      _AuthMode.forgot => 'Reset password',
    };

    final subtitle = switch (_mode) {
      _AuthMode.login => 'Log in to vote on patterns and save your favourites. Designers can submit patterns too.',
      _AuthMode.signup => 'Join Pattern Hunt to vote, save favourites, and submit patterns.',
      _AuthMode.forgot => 'Enter your email and we’ll send a reset link.',
    };

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, _loginTopInset, 20, 40),
        children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mode != _AuthMode.forgot) ...[
                OutlinedButton(
                  onPressed: _loading ? null : _googleSignIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.foreground,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: GoogleLogo(size: 20),
                      ),
                      SizedBox(width: 12),
                      Text('Continue with Google'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'OR EMAIL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (_mode != _AuthMode.forgot) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                if (_mode == _AuthMode.login)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _mode = _AuthMode.forgot;
                                _error = null;
                              }),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.muted,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
              ],
              if (_mode == _AuthMode.signup) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Register as a pattern designer'),
                  value: _designer,
                  onChanged: (v) => setState(() => _designer = v),
                ),
                if (_designer) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: 'Designer name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.destructive)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.foreground,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _loading
                      ? 'Please wait…'
                      : switch (_mode) {
                          _AuthMode.login => 'Log in',
                          _AuthMode.signup => 'Sign up',
                          _AuthMode.forgot => 'Send reset link',
                        },
                ),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        if (_mode == _AuthMode.forgot) {
                          _mode = _AuthMode.login;
                        } else {
                          _mode = _mode == _AuthMode.signup ? _AuthMode.login : _AuthMode.signup;
                        }
                        _error = null;
                      }),
                child: Text(
                  switch (_mode) {
                    _AuthMode.login => 'Need an account? Sign up',
                    _AuthMode.signup => 'Already have an account? Log in',
                    _AuthMode.forgot => 'Back to log in',
                  },
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

/// Only allow in-app relative paths for post-login redirects.
String? _safeInternalPath(String? next) {
  if (next == null || next.isEmpty) return null;
  final decoded = Uri.decodeComponent(next);
  if (!decoded.startsWith('/') || decoded.startsWith('//')) return null;
  if (decoded.startsWith('/login')) return null;
  return decoded;
}
