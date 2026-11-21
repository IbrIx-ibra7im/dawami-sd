import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/permissions/role_manager.dart';
import '../../data/repositories/app_repository.dart';
import '../home/home_screen.dart';
import '../fingerprint/fingerprint_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'admin@dawami.edu');
  final _passwordController = TextEditingController(text: '00000');
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال البريد الإلكتروني أو اسم المستخدم');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال كلمة المرور (00000 للإدارة)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<AppRepository>();
      final success = await repo.login(email, password);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تم تسجيل الدخول بنجاح بصلاحية: ${RoleManager.getRoleDisplayName(repo.currentRole)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Safe Navigation: Clear route stack so logout and back button never pop to black screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _fillAdminCredentials() {
    setState(() {
      _emailController.text = 'admin@dawami.edu';
      _passwordController.text = '00000';
      _errorMessage = null;
    });
  }

  Future<void> _handleBiometricLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final localAuth = LocalAuthentication();
      bool canCheck = false;
      try {
        canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      } catch (_) {}

      if (canCheck) {
        final authenticated = await localAuth.authenticate(
          localizedReason: 'يرجى تأكيد البصمة الحيوية للدخول إلى لوحة التحكم',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );
        if (!authenticated) {
          setState(() {
            _errorMessage = 'تم إلغاء التحقق من البصمة';
            _isLoading = false;
          });
          return;
        }
      }

      _fillAdminCredentials();
      await _handleLogin();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر مسح بصمة الجهاز: $e. يمكنك تسجيل الدخول بكلمة المرور 00000';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepository>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('تسجيل الدخول ولوحة الصلاحيات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : AppColors.darkBlue,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primaryBlue),
                tooltip: 'العودة لشاشة البصمة',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const FingerprintScreen(isInitialScreen: true)),
                    (route) => false,
                  );
                },
              ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon / Logo
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.turquoise],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withAlpha(50),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      'دوامي',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'نظام ذكي لإدارة الحضور والإنصراف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'للطلاب والموظفين والشركات والمؤسسات والمستشفيات',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Admin Credentials Quick Card (Special Notice for 00000 password)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primaryBlue.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: AppColors.primaryBlue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حساب الإدارة المعتمد',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'البريد: admin@dawami.edu | كلمة المرور: 00000',
                                style: TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _fillAdminCredentials,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('تعبئة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email Field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني / اسم المستخدم',
                      hintText: 'admin@dawami.edu',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field with Eye Toggle
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      hintText: '00000',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        tooltip: _isPasswordVisible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Error Message Banner
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.danger.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),

                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'يتم التحقق من الصلاحية وكلمة المرور 00000 قبل فتح النظام',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Quick Role Selector for Testing / Demonstration
                  const Text(
                    'التبديل السريع للأدوار للتجربة:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildRoleChip(repo, UserRole.superAdmin, 'مدير (00000)'),
                      _buildRoleChip(repo, UserRole.registrationStaff, 'مسجل'),
                      _buildRoleChip(repo, UserRole.supervisor, 'مشرف'),
                      _buildRoleChip(repo, UserRole.attendanceOfficer, 'مشرف الحضور'),
                      _buildRoleChip(repo, UserRole.viewer, 'عرض فقط'),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 14),

                  // زر البصمة في الأسفل (الذهاب لشاشة تسجيل بصمة الطلاب الحيوية وبصمة الجهاز)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.turquoise.withAlpha(120),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.turquoise.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fingerprint_rounded, color: AppColors.turquoise, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'تسجيل حضور الطلاب بالبصمة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.fingerprint_rounded, size: 24, color: Colors.white),
                            label: const Text(
                              'شاشة تسجيل الحضور بالبصمة',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.turquoise,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FingerprintScreen(isInitialScreen: true),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.security_rounded, size: 18, color: AppColors.primaryBlue),
                            label: const Text(
                              'دخول المدير ببصمة الجهاز (Windows Hello)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.primaryBlue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isLoading ? null : _handleBiometricLogin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(AppRepository repo, UserRole role, String label) {
    final isSelected = repo.currentRole == role;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.primaryBlue,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          final roleStr = RoleManager.toRoleString(role);
          setState(() {
            _emailController.text = role == UserRole.superAdmin ? 'admin@dawami.edu' : '$roleStr@dawami.edu';
            _passwordController.text = '00000';
            _errorMessage = null;
          });
          repo.switchUserRole(role);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم ضبط النموذج على دور: ${RoleManager.getRoleDisplayName(role)}'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }
}
