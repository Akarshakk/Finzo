import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/income_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/debt_reminder_service.dart';
import '../../l10n/app_localizations.dart';
import '../kyc/kyc_screen.dart';
import 'dashboard_tab.dart';
import 'expenses_tab.dart';
import 'add_expense_screen.dart';
import 'profile_tab.dart';
import 'live_finance_tracking_screen.dart';
import '../../widgets/smart_chat_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  // Tracks the order of visited tabs so the system back button returns to the
  // previously viewed tab (e.g. Dashboard -> Profile -> back = Dashboard).
  final List<int> _tabHistory = [0];
  late AnimationController _fabController;
  late AnimationController _navController;
  late Animation<double> _fabScale;
  late Animation<double> _navSlide;
  bool _isChatExpanded = false;

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
    
    // Navigation animation
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
      _loadData();
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _navController.dispose();
    super.dispose();
  }

  /// Switches tabs while recording history for back navigation.
  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _tabHistory.add(index);
      // Keep the history bounded to avoid unbounded growth.
      if (_tabHistory.length > 12) _tabHistory.removeAt(0);
    });
  }

  /// Handles the system back button: step back through visited tabs first,
  /// then fall back to the dashboard, then to the feature menu.
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
      // Already on the dashboard root -> go back to the feature menu.
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _loadData() async {
    final expenseProvider =
        Provider.of<ExpenseProvider>(context, listen: false);
    final incomeProvider = Provider.of<IncomeProvider>(context, listen: false);
    final analyticsProvider =
        Provider.of<AnalyticsProvider>(context, listen: false);
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    await Future.wait([
      expenseProvider.fetchLatestExpenses(),
      incomeProvider.fetchCurrentMonthIncome(),
      analyticsProvider.fetchDashboardData(),
      analyticsProvider.fetchBalanceChartData(),
      debtProvider.fetchDebts(),
    ]);

    if (mounted) {
      DebtReminderService.checkAndShowReminders(
        context,
        debtProvider.fetchDebtsDueToday,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style based on theme
    SystemChrome.setSystemUIOverlayStyle(
      FinzoTheme.isDark(context)
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: FinzoTheme.surface(context),
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: FinzoTheme.surface(context),
            ),
    );

    final tabs = [
      DashboardTab(
        onNavigateToProfile: () => _onTabSelected(3),
      ),
      const ExpensesTab(),
      SmartChatWidget(
        isFullScreen: true,
        onToggle: (expanded) {
          setState(() {
            _isChatExpanded = expanded;
          });
        },
      ),
      const ProfileTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      backgroundColor: FinzoTheme.background(context),
      extendBody: true,
      appBar: _buildPremiumAppBar(context),
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
          child: tabs[_currentIndex],
        ),
      ),
      bottomNavigationBar: _buildPremiumBottomNav(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: (_isChatExpanded || _currentIndex == 2)
          ? null 
          : AnimatedBuilder(
              animation: _fabScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _fabScale.value,
                  child: _buildPremiumFAB(context),
                );
              },
            ),
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(BuildContext context) {
    return AppBar(
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
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: FinzoTheme.textPrimary(context),
            size: 16,
          ),
        ),
        onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
        tooltip: context.l10n.t('back_to_menu'),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FinzoTheme.brandAccent(context),
                  FinzoTheme.brandAccent(context).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(FinzoRadius.sm),
            ),
            child: Text(
              'F',
              style: FinzoTypography.headlineMedium(color: Colors.white).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Finzo',
            style: FinzoTypography.headlineLarge(color: FinzoTheme.textPrimary(context)).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        _buildAppBarAction(
          icon: Icons.pie_chart_rounded,
          color: FinzoTheme.brandAccent(context),
          onPressed: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const LiveFinanceTrackingScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  );
                },
              ),
            );
          },
          tooltip: 'Live Finance Tracking',
        ),
        Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final isVerified = auth.user?.kycStatus == 'VERIFIED';
            return _buildAppBarAction(
              icon: isVerified ? Icons.verified_rounded : Icons.verified_outlined,
              color: isVerified ? FinzoTheme.success(context) : FinzoTheme.warning(context),
              onPressed: () {
                if (!isVerified) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KycScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Your account is verified!'),
                        ],
                      ),
                      backgroundColor: FinzoTheme.success(context),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FinzoRadius.md),
                      ),
                    ),
                  );
                }
              },
              tooltip: isVerified ? 'KYC Verified' : 'Complete KYC',
            );
          },
        ),
        _buildAppBarAction(
          icon: FinzoTheme.isDark(context) ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: FinzoTheme.textSecondary(context),
          onPressed: () {
            HapticFeedback.lightImpact();
            Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
          },
          tooltip: 'Toggle Theme',
        ),
        _buildAppBarAction(
          icon: Icons.groups_rounded,
          color: FinzoTheme.textSecondary(context),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/group-finance');
          },
          tooltip: context.l10n.t('switch_to_group'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarAction({
    required IconData icon,
    required Color color,
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
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBottomNav(BuildContext context) {
    return AnimatedBuilder(
      animation: _navSlide,
      builder: (context, child) {
        final isFabVisible = !_isChatExpanded && _currentIndex != 2;
        
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
                  horizontal: FinzoSpacing.lg,
                  vertical: FinzoSpacing.md,
                ),
                child: Row(
                  children: isFabVisible 
                  ? [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, context.l10n.t('dashboard')),
                            _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, context.l10n.t('expenses')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48), // Explicit Gap for FAB
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(2, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
                            _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, context.l10n.t('profile')),
                          ],
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, context.l10n.t('dashboard')),
                            _buildNavItem(1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, context.l10n.t('expenses')),
                            _buildNavItem(2, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
                            _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, context.l10n.t('profile')),
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
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
          horizontal: isSelected ? FinzoSpacing.md : FinzoSpacing.sm,
          vertical: FinzoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? FinzoTheme.brandAccent(context).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(FinzoRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? FinzoTheme.brandAccent(context)
                  : FinzoTheme.textSecondary(context),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: FinzoTypography.labelMedium().copyWith(
                  color: FinzoTheme.brandAccent(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFAB(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FinzoTheme.brandAccent(context),
            FinzoTheme.brandAccent(context).withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FinzoTheme.brandAccent(context).withOpacity(0.4),
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
            Navigator.of(context)
                .push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const AddExpenseScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      );
                    },
                  ),
                )
                .then((_) => _loadData());
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
    );
  }
}


