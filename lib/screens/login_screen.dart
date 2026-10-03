import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_session.dart';
import '../services/domain_service.dart';
import '../services/runtime_helpers.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _hostController = TextEditingController();
  final _storage = StorageService();
  final _domainService = DomainService.instance;

  String _legacyUser = '';
  List<String> _recentDomains = <String>[];
  bool _loading = false;
  bool _submitting = false;
  bool _domainSyncing = true;
  String? _error;
  String? _domainSyncError;

  bool get _disabled =>
      _hostController.text.trim().isEmpty ||
      _loading ||
      _domainSyncing ||
      !_domainService.verifiedThisSession;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _domainService.loadCachedDomains();
    await _restoreLastValues();
    await _refreshApprovedDomains();
  }

  Future<void> _restoreLastValues() async {
    final host = await _storage.getString(StorageKeys.erpLastUrl);
    final recentDomains = await _storage.getRecentDomains();
    final user = await _storage.getString(StorageKeys.erpLastUser);

    if (!mounted) return;

    setState(() {
      if (host != null && host.isNotEmpty) {
        _hostController.text = host;
      }
      _recentDomains = _domainService.filterKnownDomains(recentDomains);
      if (user != null) _legacyUser = user;
    });
  }

  Future<void> _refreshApprovedDomains() async {
    if (mounted) {
      setState(() {
        _domainSyncing = true;
        _domainSyncError = null;
      });
    }

    try {
      final fresh = await _domainService.refreshDomains();
      final allowed = fresh.map((e) => e.toLowerCase()).toSet();
      final recent = await _storage.retainRecentDomains(allowed);

      if (!mounted) return;
      setState(() {
        _recentDomains = _domainService.filterKnownDomains(recent);
        _domainSyncError = null;
      });
    } on DomainServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _domainSyncError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _domainSyncError =
            'Unable to verify approved domains. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _domainSyncing = false;
        });
      }
    }
  }

  void _selectRecentDomain(String domain) {
    _hostController.text = domain;
    _hostController.selection = TextSelection.collapsed(
      offset: _hostController.text.length,
    );
    setState(() {
      _error = null;
    });
  }

  Future<void> _login() async {
    if (_disabled || _submitting) return;

    _submitting = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final host = normalizeErpHost(_hostController.text);

      if (host.isEmpty) {
        setState(() {
          _error = 'Please enter your ERP host.';
        });
        return;
      }

      if (!_domainService.verifiedThisSession) {
        setState(() {
          _error =
              'Approved domains are not verified yet. Please retry domain sync.';
        });
        return;
      }

      if (!_domainService.isAllowed(host)) {
        setState(() {
          _error = 'This domain is not approved for CARTZ Link.';
        });
        return;
      }

      final baseUrl = host;

      await _storage.setString(
        StorageKeys.erpLastUser,
        normalizeLegacyUser(_legacyUser),
      );
      await _storage.setString(StorageKeys.erpLastUrl, host);
      await _storage.setString(StorageKeys.crmBaseUrl, baseUrl);
      await _storage.setString(StorageKeys.crmLastUrl, baseUrl);

      final session = AppSession(
        username: _legacyUser.isEmpty ? 'guest' : _legacyUser,
        loginUrl: baseUrl,
        lastLoginAt: DateTime.now().toIso8601String(),
        raw: const <String, dynamic>{},
      );

      await _storage.saveAuthSession(session);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _submitting = false;
      });
    }
  }

  Future<void> _openCartzLink() async {
    await launchUrl(
      Uri.parse('https://www.cartzlink.com'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF93C216),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'CARTZ Link - ERP LOGIN',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Container(
                constraints: MediaQuery.sizeOf(context).height >= 600
                    ? BoxConstraints(
                        minHeight: MediaQuery.sizeOf(context).height * .80,
                      )
                    : const BoxConstraints(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 230,
                      height: 100,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: _hostController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        onChanged: (_) => setState(() {
                          _error = null;
                        }),
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'ERP Host',
                          hintText: 'your-domain.com',
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                          suffixIcon: _recentDomains.isEmpty
                              ? null
                              : PopupMenuButton<String>(
                                  tooltip: 'Recent approved domains',
                                  icon: const Icon(
                                    Icons.arrow_drop_down_circle_outlined,
                                    color: Color(0xFF769B12),
                                  ),
                                  onSelected: _selectRecentDomain,
                                  itemBuilder: (context) => _recentDomains
                                      .map(
                                        (domain) => PopupMenuItem<String>(
                                          value: domain,
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.history,
                                                size: 19,
                                                color: Color(0xFF769B12),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  domain,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFFE1E1E1),
                            ),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF93C216),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_domainSyncing) ...[
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF93C216),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Verifying approved domains…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_domainSyncError != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFB26A00),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _domainSyncError!,
                                style: const TextStyle(
                                  color: Color(0xFF7A4A00),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _refreshApprovedDomains,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_domainService.verifiedThisSession) ...[
                      const SizedBox(height: 4),
                      // Text(
                      //   '${_domainService.domains.length} approved domains ready',
                      //   style: const TextStyle(
                      //     fontSize: 11.5,
                      //     color: Color(0xFF6B8F10),
                      //   ),
                      // ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFFFE5E5),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _disabled ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF93C216),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        child: Text(_loading ? 'Connecting…' : 'Login'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          'Powered By ',
                          style: TextStyle(
                            fontSize: 13.6,
                            color: Color(0xFF666666),
                          ),
                        ),
                        InkWell(
                          onTap: _openCartzLink,
                          child: const Text(
                            'CARTZ Link LLC',
                            style: TextStyle(
                              fontSize: 13.6,
                              color: Color(0xFF93C216),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
