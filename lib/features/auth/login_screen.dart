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

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (_signup) {
        await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {
            'is_pattern_designer': _designer,
            if (_designer) 'display_name': _name.text.trim(),
          },
        );
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
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

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => setState(() => _signup = !_signup),
          child: Text(_signup ? 'Already have an account? Log in' : 'New here? Create an account'),
        ),
      ],
    );
  }
}
