import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signup = false;
  bool _designer = false;
  bool _loading = false;
  String? _error;
  String? _signupSuccessEmail;

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
      _signup = false;
      _error = null;
      _password.clear();
      _name.clear();
    });
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_signup) {
        final email = _email.text.trim();
        final response = await auth.signUp(
          email: email,
          password: _password.text,
          emailRedirectTo: '${Env.normalizedApiBaseUrl.replaceAll('/api/v1', '')}/auth/callback',
          data: {
            'is_pattern_designer': _designer,
            if (_designer) 'display_name': _name.text.trim(),
          },
        );
        if (response.session == null) {
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
      if (mounted) context.go('/');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Widget _buildSignupSuccess() {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.foreground,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
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
        Text('Account created', style: titleStyle),
        const SizedBox(height: 12),
        Text(
          'We sent a confirmation link to $_signupSuccessEmail.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Open that email and confirm your account, then come back here to log in.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: _resetSignupSuccess,
          child: const Text('Back to log in'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_signupSuccessEmail != null) {
      return _buildSignupSuccess();
    }

    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.foreground,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(_signup ? 'Create account' : 'Log in', style: titleStyle),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _loading ? null : _googleSignIn,
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        if (_signup) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Register as a pattern designer'),
            value: _designer,
            onChanged: (v) => setState(() => _designer = v),
          ),
          if (_designer) ...[
            const SizedBox(height: 8),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Designer name')),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.destructive)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: Text(_loading ? 'Please wait…' : (_signup ? 'Sign up' : 'Log in')),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                  _signup = !_signup;
                  _error = null;
                }),
          child: Text(_signup ? 'Already have an account? Log in' : 'New here? Create an account'),
        ),
      ],
    );
  }
}
