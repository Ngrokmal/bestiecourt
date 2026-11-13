import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/design_tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });

    final AuthRepository repository = ref.read(authRepositoryProvider);

    if (_isSignUp) {
      final Result<SignUpOutcome> result = await repository.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
      });
      result.fold<void>(
        onSuccess: (SignUpOutcome outcome) {
          if (outcome == SignUpOutcome.emailConfirmationRequired) {
            setState(() {
              _message = 'অ্যাকাউন্ট তৈরি হয়েছে। ইমেইল ভেরিফিকেশন লিংকে ক্লিক '
                  'করার পর লগইন করুন।';
            });
          }
        },
        onFailure: (AppFailure failure) {
          setState(() {
            _message = failure.message;
          });
        },
      );
      return;
    }

    final Result<bool> signInResult = await repository.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _message = failureText(signInResult);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text('😂', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Roast My Bestie',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'বন্ধুকে চ্যালেঞ্জ করুন, ভোট দিন, মজার ফলাফল জানুন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_isSignUp) ...<Widget>[
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        maxLength: 24,
                        decoration: const InputDecoration(
                          labelText: 'ডিসপ্লে নাম',
                          hintText: 'যেমন: রোস্ট মাস্টার',
                          counterText: '',
                        ),
                        validator: (String? value) {
                          final String name = (value ?? '').trim();
                          if (name.length < 2 || name.length > 24) {
                            return 'নাম ২ থেকে ২৪ অক্ষরের হতে হবে।';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'ইমেইল'),
                      validator: (String? value) {
                        final String email = (value ?? '').trim();
                        if (!email.contains('@') || email.length < 5) {
                          return 'সঠিক ইমেইল দিন।';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'পাসওয়ার্ড'),
                      onFieldSubmitted: (String value) => _submit(),
                      validator: (String? value) {
                        if ((value ?? '').length < 6) {
                          return 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।';
                        }
                        return null;
                      },
                    ),
                    if (_message != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: AppColors.danger.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isSignUp ? 'অ্যাকাউন্ট খুলুন' : 'লগইন করুন'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _message = null;
                              });
                            },
                      child: Text(
                        _isSignUp
                            ? 'আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন'
                            : 'নতুন? অ্যাকাউন্ট খুলুন',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'শুধু মজার জন্য — কারো ক্ষতি করার জন্য নয়। '
                      'আপনার ডেটা RLS দিয়ে সুরক্ষিত।',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
