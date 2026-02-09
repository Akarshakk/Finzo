import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/constants.dart';
import 'chart_platform_utils.dart';

class TradingViewChart extends StatefulWidget {
  final String symbol;
  final String interval;
  final String theme; // 'dark' or 'light'
  final String type; // 'candlestick', 'area', 'volume'
  final List<String>? comparisonSymbols; // For multi-stock comparison
  final double height;

  const TradingViewChart({
    super.key,
    required this.symbol,
    this.interval = '1D',
    this.theme = 'dark',
    this.type = 'candlestick',
    this.comparisonSymbols,
    this.height = 360,
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  late final WebViewController? _controller;
  bool _isLoading = true;
  String? _webIframeId;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _initWeb();
    } else {
      _initMobile();
    }
  }

  void _initWeb() {
    _webIframeId = 'tradingview_iframe_${DateTime.now().millisecondsSinceEpoch}';
    
    final baseUrl = "${ApiConstants.baseUrl}/markets";
    final symbolsText = widget.comparisonSymbols?.join(',') ?? '';
    
    ChartPlatformUtils.registerView(
      _webIframeId!, 
      widget.symbol, 
      widget.interval, 
      widget.theme, 
      widget.type, 
      baseUrl,
      symbols: symbolsText,
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isLoading = false);
    });
    
    _controller = null; // No controller for web
  }

  void _initMobile() {
    _controller = WebViewController();
    _controller!.setJavaScriptMode(JavaScriptMode.unrestricted);
    _controller!.setBackgroundColor(const Color(0x00000000));
    // NavigationDelegate will be set in _loadMobileChart
    _loadMobileChart();
  }

  void _onPageFinished(String url) {
    if (mounted) {
      setState(() => _isLoading = false);
      _injectConfig();
    }
  }

  Future<void> _injectConfig() async {
    if (_controller == null || kIsWeb) return;
    
    try {
      final baseUrl = "${ApiConstants.baseUrl}/markets";
      final symbolsText = widget.comparisonSymbols?.join(',') ?? '';
      
      final js = "if (window.updateConfig) { "
          "window.updateConfig("
          "'${widget.symbol}', "
          "'${widget.interval}', "
          "'${widget.theme}', "
          "'$baseUrl', "
          "'$symbolsText', "
          "'${widget.type}'"
          "); "
          "}";
      await _controller!.runJavaScript(js);
    } catch (e) {
      debugPrint('Error injecting chart config: $e');
    }
  }

  Future<void> _loadMobileChart() async {
    try {
      if (_controller == null || kIsWeb) return;

      _controller!.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller!.setBackgroundColor(const Color(0x00000000));
      _controller!.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onPageFinished,
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );

      // IMPORTANT: loadFlutterAsset does NOT support query parameters.
      // We load the plain asset and then inject config via JS.
      await _controller!.loadFlutterAsset('assets/chart.html');
    } catch (e) {
      debugPrint('Error loading chart: $e');
    }
  }

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol || 
        oldWidget.interval != widget.interval || 
        oldWidget.theme != widget.theme ||
        oldWidget.type != widget.type ||
        !listEquals(oldWidget.comparisonSymbols, widget.comparisonSymbols)) {
      if (kIsWeb) {
        _initWeb();
      } else {
        _injectConfig();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.theme == 'dark' ? Colors.black : Colors.white,
      ),
      child: Stack(
        children: [
          if (kIsWeb && _webIframeId != null)
             HtmlElementView(viewType: _webIframeId!)
          else if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            const Center(child: Text('Chart not initialized')),
            
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
