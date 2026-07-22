import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pigfig_button.dart';
import '../../../shared/widgets/pigfig_logo.dart';
import '../../../shared/widgets/role_toggle.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authRepository = AuthRepository();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.adopter;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (result.role == UserRole.adopter) {
        Navigator.of(context).pushReplacementNamed('/adopter');
      } else {
        Navigator.of(context).pushReplacementNamed('/grower');
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToRegister() {
    Navigator.of(context).pushNamed('/register', arguments: _selectedRole);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 84),
              const PigFigLogo(size: 74, variant: PigFigLogoVariant.symbol),
              const SizedBox(height: 12),
              Text('Pig.Fig.', style: AppTextStyles.display(fontSize: 34)),
              const SizedBox(height: 4),
              Text(
                '나의 무화과를 만나러 가요 🌱',
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              RoleToggle(
                selected: _selectedRole,
                onChanged: (role) => setState(() => _selectedRole = role),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: '이메일'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.errorRed,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PigFigButton.primary(
                label: '로그인',
                onPressed: _submit,
                loading: _loading,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '비밀번호 찾기',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '|',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.dotInactive,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _goToRegister,
                    child: Text(
                      '회원가입',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.badgeGreenText,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.dotInactive)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('간편 로그인', style: AppTextStyles.caption()),
                  ),
                  const Expanded(child: Divider(color: AppColors.dotInactive)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('카카오 로그인은 준비 중이에요')),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kakaoYellow,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    '카카오로 계속하기',
                    style: AppTextStyles.button(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
