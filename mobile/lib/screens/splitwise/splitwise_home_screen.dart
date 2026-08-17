import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/splitwise_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../l10n/app_localizations.dart';
import 'splitwise_groups_tab.dart';
import 'splitwise_friends_tab.dart';
import 'splitwise_activity_tab.dart';
import 'splitwise_settings_tab.dart';

class SplitwiseHomeScreen extends StatefulWidget {
  const SplitwiseHomeScreen({super.key});

  @override
  State<SplitwiseHomeScreen> createState() => _SplitwiseHomeScreenState();
}

class _SplitwiseHomeScreenState extends State<SplitwiseHomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  // Visited-tab history so the system back button returns to the previous tab.
  final List<int> _tabHistory = [0];

  late AnimationController _fabController;
  late AnimationController _navController;
  late Animation<double> _fabScale;
  late Animation<double> _navSlide;

  final List<Widget> _tabs = [
    const SplitwiseGroupsTab(),
    const SplitwisFriendsTab(),
    const SplitwiseActivityTab(),
    const SplitwiseSettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    
    // FAB animation
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
    );
    
    // Nav animation
    _navController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _navSlide = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(parent: _navController, curve: Curves.easeOutCubic),
    );
    
    // Start animations
    Future.delayed(const Duration(milliseconds: 300), () {
      _fabController.forward();
      _navController.forward();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final splitwiseProvider =
          Provider.of<SplitWiseProvider>(context, listen: false);
      splitwiseProvider.fetchGroups();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _navController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _tabHistory.add(index);
      if (_tabHistory.length > 12) _tabHistory.removeAt(0);
    });
  }

  void _handleBack() {
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = _tabHistory.last;
      });
    } else if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _tabHistory
          ..clear()
          ..add(0);
      });
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use consistent brand accent color across the app
    final splitAccent = FinzoTheme.brandAccent(context);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      backgroundColor: FinzoTheme.background(context),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: FinzoTheme.background(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FinzoTheme.surfaceVariant(context),
              borderRadius: BorderRadius.circular(FinzoRadius.sm),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: FinzoTheme.textPrimary(context), size: 16),
          ),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
          tooltip: context.l10n.t('back_to_menu'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FinzoColors.brandPrimary, FinzoColors.brandSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(FinzoRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: FinzoColors.brandSecondary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.t('smart_split'),
              style: FinzoTypography.headlineLarge(
                color: FinzoTheme.textPrimary(context),
              ).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          _buildAppBarAction(
            icon: FinzoTheme.isDark(context) ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
            tooltip: context.l10n.t('toggle_theme'),
          ),
          _buildAppBarAction(
            icon: Icons.person_add_rounded,
            onPressed: _showJoinGroupDialog,
            tooltip: context.l10n.t('join_group'),
          ),
          _buildAppBarAction(
            icon: Icons.account_balance_wallet_rounded,
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/personal-finance');
            },
            tooltip: 'Switch to Personal Finance',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _tabs[_currentIndex],
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _navSlide,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _navSlide.value),
            child: Container(
              decoration: BoxDecoration(
                color: FinzoTheme.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FinzoSpacing.md,
                    vertical: FinzoSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(0, Icons.groups_outlined, Icons.groups_rounded, context.l10n.t('groups'), splitAccent),
                            _buildNavItem(1, Icons.person_outline_rounded, Icons.person_rounded, context.l10n.t('friends'), splitAccent),
                          ],
                        ),
                      ),
                      const SizedBox(width: 50), // Explicit Gap for FAB
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(2, Icons.history_outlined, Icons.history_rounded, context.l10n.t('activity'), splitAccent),
                            _buildNavItem(3, Icons.settings_outlined, Icons.settings_rounded, context.l10n.t('settings'), splitAccent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScale.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FinzoColors.brandPrimary, FinzoColors.brandSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: FinzoColors.brandSecondary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (_currentIndex == 0) {
                      _showCreateGroupDialog();
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(FinzoRadius.sm),
          child: Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: FinzoTheme.textSecondary(context), size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, Color accentColor) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _onTabSelected(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? FinzoSpacing.sm : FinzoSpacing.xs,
          vertical: FinzoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? accentColor
                  : FinzoTheme.textSecondary(context),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: FinzoTypography.labelSmall().copyWith(
                color: isSelected
                    ? accentColor
                    : FinzoTheme.textSecondary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FinzoTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        title: Text(
          'Create Group',
          style: FinzoTypography.headlineSmall(),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: FinzoTypography.bodyMedium(),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: FinzoTypography.bodySmall().copyWith(
                  color: FinzoTheme.textSecondary(context),
                ),
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
              ),
            ),
            const SizedBox(height: FinzoSpacing.md),
            TextField(
              controller: descriptionController,
              style: FinzoTypography.bodyMedium(),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: FinzoTypography.bodySmall().copyWith(
                  color: FinzoTheme.textSecondary(context),
                ),
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
              ),
              maxLines: 2,
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
              if (nameController.text.isNotEmpty) {
                final provider =
                    Provider.of<SplitWiseProvider>(context, listen: false);
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);

                final success = await provider.createGroup(
                  name: nameController.text,
                  description: descriptionController.text,
                  memberEmails: [],
                  userId: authProvider.user?.id ?? 'user_123',
                  userName: authProvider.user?.name ?? 'User',
                );

                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Group created successfully!'),
                      backgroundColor: FinzoColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FinzoRadius.md),
                      ),
                    ),
                  );
                } else if (mounted && provider.errorMessage != null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${provider.errorMessage}'),
                      backgroundColor: FinzoColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FinzoRadius.md),
                      ),
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: FinzoTheme.brandAccent(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FinzoRadius.md),
              ),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    final inviteCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: FinzoTheme.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinzoRadius.lg),
          ),
          title: Text(
            'Join Group',
            style: FinzoTypography.headlineSmall(),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the 6-character invite code from the group creator',
                  style: FinzoTypography.bodySmall().copyWith(
                    color: FinzoTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: FinzoSpacing.md),
                TextField(
                  controller: inviteCodeController,
                  style: FinzoTypography.bodyMedium(),
                  decoration: InputDecoration(
                    labelText: 'Invite Code',
                    labelStyle: FinzoTypography.bodySmall().copyWith(
                      color: FinzoTheme.textSecondary(context),
                    ),
                    hintText: 'e.g., ABC123',
                    hintStyle: FinzoTypography.bodySmall().copyWith(
                      color: FinzoTheme.textTertiary(context),
                    ),
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
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                ),
              ],
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
                if (inviteCodeController.text.length == 6) {
                  final provider =
                      Provider.of<SplitWiseProvider>(context, listen: false);
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);

                  final success = await provider.joinGroupByCode(
                    inviteCode: inviteCodeController.text.toUpperCase(),
                    userId: authProvider.user?.id ?? 'user_123',
                    userName: authProvider.user?.name ?? 'User',
                    userEmail: authProvider.user?.email ?? 'user@example.com',
                  );

                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Joined group successfully!'),
                        backgroundColor: FinzoColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FinzoRadius.md),
                        ),
                      ),
                    );
                  } else if (mounted && provider.errorMessage != null) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${provider.errorMessage}'),
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
                      content: const Text('Code must be exactly 6 characters'),
                      backgroundColor: FinzoColors.warning,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FinzoRadius.md),
                ),
              ),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }
}