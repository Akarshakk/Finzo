import 'package:flutter/material.dart';
import 'dart:async';
import '../../config/theme.dart';
import '../../models/stock.dart';
import '../../models/paper_portfolio.dart';
import '../../services/markets_service.dart';
import 'trade_screen.dart';
import 'candlestick_chart_screen.dart';
import '../../widgets/trading_view_chart.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;
  final String name;

  const StockDetailScreen({
    super.key,
    required this.symbol,
    required this.name,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  bool _isLoading = true;
  StockDetail? _stockDetail;
  PaperPortfolio? _portfolio;
  String _selectedTimeframe = '1M';
  final List<String> _timeframes = ['1D', '1W', '1M', '3M', '6M', '1Y'];
  bool _isInWatchlist = false;
  bool _watchlistLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkWatchlist();
    // Start silent refresh timer (10 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Timer? _refreshTimer;

  Future<void> _checkWatchlist() async {
    final isWatched = await MarketsService.isInWatchlist(widget.symbol);
    if (mounted) {
      setState(() => _isInWatchlist = isWatched);
    }
  }

  Future<void> _toggleWatchlist() async {
    setState(() => _watchlistLoading = true);
    
    try {
      if (_isInWatchlist) {
        final result = await MarketsService.removeFromWatchlist(widget.symbol);
        print('[Watchlist] Remove result: $result');
        if (result['success'] == true) {
          setState(() => _isInWatchlist = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.symbol} removed from watchlist'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed: ${result['message'] ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        final result = await MarketsService.addToWatchlist(
          symbol: widget.symbol,
          stockName: widget.name,
        );
        print('[Watchlist] Add result: $result');
        if (result['success'] == true) {
          setState(() => _isInWatchlist = true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.symbol} added to watchlist'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed: ${result['message'] ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('[Watchlist] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() => _watchlistLoading = false);
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        MarketsService.getStockDetail(widget.symbol, timeframe: _selectedTimeframe),
        MarketsService.getPortfolio(),
      ]);
      
      if (mounted) {
        setState(() {
          _stockDetail = results[0] as StockDetail?;
          _portfolio = results[1] as PaperPortfolio?;
          if (!silent) _isLoading = false;
        });
      }
    } catch (e) {
      print('[StockDetail] Error loading data: $e');
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Holding? get _currentHolding {
    if (_portfolio == null) return null;
    try {
      // Case-insensitive comparison since backend stores uppercase
      return _portfolio!.holdings.firstWhere(
        (h) => h.symbol.toUpperCase() == widget.symbol.toUpperCase()
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColorsDark.background : AppColors.background;
    final surfaceColor = isDark ? AppColorsDark.surface : AppColors.surface;
    final primaryColor = isDark ? AppColorsDark.primary : AppColors.primary;
    final textPrimary = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final textSecondary = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.symbol,
                      style: AppTextStyles.heading3.copyWith(color: textPrimary),
                    ),
                  ),
                  Text(
                    widget.name,
                    style: AppTextStyles.caption.copyWith(color: textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Candlestick chart button
          IconButton(
            icon: const Icon(
              Icons.candlestick_chart_rounded,
              color: Color(0xFFF59E0B),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CandlestickChartScreen(
                    symbol: widget.symbol,
                    stockName: widget.name,
                  ),
                ),
              );
            },
            tooltip: 'Full Candlestick Chart',
          ),
          // Watchlist button
          _watchlistLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
                    color: _isInWatchlist ? Colors.orange : primaryColor,
                  ),
                  onPressed: _toggleWatchlist,
                  tooltip: _isInWatchlist ? 'Remove from watchlist' : 'Add to watchlist',
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stockDetail == null
              ? Center(
                  child: Text(
                    'Failed to load stock data',
                    style: TextStyle(color: textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price Header
                        _buildPriceHeader(isDark, surfaceColor, textPrimary, textSecondary),
                        
                        // Timeframe Selector
                        _buildTimeframeSelector(isDark, surfaceColor, primaryColor, textSecondary),
                        
                        // Price Trend Chart (Area)
                        _buildPriceTrendSection(isDark, surfaceColor, textPrimary, textSecondary),

                        // Main Candlestick Chart
                        _buildCandlestickChartSection(isDark, surfaceColor, textPrimary, textSecondary),
                        
                        // Dedicated Volume Chart
                        _buildVolumeSection(isDark, surfaceColor, textPrimary, textSecondary),

                        const SizedBox(height: 16),
                        
                        // Stock Stats
                        _buildStockStats(isDark, surfaceColor, textPrimary, textSecondary),
                        
                        // Current Holding (if any)
                        if (_currentHolding != null)
                          _buildHoldingCard(isDark, surfaceColor, textPrimary, textSecondary),
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: _stockDetail != null
          ? _buildTradeButtons(isDark, surfaceColor, primaryColor)
          : null,
    );
  }

  Widget _buildPriceHeader(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Price',
                    style: AppTextStyles.caption.copyWith(color: textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stockDetail!.formattedPrice,
                    style: AppTextStyles.heading1.copyWith(color: textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _stockDetail!.isPositive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      _stockDetail!.isPositive ? Icons.trending_up : Icons.trending_down,
                      color: _stockDetail!.isPositive ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _stockDetail!.formattedChangePercent,
                        style: TextStyle(
                          color: _stockDetail!.isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _stockDetail!.formattedChange,
                        style: TextStyle(
                          color: _stockDetail!.isPositive ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector(bool isDark, Color surfaceColor, Color primaryColor, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _timeframes.map((tf) {
          final isSelected = tf == _selectedTimeframe;
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                setState(() => _selectedTimeframe = tf);
                _loadData();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected ? null : Border.all(color: textSecondary.withOpacity(0.3)),
              ),
              child: Text(
                tf,
                style: TextStyle(
                  color: isSelected 
                      ? (isDark ? AppColorsDark.background : Colors.white)
                      : textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }


  Widget _buildPriceTrendSection(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📉 Price Trend',
            style: AppTextStyles.body1.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TradingViewChart(
                symbol: widget.symbol,
                interval: _selectedTimeframe,
                theme: isDark ? 'dark' : 'light',
                type: 'area',
                height: 160,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandlestickChartSection(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      height: 380,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🕯️ Candlestick Chart',
                style: AppTextStyles.body1.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.fullscreen, color: textSecondary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CandlestickChartScreen(
                        symbol: widget.symbol,
                        stockName: widget.name,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TradingViewChart(
                symbol: widget.symbol,
                interval: _selectedTimeframe,
                theme: isDark ? 'dark' : 'light',
                type: 'candlestick',
                height: 300,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSection(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Volume Analysis',
            style: AppTextStyles.body1.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TradingViewChart(
                symbol: widget.symbol,
                interval: _selectedTimeframe,
                theme: isDark ? 'dark' : 'light',
                type: 'volume',
                height: 120,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStockStats(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 Stock Information',
            style: AppTextStyles.body1.copyWith(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('Day High', '₹${_stockDetail!.dayHigh.toStringAsFixed(2)}', Colors.green, textPrimary, textSecondary)),
              Expanded(child: _buildStatItem('Day Low', '₹${_stockDetail!.dayLow.toStringAsFixed(2)}', Colors.red, textPrimary, textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatItem('Prev Close', '₹${_stockDetail!.previousClose.toStringAsFixed(2)}', Colors.blue, textPrimary, textSecondary)),
              Expanded(child: _buildStatItem('Volume', _formatLargeNumber(_stockDetail!.volume), Colors.purple, textPrimary, textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatItem('Market Cap', _formatLargeNumber(_stockDetail!.marketCap), Colors.orange, textPrimary, textSecondary),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, Color textPrimary, Color textSecondary) {
    if (value == '0' || value == '0.00' || value == '₹0.00' || value.isEmpty || value == 'null') {
      return const SizedBox(width: 0, height: 0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: textSecondary, fontSize: 10)),
                Text(value, style: AppTextStyles.body1.copyWith(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingCard(bool isDark, Color surfaceColor, Color textPrimary, Color textSecondary) {
    final holding = _currentHolding!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: holding.isProfitable ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💼 Your Holdings',
                style: AppTextStyles.body1.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: holding.isProfitable 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  holding.formattedPnlPercent,
                  style: TextStyle(
                    color: holding.isProfitable ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity', style: AppTextStyles.caption.copyWith(color: textSecondary)),
                    Text('${holding.quantity} shares', style: AppTextStyles.body1.copyWith(color: textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avg Price', style: AppTextStyles.caption.copyWith(color: textSecondary)),
                    Text(holding.formattedAvgPrice, style: AppTextStyles.body1.copyWith(color: textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invested', style: AppTextStyles.caption.copyWith(color: textSecondary)),
                    Text(holding.formattedCurrentValue, style: AppTextStyles.body1.copyWith(color: textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('P&L', style: AppTextStyles.caption.copyWith(color: textSecondary)),
                    Text(
                      holding.formattedPnl,
                      style: AppTextStyles.body1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: holding.isProfitable ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTradeButtons(bool isDark, Color surfaceColor, Color primaryColor) {
    final hasHolding = _currentHolding != null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show holdings info if user owns this stock
            if (hasHolding) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'You own ${_currentHolding!.quantity} shares',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Avg: ₹${_currentHolding!.avgPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _navigateToTrade('BUY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline),
                        SizedBox(width: 8),
                        Text('BUY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Tooltip(
                    message: hasHolding ? 'Sell your shares' : 'You don\'t own this stock yet',
                    child: ElevatedButton(
                      onPressed: hasHolding ? () => _navigateToTrade('SELL') : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(hasHolding ? Icons.remove_circle_outline : Icons.block),
                          const SizedBox(width: 8),
                          Text(
                            hasHolding ? 'SELL' : 'NO SHARES',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTrade(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeScreen(
          symbol: widget.symbol,
          name: widget.name,
          currentPrice: _stockDetail!.currentPrice,
          tradeType: type,
          maxSellQuantity: _currentHolding?.quantity,
          availableBalance: _portfolio?.virtualBalance ?? 0,
        ),
      ),
    ).then((_) => _loadData());
  }

  String _formatLargeNumber(dynamic value) {
    if (value == null) return '0';
    
    double numValue;
    if (value is num) {
      numValue = value.toDouble();
    } else {
      numValue = double.tryParse(value.toString()) ?? 0;
    }

    if (numValue >= 10000000) {
      return '${(numValue / 10000000).toStringAsFixed(2)} Cr';
    } else if (numValue >= 100000) {
      return '${(numValue / 100000).toStringAsFixed(2)} L';
    } else if (numValue >= 1000) {
      return '${(numValue / 1000).toStringAsFixed(1)} K';
    }
    return numValue.toStringAsFixed(0);
  }
}

// CandlestickPainter moved to widgets/candlestick_chart.dart
