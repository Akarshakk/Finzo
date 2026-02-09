import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../config/app_theme.dart';
import '../../models/stock.dart';
import '../../models/paper_portfolio.dart';
import '../../services/markets_service.dart';
import '../../widgets/animated_button.dart';
import '../../l10n/app_localizations.dart';
import 'stock_detail_screen.dart';
import 'portfolio_screen.dart';
import 'trade_history_screen.dart';
import 'stock_comparator_screen.dart';
import 'candlestick_chart_screen.dart';

class MarketsLabHomeScreen extends StatefulWidget {
  const MarketsLabHomeScreen({super.key});

  @override
  State<MarketsLabHomeScreen> createState() => _MarketsLabHomeScreenState();
}

class _MarketsLabHomeScreenState extends State<MarketsLabHomeScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  MarketOverview? _marketOverview;
  List<Stock> _stocks = [];
  PaperPortfolio? _portfolio;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Filter state
  String _selectedFilter = 'gainers';
  String _selectedMarketCap = 'large';
  
  // Animations
  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    
    _entranceController.forward();
    
    // Use addPostFrameCallback to ensure widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      // Start silent refresh timer (10 seconds)
      _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _loadData(silent: true);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refreshTimer?.cancel(); // Cancel the periodic timer
    _searchController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Timer? _refreshTimer;

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }
    
    try {
      // Fetch independently to allow partial success
      final overviewFuture = MarketsService.getMarketOverview()
          .catchError((e) { print('Overview error: $e'); return null; });
      
      final stocksFuture = MarketsService.getStocks()
          .catchError((e) { print('Stocks error: $e'); return <Stock>[]; });
          
      final portfolioFuture = MarketsService.getPortfolio()
          .catchError((e) { print('Portfolio error: $e'); return null; });

      final results = await Future.wait([overviewFuture, stocksFuture, portfolioFuture]);
      
      if (mounted) {
        setState(() {
          _marketOverview = results[0] as MarketOverview?;
          _stocks = results[1] as List<Stock>;
          _portfolio = results[2] as PaperPortfolio?;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('LoadData Fatal Error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPortfolio() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Portfolio?'),
        content: const Text(
          'This will clear all your trades and reset your balance to ₹1,00,000. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      final result = await MarketsService.resetPortfolio();
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Portfolio reset successfully'), backgroundColor: Colors.green),
          );
          _loadData(); // Reload all data
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${result['message']}'), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FinzoTheme.isDark(context);
    final bgColor = FinzoTheme.background(context);
    final surfaceColor = FinzoTheme.surface(context);
    final primaryColor = FinzoTheme.brandAccent(context);
    final textPrimary = FinzoTheme.textPrimary(context);
    final textSecondary = FinzoTheme.textSecondary(context);
    
    // Brand copper/gold theme for Markets Lab (matching app theme)
    const marketAccent = FinzoColors.brandSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FinzoTheme.surfaceVariant(context),
              borderRadius: BorderRadius.circular(FinzoRadius.sm),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 16),
          ),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
          tooltip: context.l10n.t('back_to_menu'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [FinzoColors.brandSecondary, FinzoColors.brandSecondary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(FinzoRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: marketAccent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.candlestick_chart, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.l10n.t('markets_lab'),
                      style: FinzoTypography.titleLarge(color: textPrimary).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    context.l10n.t('paper_trading'),
                    style: FinzoTypography.labelSmall().copyWith(
                      color: marketAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          _buildAppBarAction(
            icon: Icons.account_balance_wallet_rounded,
            color: Colors.orange,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const PortfolioScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    );
                  },
                ),
              ).then((_) => _loadData());
            },
            tooltip: 'View Portfolio',
          ),
          const SizedBox(width: 8),
          _buildAppBarAction(
            icon: Icons.refresh_rounded,
            color: primaryColor,
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
          _buildAppBarAction(
            icon: Icons.history_rounded,
            color: textSecondary,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const TradeHistoryScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    );
                  },
                ),
              );
            },
            tooltip: 'Trade History',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textPrimary),
            onSelected: (value) {
              if (value == 'reset') {
                _resetPortfolio();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reset Portfolio', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideUp,
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(FinzoRadius.lg),
                          boxShadow: FinzoShadows.medium,
                        ),
                        child: const CircularProgressIndicator(
                          color: FinzoColors.brandSecondary,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Loading market data...',
                        style: FinzoTypography.bodyMedium(color: textSecondary),
                      ),
                    ],
                  ),
                )
              : _hasError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: FinzoTheme.error(context).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.error_outline_rounded, size: 48, color: FinzoTheme.error(context)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Failed to load market data',
                            style: FinzoTypography.titleMedium(color: textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: FinzoTypography.bodySmall(color: textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [FinzoColors.brandSecondary, FinzoColors.brandSecondary.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(FinzoRadius.md),
                              boxShadow: [
                                BoxShadow(
                                  color: marketAccent.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _loadData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: marketAccent,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            // Virtual Money Banner
                            _buildVirtualMoneyBanner(isDark, primaryColor),
                            
                            // Portfolio Card
                            _buildPortfolioCard(isDark, surfaceColor, textPrimary, textSecondary),
                            
                            // Market Indices
                            if (_marketOverview != null) _buildIndicesSection(isDark, surfaceColor, textPrimary, textSecondary),
                            
                            // Pro Features Bar
                            _buildProFeaturesBar(isDark, surfaceColor, textPrimary, textSecondary),
                            
                            // Search Bar
                            _buildSearchBar(isDark, surfaceColor, textPrimary, textSecondary),
                            
                            // Filter Buttons
                            if (_searchQuery.isEmpty)
                              _buildFilterButtons(isDark, surfaceColor, textPrimary, textSecondary),
                            
                            // Filtered Stocks List
                            _buildFilteredStocksSection(isDark, surfaceColor, textPrimary, textSecondary),
                            
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
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
      child: Tooltip(
        message: tooltip,
        child: AnimatedIconButton(
          onPressed: onPressed,
          icon: icon,
          color: color,
          size: 22,
          enableHaptics: true,
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  Widget _buildVirtualMoneyBanner(bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [FinzoColors.brandSecondary, FinzoColors.brandSecondary.withOpacity(0.85), FinzoColors.brandSecondary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(FinzoRadius.lg),
        boxShadow: [
          BoxShadow(
            color: FinzoColors.brandSecondary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(FinzoRadius.md),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📚 Learning Mode',
                  style: FinzoTypography.titleMedium().copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Practice trading with ₹1 Lakh virtual money. No real money involved!',
                  style: FinzoTypography.bodySmall().copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return AnimatedButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PortfolioScreen()),
      ).then((_) => _loadData()),
      enableHaptics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Portfolio',
                  style: AppTextStyles.body1.copyWith(color: textSecondary),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: textSecondary),
              ],
            ),
            const SizedBox(height: 12),
                _portfolio == null
                  ? Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          CircularProgressIndicator(color: Colors.orange.withOpacity(0.5)),
                          const SizedBox(height: 10),
                          Text('Loading portfolio...', style: AppTextStyles.caption.copyWith(color: textSecondary)),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Net Worth',
                                    style: AppTextStyles.caption.copyWith(color: textSecondary),
                                  ),
                                  Text(
                                    _portfolio!.formattedNetWorth,
                                    style: AppTextStyles.heading2.copyWith(color: textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _portfolio!.isProfitable 
                                    ? Colors.green.withOpacity(0.1) 
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _portfolio!.isProfitable ? Icons.trending_up : Icons.trending_down,
                                    color: _portfolio!.isProfitable ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _portfolio!.formattedPnlPercent,
                                    style: TextStyle(
                                      color: _portfolio!.isProfitable ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildPortfolioStat('Available', _portfolio!.formattedBalance, Colors.blue, textSecondary),
                            const SizedBox(width: 20),
                            _buildPortfolioStat('Invested', _portfolio!.formattedInvested, Colors.orange, textSecondary),
                          ],
                        ),
                      ],
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioStat(String label, String value, Color color, Color textSecondary) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: textSecondary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  value,
                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicesSection(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Market Indices',
            style: AppTextStyles.heading3.copyWith(color: textPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(), // Better for horizontal lists
              itemCount: _marketOverview!.indices.length,
              itemBuilder: (context, index) {
                final idx = _marketOverview!.indices[index];
                return Container(
                  width: 160,
                  margin: EdgeInsets.only(right: index < _marketOverview!.indices.length - 1 ? 12 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: idx.isPositive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        idx.name,
                        style: AppTextStyles.caption.copyWith(color: textSecondary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        idx.formattedValue,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${idx.formattedChange} (${idx.formattedChangePercent})',
                        style: TextStyle(
                          color: idx.isPositive ? Colors.green : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProFeaturesBar(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    const marketAccent = FinzoColors.brandSecondary;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: marketAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pro Tools',
                style: FinzoTypography.titleSmall(color: textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Stock Comparator
              Expanded(
                child: _buildProFeatureCard(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Compare',
                  subtitle: 'Side-by-side',
                  gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const StockComparatorScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
                
              // Watchlist
              Expanded(
                child: _buildProFeatureCard(
                  icon: Icons.bookmark_rounded,
                  label: 'Watchlist',
                  subtitle: 'Your favorites',
                  gradient: const [Color(0xFFEF4444), Color(0xFFF87171)],
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PortfolioScreen(initialTab: 1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProFeatureCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCandlestickStockPicker() {
    final isDark = FinzoTheme.isDark(context);
    final surfaceColor = FinzoTheme.surface(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.candlestick_chart, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 12),
                  Text(
                    'Select Stock for Candlestick Chart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Popular Stocks',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  {'symbol': 'RELIANCE', 'name': 'Reliance Industries'},
                  {'symbol': 'TCS', 'name': 'TCS'},
                  {'symbol': 'HDFCBANK', 'name': 'HDFC Bank'},
                  {'symbol': 'INFY', 'name': 'Infosys'},
                  {'symbol': 'ICICIBANK', 'name': 'ICICI Bank'},
                  {'symbol': 'SBIN', 'name': 'SBI'},
                  {'symbol': 'TATAMOTORS', 'name': 'Tata Motors'},
                  {'symbol': 'ITC', 'name': 'ITC'},
                ].map((stock) => ActionChip(
                  label: Text(stock['symbol']!),
                  backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.grey[200],
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CandlestickChartScreen(
                          symbol: stock['symbol']!,
                          stockName: stock['name']!,
                        ),
                      ),
                    );
                  },
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Timer? _debounce;
  List<Stock> _searchResults = [];
  bool _isSearching = false;


  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchResults = [];
        _isSearching = false;
      } else {
        _isSearching = true;
      }
    });

    if (query.isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 500), () async {
        try {
          final results = await MarketsService.searchStocks(query);
          if (mounted) {
            setState(() {
              _searchResults = results;
              _isSearching = false;
            });
          }
        } catch (e) {
          print('Search error: $e');
          if (mounted) {
            setState(() => _isSearching = false);
          }
        }
      });
    }
  }

  Widget _buildSearchBar(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: textPrimary),
        decoration: InputDecoration(
          hintText: 'Search all Indian stocks (e.g. ZOMATO, MRF)',
          hintStyle: TextStyle(color: textSecondary),
          prefixIcon: Icon(Icons.search, color: textSecondary),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilterButtons(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All Button
            _buildFilterButton(
              label: 'All',
              isSelected: _selectedFilter == 'all',
              color: FinzoColors.brandSecondary,
              onTap: () => setState(() => _selectedFilter = 'all'),
            ),
            const SizedBox(width: 8),
            // Gainers Button
            _buildFilterButton(
              label: '🚀 Gainers',
              isSelected: _selectedFilter == 'gainers',
              color: Colors.green,
              onTap: () => setState(() => _selectedFilter = 'gainers'),
            ),
            const SizedBox(width: 8),
            // Losers Button
            _buildFilterButton(
              label: '📉 Losers',
              isSelected: _selectedFilter == 'losers',
              color: Colors.red,
              onTap: () => setState(() => _selectedFilter = 'losers'),
            ),
            const SizedBox(width: 8),
            // Market Cap Dropdown
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: _selectedFilter == 'marketcap' 
                    ? Colors.orange 
                    : surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFilter == 'marketcap' 
                      ? Colors.orange 
                      : Colors.grey.withOpacity(0.3),
                  width: _selectedFilter == 'marketcap' ? 2 : 1,
                ),
              ),
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  setState(() {
                    _selectedFilter = 'marketcap';
                    _selectedMarketCap = value;
                  });
                },
                offset: const Offset(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => [
                  _buildCapMenuItem('large', '🏢 Large Cap', 'Market Cap > ₹20K Cr'),
                  _buildCapMenuItem('mid', '🏛️ Mid Cap', '₹5K - ₹20K Cr'),
                  _buildCapMenuItem('small', '🏠 Small Cap', 'Market Cap < ₹5K Cr'),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _selectedFilter == 'marketcap'
                            ? '${_selectedMarketCap[0].toUpperCase()}${_selectedMarketCap.substring(1)} Cap'
                            : 'Cap ▼',
                        style: TextStyle(
                          color: _selectedFilter == 'marketcap' 
                              ? Colors.white 
                              : textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildCapMenuItem(String value, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopupMenuItem<String>(
      value: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title, 
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            )
          ),
          Text(
            subtitle, 
            style: TextStyle(
              fontSize: 11, 
              color: isDark ? Colors.grey[400] : Colors.grey[600]
            )
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedButton(
      onPressed: onTap,
      enableHaptics: true,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  List<Stock> get _getFilteredStocks {
    if (_searchQuery.isNotEmpty) {
      return _searchResults;
    }

    switch (_selectedFilter) {
      case 'all':
         // Sort by name or volume? Default alphabetical for now
         return [..._stocks]..sort((a, b) => a.symbol.compareTo(b.symbol));
      case 'gainers':
        // Calculate gainers locally from the full list
        final gainers = _stocks.where((s) => s.changePercent >= 0).toList();
        gainers.sort((a, b) => b.changePercent.compareTo(a.changePercent));
        return gainers;
      case 'losers':
        // Calculate losers locally from the full list
        final losers = _stocks.where((s) => s.changePercent < 0).toList();
        losers.sort((a, b) => a.changePercent.compareTo(b.changePercent)); // Most negative first
        return losers;
      case 'marketcap':
        return _getStocksByMarketCap(_selectedMarketCap);
      default:
        // Default to 'all' or 'gainers' depending on preference. 
        // Let's default to 'all' so they see everything immediately.
        return [..._stocks]..sort((a, b) => a.symbol.compareTo(b.symbol));
    }
  }

  List<Stock> _getStocksByMarketCap(String cap) {
    // Market cap categorization based on typical Indian stock classification
    // Large Cap: > 20,000 Cr (typically Nifty 50 stocks)
    // Mid Cap: 5,000 - 20,000 Cr
    // Small Cap: < 5,000 Cr
    
    // For demonstration, we'll categorize based on stock price as a proxy
    // In real implementation, you'd have actual market cap data
    final Map<String, List<String>> capCategories = {
      'large': ['RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK', 'HINDUNILVR', 'BHARTIARTL', 'SBIN', 'KOTAKBANK', 'LT'],
      'mid': ['TITAN', 'BAJFINANCE', 'ASIANPAINT', 'MARUTI', 'AXISBANK', 'HCLTECH', 'WIPRO', 'SUNPHARMA', 'ITC'],
      'small': ['TATAMOTORS', 'INDUSINDBK', 'HINDALCO', 'ADANIPORTS', 'BPCL', 'NTPC', 'ONGC', 'GRASIM', 'JSWSTEEL', 'COALINDIA'],
    };

    final targetSymbols = capCategories[cap] ?? [];
    
    // Filter from available stocks
    final filteredFromStocks = _stocks.where((s) => 
      targetSymbols.any((t) => s.symbol.toUpperCase().contains(t))
    ).toList();

    // If we have matching stocks, return them
    if (filteredFromStocks.isNotEmpty) {
      return filteredFromStocks;
    }

    // Fallback: divide the available stocks by price tiers
    final sortedByPrice = [..._stocks]..sort((a, b) => b.price.compareTo(a.price));
    final third = (sortedByPrice.length / 3).ceil();
    
    switch (cap) {
      case 'large':
        return sortedByPrice.take(third).toList();
      case 'mid':
        return sortedByPrice.skip(third).take(third).toList();
      case 'small':
        return sortedByPrice.skip(third * 2).toList();
      default:
        return sortedByPrice;
    }
  }

  Widget _buildFilteredStocksSection(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    final stocks = _getFilteredStocks;
    
    String title;
    Color? accentColor;
    
    if (_searchQuery.isNotEmpty) {
      title = '🔍 Search Results';
      accentColor = Colors.orange;
    } else {
      switch (_selectedFilter) {
        case 'all':
          title = '📋 All Stocks';
          accentColor = FinzoColors.brandAccent;
          break;
        case 'gainers':
          title = '🚀 Top Gainers';
          accentColor = Colors.green;
          break;
        case 'losers':
          title = '📉 Top Losers';
          accentColor = Colors.red;
          break;
        case 'marketcap':
          final capEmoji = _selectedMarketCap == 'large' ? '🏢' : (_selectedMarketCap == 'mid' ? '🏛️' : '🏠');
          title = '$capEmoji ${_selectedMarketCap[0].toUpperCase()}${_selectedMarketCap.substring(1)} Cap Stocks';
          accentColor = Colors.orange;
          break;
        default:
          title = '📈 Stocks';
          accentColor = Colors.orange;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTextStyles.heading3.copyWith(color: textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stocks.length} stocks',
                  style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stocks.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      'No stocks found',
                      style: TextStyle(color: textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stocks.length,
              itemBuilder: (context, index) {
                final stock = stocks[index];
                return _buildStockListItem(stock, surfaceColor, textPrimary, textSecondary, accentColor);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStockListItem(Stock stock, Color surfaceColor, Color textPrimary, Color textSecondary, Color? accentColor) {
    final displayColor = accentColor ?? (stock.isPositive ? Colors.green : Colors.red);
    
    return AnimatedButton(
      onPressed: () => _navigateToStockDetail(stock),
      enableHaptics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: displayColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: stock.isPositive 
                    ? Colors.green.withOpacity(0.1) 
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  stock.symbol.substring(0, stock.symbol.length > 2 ? 2 : stock.symbol.length),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: stock.isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.symbol,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    stock.name,
                    style: AppTextStyles.caption.copyWith(color: textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stock.formattedPrice,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stock.isPositive 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stock.formattedChangePercent,
                    style: TextStyle(
                      color: stock.isPositive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: textSecondary),
          ],
        ),
      ),
    );
  }

  void _navigateToStockDetail(Stock stock) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(symbol: stock.symbol, name: stock.name),
      ),
    ).then((_) => _loadData());
  }
}
