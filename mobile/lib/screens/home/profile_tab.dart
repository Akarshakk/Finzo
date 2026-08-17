import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../l10n/app_localizations.dart';
import '../auth/login_screen.dart';
import '../sms_settings_screen.dart';
import '../bank_statement_screen.dart';
import 'add_income_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isUploadingImage = false;

  Future<void> _pickAndUploadImage() async {
    // Show options dialog
    showModalBottomSheet(
      context: context,
      backgroundColor: FinzoTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FinzoRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: FinzoTheme.brandAccent(context)),
              title: Text('Take a Photo', style: FinzoTypography.bodyMedium()),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: FinzoTheme.brandAccent(context)),
              title: Text('Choose from Gallery', style: FinzoTypography.bodyMedium()),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
            if (Provider.of<AuthProvider>(context, listen: false)
                    .user
                    ?.profilePicture !=
                null)
              ListTile(
                leading: const Icon(Icons.delete, color: FinzoColors.error),
                title: Text('Remove Photo',
                    style: FinzoTypography.bodyMedium().copyWith(color: FinzoColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() => _isUploadingImage = true);

        // Convert image to base64
        final bytes = await image.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        // Update profile with base64 image
        final success = await Provider.of<AuthProvider>(context, listen: false)
            .updateProfile(profilePicture: base64Image);

        setState(() => _isUploadingImage = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile picture updated! 📸'),
              backgroundColor: FinzoColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FinzoRadius.md),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to update profile picture'),
              backgroundColor: FinzoColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FinzoRadius.md),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: FinzoColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.md),
          ),
        ),
      );
    }
  }

  Future<void> _removeProfilePicture() async {
    setState(() => _isUploadingImage = true);

    // Set profilePicture to empty string to remove it
    final success = await Provider.of<AuthProvider>(context, listen: false)
        .updateProfile(profilePicture: '');

    setState(() => _isUploadingImage = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile picture removed'),
          backgroundColor: FinzoColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.md),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinzoTheme.background(context),
      appBar: AppBar(
        title: Text(context.l10n.t('profile'), style: FinzoTypography.headlineMedium()),
        backgroundColor: FinzoTheme.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(FinzoSpacing.md),
            child: Column(
              children: [
                // Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(FinzoSpacing.lg),
                  decoration: BoxDecoration(
                    color: FinzoTheme.surface(context),
                    borderRadius: BorderRadius.circular(FinzoRadius.lg),
                    boxShadow: FinzoShadows.small,
                  ),
                  child: Column(
                    children: [
                      // Profile Picture with edit button
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: _isUploadingImage
                                ? CircleAvatar(
                                    radius: 50,
                                    backgroundColor: FinzoTheme.brandAccent(context),
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : user?.profilePicture != null &&
                                        user!.profilePicture!.isNotEmpty
                                    ? CircleAvatar(
                                        radius: 50,
                                        backgroundImage: MemoryImage(
                                          base64Decode(user.profilePicture!
                                              .split(',')
                                              .last),
                                        ),
                                      )
                                    : CircleAvatar(
                                        radius: 50,
                                        backgroundColor: FinzoTheme.brandAccent(context),
                                        child: Text(
                                          (user?.name.isNotEmpty ?? false)
                                              ? user!.name[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: FinzoTheme.brandAccent(context),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: FinzoSpacing.md),
                      Text(
                        user?.name ?? 'User',
                        style: FinzoTypography.headlineMedium(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: FinzoTypography.bodyMedium().copyWith(
                          color: FinzoTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FinzoSpacing.lg),

                // Settings Section
                Container(
                  decoration: BoxDecoration(
                    color: FinzoTheme.surface(context),
                    borderRadius: BorderRadius.circular(FinzoRadius.lg),
                    boxShadow: FinzoShadows.small,
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.savings_outlined,
                        title: 'Savings Target',
                        subtitle:
                            '${user?.savingsTarget.toStringAsFixed(0) ?? '0'}% of income',
                        onTap: () => _showEditSavingsTargetDialog(context),
                        textColor: FinzoTheme.textPrimary(context),
                        subtitleColor: FinzoTheme.textSecondary(context),
                      ),
                      Divider(height: 1, color: FinzoTheme.divider(context)),
                      _buildListTile(
                        icon: Icons.add_circle_outline,
                        title: 'Add Income',
                        subtitle: 'Add pocket money or income',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AddIncomeScreen()),
                          );
                        },
                        textColor: FinzoTheme.textPrimary(context),
                        subtitleColor: FinzoTheme.textSecondary(context),
                      ),
                      Divider(height: 1, color: FinzoTheme.divider(context)),
                      _buildListTile(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        subtitle: 'Update your name',
                        onTap: () => _showEditNameDialog(context),
                        textColor: FinzoTheme.textPrimary(context),
                        subtitleColor: FinzoTheme.textSecondary(context),
                      ),
                      Divider(height: 1, color: FinzoTheme.divider(context)),
                      _buildListTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'UPI ID',
                        subtitle: (user?.upiId.isNotEmpty ?? false)
                            ? user!.upiId
                            : 'Add your UPI ID for group settlements',
                        onTap: () => _showEditUpiDialog(context),
                        textColor: FinzoTheme.textPrimary(context),
                        subtitleColor: FinzoTheme.textSecondary(context),
                      ),
                      Divider(height: 1, color: FinzoTheme.divider(context)),
                      _buildListTile(
                        icon: Icons.message,
                        title: 'SMS Auto-Tracking',
                        subtitle: 'Track expenses from payment SMS',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SmsSettingsScreen()),
                          );
                        },
                        textColor: FinzoTheme.textPrimary(context),
                        subtitleColor: FinzoTheme.textSecondary(context),
                      ),
                      Divider(height: 1, color: FinzoTheme.divider(context)),
                      _buildListTile(
                        icon: Icons.account_balance_wallet,
                        title: 'Bank Statement OCR',
                        subtitle: 'Upload statement to extract transactions',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const BankStatementScreen()),
                          );
                        },
                        textColor: FinzoTheme.textPrimary(context),
                        subtitleColor: FinzoTheme.textSecondary(context),
                      ),
                      Divider(height: 1, color: FinzoTheme.divider(context)),
                      _buildListTile(
                        icon: Icons.switch_account,
                        title: 'Switch to SmartSplit',
                        subtitle: 'Manage group expenses',
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: FinzoTheme.surface(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(FinzoRadius.lg),
                              ),
                              title: Text('Switch Feature', style: FinzoTypography.titleLarge()),
                              content: Text(
                                'Switch to Group Expenses (SmartSplit)?',
                                style: FinzoTypography.bodyMedium(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: FinzoTypography.labelMedium().copyWith(
                                      color: FinzoTheme.textSecondary(context),
                                    ),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.of(context).pushReplacementNamed('/home');
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: FinzoTheme.brandAccent(context),
                                  ),
                                  child: const Text('Switch'),
                                ),
                              ],
                            ),
                          );
                        },
                        textColor: FinzoTheme.textPrimary(context),
                        subtitleColor: FinzoTheme.textSecondary(context),
                      ),
                      Divider(height: 1, color: FinzoTheme.divider(context)),
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, _) {
                          String themeName = 'System';
                          if (themeProvider.themeMode == ThemeMode.light) {
                            themeName = 'Light';
                          } else if (themeProvider.themeMode ==
                              ThemeMode.dark) {
                            themeName = 'Dark';
                          }

                          return _buildListTile(
                            icon: Icons.brightness_4_outlined,
                            title: 'Theme',
                            subtitle: '$themeName theme',
                            onTap: () =>
                                _showThemePickerDialog(context, themeProvider),
                            textColor: FinzoTheme.textPrimary(context),
                            subtitleColor: FinzoTheme.textSecondary(context),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FinzoSpacing.lg),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: FinzoColors.error,
                      padding: const EdgeInsets.symmetric(vertical: FinzoSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FinzoRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80), // Space for navigation bar
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
    Color? subtitleColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(FinzoSpacing.sm),
        decoration: BoxDecoration(
          color: FinzoTheme.brandAccent(context).withOpacity(0.12),
          borderRadius: BorderRadius.circular(FinzoRadius.md),
        ),
        child: Icon(icon, color: FinzoTheme.brandAccent(context), size: 22),
      ),
      title: Text(title,
          style: FinzoTypography.bodyMedium().copyWith(
            fontWeight: FontWeight.w600,
            color: textColor ?? FinzoTheme.textPrimary(context),
          )),
      subtitle: Text(subtitle,
          style: FinzoTypography.bodySmall().copyWith(
            color: subtitleColor ?? FinzoTheme.textSecondary(context),
          )),
      trailing: Icon(Icons.chevron_right, color: FinzoTheme.textTertiary(context), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: FinzoSpacing.md, vertical: FinzoSpacing.sm),
    );
  }

  void _showEditSavingsTargetDialog(BuildContext context) {
    final controller = TextEditingController(
      text: Provider.of<AuthProvider>(context, listen: false)
          .user
          ?.savingsTarget
          .toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        title: Text('Set Savings Target', style: FinzoTypography.titleLarge()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What percentage of your monthly income do you want to save?',
              style: FinzoTypography.bodySmall().copyWith(
                color: FinzoTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: FinzoSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: FinzoTypography.bodyMedium(),
              decoration: InputDecoration(
                labelText: 'Savings Target',
                labelStyle: FinzoTypography.bodySmall().copyWith(
                  color: FinzoTheme.textSecondary(context),
                ),
                suffixText: '%',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FinzoRadius.md),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FinzoRadius.md),
                  borderSide: BorderSide(color: FinzoTheme.brandAccent(context), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter a value between 0-100',
              style: FinzoTypography.labelSmall().copyWith(
                color: FinzoTheme.textTertiary(context),
              ),
            ),
            const SizedBox(height: FinzoSpacing.sm),
            Container(
              padding: const EdgeInsets.all(FinzoSpacing.sm),
              decoration: BoxDecoration(
                color: FinzoColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(FinzoRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: FinzoColors.info, size: 20),
                  const SizedBox(width: FinzoSpacing.sm),
                  Expanded(
                    child: Text(
                      'Example: If income is ₹5000 and target is 20%, you should spend max ₹4000',
                      style: FinzoTypography.labelSmall().copyWith(
                        color: FinzoColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: FinzoTypography.labelMedium().copyWith(
                color: FinzoTheme.textSecondary(context),
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final target = double.tryParse(controller.text);
              if (target != null && target >= 0 && target <= 100) {
                // Store references before async call
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                final success =
                    await authProvider.updateProfile(savingsTarget: target);

                navigator.pop();

                if (success) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Savings target set to ${target.toStringAsFixed(0)}%! 🎯'),
                      backgroundColor: FinzoColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FinzoRadius.md),
                      ),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Failed to update savings target. Please try again.'),
                      backgroundColor: FinzoColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FinzoRadius.md),
                      ),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Please enter a valid percentage (0-100)'),
                    backgroundColor: FinzoColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FinzoRadius.md),
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: FinzoTheme.brandAccent(context),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditUpiDialog(BuildContext context) {
    final controller = TextEditingController(
      text: Provider.of<AuthProvider>(context, listen: false).user?.upiId ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        title: Text('Your UPI ID', style: FinzoTypography.titleLarge()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group members can pay you here when settling up.',
              style: FinzoTypography.bodySmall().copyWith(
                color: FinzoTheme.textSecondary(context),
              ),
            ),
            const SizedBox(height: FinzoSpacing.md),
            TextField(
              controller: controller,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              style: FinzoTypography.bodyMedium(),
              decoration: InputDecoration(
                labelText: 'UPI ID',
                hintText: 'name@bank',
                labelStyle: FinzoTypography.bodySmall().copyWith(
                  color: FinzoTheme.textSecondary(context),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FinzoRadius.md),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FinzoRadius.md),
                  borderSide: BorderSide(color: FinzoTheme.brandAccent(context), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: FinzoTypography.labelMedium().copyWith(
                color: FinzoTheme.textSecondary(context),
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final value = controller.text.trim();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              final success = await authProvider.updateProfile(upiId: value);
              navigator.pop();

              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(success ? 'UPI ID saved!' : 'Failed to save UPI ID'),
                  backgroundColor: success ? FinzoColors.success : FinzoColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FinzoRadius.md),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: FinzoTheme.brandAccent(context),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(
      text: Provider.of<AuthProvider>(context, listen: false).user?.name,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        title: Text('Edit Name', style: FinzoTypography.titleLarge()),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          style: FinzoTypography.bodyMedium(),
          decoration: InputDecoration(
            labelText: 'Full Name',
            labelStyle: FinzoTypography.bodySmall().copyWith(
              color: FinzoTheme.textSecondary(context),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinzoRadius.md),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FinzoRadius.md),
              borderSide: BorderSide(color: FinzoTheme.brandAccent(context), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: FinzoTypography.labelMedium().copyWith(
                color: FinzoTheme.textSecondary(context),
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await Provider.of<AuthProvider>(context, listen: false)
                    .updateProfile(name: controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: FinzoTheme.brandAccent(context),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        title: Text('Logout', style: FinzoTypography.titleLarge()),
        content: Text('Are you sure you want to logout?', style: FinzoTypography.bodyMedium()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: FinzoTypography.labelMedium().copyWith(
                color: FinzoTheme.textSecondary(context),
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              // Clear all providers
              Provider.of<ExpenseProvider>(context, listen: false).clear();
              Provider.of<IncomeProvider>(context, listen: false).clear();
              Provider.of<AnalyticsProvider>(context, listen: false).clear();
              await Provider.of<AuthProvider>(context, listen: false).logout();

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: FinzoColors.error),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showThemePickerDialog(
      BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        title: Text('Choose Theme', style: FinzoTypography.titleLarge()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Text('Light Theme', style: FinzoTypography.bodyMedium()),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              activeColor: FinzoTheme.brandAccent(context),
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('Dark Theme', style: FinzoTypography.bodyMedium()),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              activeColor: FinzoTheme.brandAccent(context),
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Text('System Default', style: FinzoTypography.bodyMedium()),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              activeColor: FinzoTheme.brandAccent(context),
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}