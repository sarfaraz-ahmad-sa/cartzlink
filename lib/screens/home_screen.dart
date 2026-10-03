import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/app_session.dart';
import '../services/domain_service.dart';
import '../services/runtime_helpers.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  final _domainService = DomainService.instance;
  late final WebViewController _webView;

  String _baseUrl = '';
  String _baseOrigin = '';
  String _initialUrl = '';
  bool _loading = true;
  bool _domainSyncing = true;
  bool _readyToBrowse = false;
  int _progress = 0;
  String? _domainError;
  List<String> _recentDomains = <String>[];

  @override
  void initState() {
    super.initState();

    _webView = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted || !_readyToBrowse) return;
            setState(() {
              _progress = progress.clamp(0, 100).toInt();
              _loading = progress < 100;
            });
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _progress = 0;
            });
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() {
                _loading = false;
                _progress = 100;
              });
            }
            await _captureSameOriginUrl(url, saveAsLastDomain: true);
          },
          onNavigationRequest: (request) async {
            await _captureSameOriginUrl(request.url);
            return NavigationDecision.navigate;
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _progress = 0;
            });
          },
        ),
      );

    _initialize();
  }

  Future<void> _initialize() async {
    await _enableWebAuthentication();
    await _domainService.loadCachedDomains();
    await _loadRecentDomains();
    await _refreshDomainWhitelist(bootstrapAfterSuccess: true);
  }

  Future<void> _refreshDomainWhitelist({bool bootstrapAfterSuccess = false}) async {
    if (mounted) {
      setState(() {
        _domainSyncing = true;
        _domainError = null;
      });
    }

    try {
      final fresh = await _domainService.refreshDomains();
      final allowed = fresh.map((e) => e.toLowerCase()).toSet();
      await _storage.retainRecentDomains(allowed);
      await _loadRecentDomains();

      if (bootstrapAfterSuccess || !_readyToBrowse) {
        await _bootstrap();
      }
    } on DomainServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _domainError = e.message;
        _readyToBrowse = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _domainError =
            'Unable to verify approved domains. Check your internet connection and retry.';
        _readyToBrowse = false;
        _loading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _domainSyncing = false;
        });
      }
    }
  }

  Future<void> _loadRecentDomains() async {
    final domains = await _storage.getRecentDomains();
    if (!mounted) return;
    setState(() {
      _recentDomains = _domainService.filterKnownDomains(domains);
    });
  }

  Future<void> _enableWebAuthentication() async {
    final platform = _webView.platform;
    if (platform is! AndroidWebViewController) return;

    try {
      final supported = await platform.isWebViewFeatureSupported(
        WebViewFeatureType.webAuthentication,
      );

      if (!supported) return;

      await platform.setWebAuthenticationSupport(
        WebAuthenticationSupport.forApp,
      );
    } catch (_) {
      // Never block the ERP because of WebAuthn support.
    }
  }

  Future<void> _bootstrap() async {
    final storedBase = await _storage.getString(StorageKeys.crmBaseUrl);
    final storedLast = await _storage.getString(StorageKeys.crmLastUrl);

    final candidate = widget.session.loginUrl.isNotEmpty
        ? widget.session.loginUrl
        : (storedBase?.isNotEmpty == true
            ? storedBase!
            : (storedLast?.isNotEmpty == true ? storedLast! : ''));

    final host = normalizeErpHost(candidate);

    if (host.isEmpty) {
      if (!mounted) return;
      setState(() {
        _domainError = 'No ERP domain is selected.';
        _readyToBrowse = false;
      });
      return;
    }

    if (!_domainService.isAllowed(host)) {
      if (!mounted) return;
      setState(() {
        _domainError = 'This domain is not approved for CARTZ Link.';
        _readyToBrowse = false;
      });
      return;
    }

    final resolvedBase = originOrDefault(host);
    if (resolvedBase.isEmpty) {
      if (!mounted) return;
      setState(() {
        _domainError = 'The selected ERP domain is invalid.';
        _readyToBrowse = false;
      });
      return;
    }

    _baseUrl = resolvedBase;
    _baseOrigin = resolvedBase;
    _initialUrl = resolvedBase;

    await _storage.setString(StorageKeys.crmBaseUrl, _baseUrl);

    final lastLogin = await _storage.getString(StorageKeys.authLastLoginAt);
    if (lastLogin == null || lastLogin.isEmpty) {
      await _storage.setString(
        StorageKeys.authLastLoginAt,
        DateTime.now().toIso8601String(),
      );
    }

    if (!mounted) return;
    setState(() {
      _domainError = null;
      _readyToBrowse = true;
    });

    await _setFrame(_initialUrl);
  }

  Future<void> _setFrame(String requested) async {
    if (_baseUrl.isEmpty || !_domainService.isAllowed(_baseUrl)) return;

    String target;
    try {
      target = Uri.parse(_baseUrl).resolve(requested).toString();
    } catch (_) {
      target = _baseUrl;
    }

    if (!sameOrigin(target, _baseOrigin)) target = _baseUrl;

    await _storage.setString(StorageKeys.crmBaseUrl, _baseUrl);
    await _storage.setString(StorageKeys.crmLastUrl, target);

    if (mounted) {
      setState(() {
        _loading = true;
        _progress = 0;
      });
    }

    await _webView.loadRequest(Uri.parse(target));
  }

  Future<void> _captureSameOriginUrl(
    String url, {
    bool saveAsLastDomain = false,
  }) async {
    if (_baseOrigin.isEmpty || !sameOrigin(url, _baseOrigin)) return;

    await _storage.setString(StorageKeys.crmLastUrl, url);

    if (saveAsLastDomain) {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.host.isNotEmpty &&
          _domainService.isAllowed(uri.host)) {
        await _storage.addRecentDomain(uri.host.toLowerCase());
        await _loadRecentDomains();
      }
    }
  }

  String get _currentDomain {
    if (_baseUrl.isEmpty) return '';
    final uri = Uri.tryParse(ensureHttps(_baseUrl));
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return normalizeErpHost(_baseUrl);
  }

  Future<void> _switchDomain(String domain) async {
    if (!_domainService.verifiedThisSession) {
      _showMessage('Approved domains are not verified. Please retry.');
      return;
    }

    final host = normalizeErpHost(domain);
    if (host.isEmpty || host == _currentDomain) return;

    if (!_domainService.isAllowed(host)) {
      _showMessage('This domain is no longer approved for CARTZ Link.');
      return;
    }

    final nextBase = originOrDefault(host);
    if (nextBase.isEmpty) {
      _showMessage('Invalid ERP domain.');
      return;
    }

    if (mounted) {
      setState(() {
        _baseUrl = nextBase;
        _baseOrigin = nextBase;
        _initialUrl = nextBase;
        _readyToBrowse = true;
        _domainError = null;
        _loading = true;
        _progress = 0;
      });
    }

    await _storage.setString(StorageKeys.erpLastUrl, host);
    await _storage.setString(StorageKeys.crmBaseUrl, nextBase);
    await _storage.setString(StorageKeys.crmLastUrl, nextBase);

    await _webView.loadRequest(Uri.parse(nextBase));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<PopupMenuEntry<String>> _domainMenuItems() {
    if (_recentDomains.isEmpty) {
      return const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Text('No approved recent domains'),
        ),
      ];
    }

    return _recentDomains.map((domain) {
      final isCurrent = domain.toLowerCase() == _currentDomain.toLowerCase();
      return PopupMenuItem<String>(
        value: domain,
        child: Row(
          children: [
            Icon(
              isCurrent ? Icons.check_circle : Icons.language,
              size: 19,
              color: const Color(0xFF769B12),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                domain,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _reload() async {
    if (!_readyToBrowse) {
      await _refreshDomainWhitelist(bootstrapAfterSuccess: true);
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _progress = 0;
      });
    }
    await _webView.reload();
  }

  Future<void> _logout() async {
    await _storage.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _nativeBack() async {
    if (_readyToBrowse && await _webView.canGoBack()) {
      await _webView.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  Widget _buildDomainError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.domain_disabled_outlined,
                size: 48,
                color: Color(0xFF93C216),
              ),
              const SizedBox(height: 14),
              Text(
                _domainError ?? 'Unable to verify approved domains.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _domainSyncing
                    ? null
                    : () => _refreshDomainWhitelist(
                          bootstrapAfterSuccess: true,
                        ),
                icon: const Icon(Icons.refresh),
                label: Text(
                  _domainSyncing ? 'Checking…' : 'Retry',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF93C216),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _nativeBack();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF93C216),
          foregroundColor: Colors.white,
          title: PopupMenuButton<String>(
            tooltip: 'Switch domain',
            onSelected: _switchDomain,
            itemBuilder: (_) => _domainMenuItems(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CARTZ Link - ERP',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language,
                      size: 13,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _currentDomain.isEmpty ? 'Select domain' : _currentDomain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 17,
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: _logout,
                tooltip: 'Logout',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.logout),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_domainSyncing || (_loading && _readyToBrowse))
              LinearProgressIndicator(
                value: _readyToBrowse && _progress > 0
                    ? _progress / 100
                    : null,
                minHeight: 3,
                backgroundColor: const Color(0xFFE8E8E8),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF93C216),
                ),
              ),
            Expanded(
              child: !_readyToBrowse
                  ? _buildDomainError()
                  : WebViewWidget(controller: _webView),
            ),
          ],
        ),
      ),
    );
  }
}
