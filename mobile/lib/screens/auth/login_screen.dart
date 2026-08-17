import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import 'email_verification_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _canUseBiometric = false;
  bool _hasSavedCredentials = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
    
    // Check biometric availability after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAvailability();
    });
  }

  Future<void> _checkBiometricAvailability() async {
    final biometricService = BiometricService();
    final isSupported = await biometricService.isDeviceSupported();
    final hasCreds = await biometricService.hasSavedCredentials();
    
    if (mounted) {
      setState(() {
        _canUseBiometric = isSupported;
        _hasSavedCredentials = hasCreds;
      });
      
      // Auto-prompt biometric if credentials are saved (with small delay for UI to settle)
      if (isSupported && hasCreds) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _loginWithBiometric();
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithBiometric() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithBiometric();
    
    if (!mounted) return;
    
    if (success) {
      _navigateAfterLogin(authProvider);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Prompt to enable biometric if device supports it
      if (_canUseBiometric) {
        await _promptEnableBiometric();
      }
      _navigateAfterLogin(authProvider);
    } else {
      // Check if the error is about email verification
      final errorMsg = authProvider.errorMessage ?? '';
      if (errorMsg.contains('verify your email')) {
        // Redirect to email verification screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: _emailController.text.trim(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg.isNotEmpty ? errorMsg : 'Login failed',
              style: FinzoTypography.bodyMedium(color: Colors.white),
            ),
            backgroundColor: FinzoColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FinzoRadius.sm)),
            margin: const EdgeInsets.all(FinzoSpacing.md),
          ),
        );
      }
      authProvider.clearError();
    }
  }

  Future<void> _promptEnableBiometric() async {
    final biometricService = BiometricService();
    final alreadyEnabled = await biometricService.isBiometricEnabled();
    
    if (alreadyEnabled) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FinzoRadius.lg)),
        title: Row(
          children: [
            Icon(Icons.fingerprint, color: FinzoTheme.brandAccent(context)),
            const SizedBox(width: FinzoSpacing.sm),
            Text('Quick Login', style: FinzoTypography.titleLarge(color: FinzoTheme.textPrimary(context))),
          ],
        ),
        content: Text(
          'Enable fingerprint, Face ID, or PIN for faster login next time?',
          style: FinzoTypography.bodyMedium(color: FinzoTheme.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Not Now', style: FinzoTypography.labelMedium(color: FinzoTheme.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinzoTheme.brandAccent(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FinzoRadius.sm)),
            ),
            child: Text('Enable', style: FinzoTypography.labelMedium(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await biometricService.saveCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  void _navigateAfterLogin(AuthProvider authProvider) {
    Navigator.of(context).pushReplacementNamed('/home');
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: FinzoTheme.background(context),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: FinzoSpacing.lg, vertical: FinzoSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
                child: IntrinsicHeight(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: FinzoSpacing.xl),
                            // Logo
                            Center(
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      FinzoColors.brandPrimary,
                                      FinzoColors.brandSecondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(FinzoRadius.xl),
                                  boxShadow: [
                                    BoxShadow(
                                      color: FinzoColors.brandPrimary.withOpacity(0.3),
                                      blurRadius: 24,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 44,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: FinzoSpacing.xl),
                            // Heading
                            Text(
                              'Welcome Back',
                              style: FinzoTypography.displaySmall(
                                color: FinzoTheme.textPrimary(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: FinzoSpacing.sm),
                            Text(
                              'Sign in to continue managing your finances',
                              style: FinzoTypography.bodyLarge(
                                color: FinzoTheme.textSecondary(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: FinzoSpacing.xxl),
                            
                            // Email field
                            _buildTextField(
                              context: context,
                              label: 'Email',
                              controller: _emailController,
                              hint: 'your@email.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: FinzoSpacing.lg),
                            
                            // Password field
                            _buildTextField(
                              context: context,
                              label: 'Password',
                              controller: _passwordController,
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword 
                                      ? Icons.visibility_off_outlined 
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: FinzoTheme.textSecondary(context),
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: FinzoSpacing.xl),
                            
                            // Login button
                            Consumer<AuthProvider>(
                              builder: (context, auth, _) {
                                return _buildPrimaryButton(
                                  context: context,
                                  onPressed: auth.status == AuthStatus.loading ? null : _login,
                                  isLoading: auth.status == AuthStatus.loading,
                                  label: 'Sign In',
                                );
                              },
                            ),
                            const SizedBox(height: FinzoSpacing.lg),
                            
                            // Biometric Login Button (shown if available and credentials saved)
                            if (_canUseBiometric && _hasSavedCredentials)
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: FinzoSpacing.lg),
                                    child: OutlinedButton.icon(
                                      onPressed: auth.status == AuthStatus.loading 
                                          ? null 
                                          : _loginWithBiometric,
                                      icon: Icon(
                                        Icons.fingerprint,
                                        color: FinzoTheme.brandAccent(context),
                                        size: 24,
                                      ),
                                      label: Text(
                                        'Use Fingerprint / PIN',
                                        style: FinzoTypography.labelLarge(
                                          color: FinzoTheme.brandAccent(context),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: FinzoSpacing.md),
                                        side: BorderSide(
                                          color: FinzoTheme.brandAccent(context),
                                          width: 2,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(FinzoRadius.md),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            
                            // Divider with text
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: FinzoTheme.divider(context),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: FinzoSpacing.md),
                                  child: Text(
                                    'or',
                                    style: FinzoTypography.bodySmall(
                                      color: FinzoTheme.textSecondary(context),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: FinzoTheme.divider(context),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: FinzoSpacing.lg),
                            
                            // Register link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: FinzoTypography.bodyMedium(
                                    color: FinzoTheme.textSecondary(context),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    );
                                  },
                                  child: Text(
                                    'Sign Up',
                                    style: FinzoTypography.labelLarge(
                                      color: FinzoTheme.brandAccent(context),
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: FinzoSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FinzoTypography.labelMedium(
            color: FinzoTheme.textPrimary(context),
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: FinzoSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onFieldSubmitted: onFieldSubmitted,
          style: FinzoTypography.bodyMedium(color: FinzoTheme.textPrimary(context)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: FinzoTypography.bodyMedium(color: FinzoTheme.textSecondary(context)),
            prefixIcon: Icon(icon, size: 20, color: FinzoTheme.textSecondary(context)),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: FinzoTheme.surfaceVariant(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinzoRadius.md),
              borderSide: BorderSide(color: FinzoTheme.divider(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinzoRadius.md),
              borderSide: BorderSide(color: FinzoTheme.divider(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinzoRadius.md),
              borderSide: BorderSide(color: FinzoTheme.brandAccent(context), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinzoRadius.md),
              borderSide: const BorderSide(color: FinzoColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinzoRadius.md),
              borderSide: const BorderSide(color: FinzoColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: FinzoSpacing.md,
              vertical: FinzoSpacing.md,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required String label,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            FinzoColors.brandPrimary,
            FinzoColors.brandSecondary,
          ],
        ),
        borderRadius: BorderRadius.circular(FinzoRadius.md),
        boxShadow: [
          BoxShadow(
            color: FinzoColors.brandPrimary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: FinzoSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.md),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: FinzoTypography.labelLarge(color: Colors.white),
              ),
      ),
    );
  }
}


