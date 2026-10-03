import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/app_session.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _profileBase = 'https://nb.newagedistributions.com';
  final _storage = StorageService();
  final _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _online = true;
  String _activeTab = 'profile';
  String? _profileImage;
  String _lastUrl = '—';
  String? _lastLoginAt;
  String _displayUser = 'Signed in';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final currentConnectivity = await _connectivity.checkConnectivity();
    final activeTab = await _storage.getString(StorageKeys.crmActiveTab);
    final lastUrl = await _storage.getString(StorageKeys.crmLastUrl);
    final lastLogin = await _storage.getString(StorageKeys.authLastLoginAt);
    final storedAuth = await _storage.getString(StorageKeys.authUserSession);

    String display = 'Signed in';
    if (storedAuth != null) {
      try {
        final decoded = jsonDecode(storedAuth);
        if (decoded is Map) {
          display = (decoded['email'] ?? decoded['username'] ?? 'Signed in').toString();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _online = !currentConnectivity.contains(ConnectivityResult.none);
      _activeTab = activeTab ?? 'profile';
      _lastUrl = lastUrl ?? '—';
      _lastLoginAt = lastLogin;
      _displayUser = display;
    });

    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      if (mounted) setState(() => _online = !result.contains(ConnectivityResult.none));
    });

    await _fetchProfileImage();
  }

  Future<void> _fetchProfileImage() async {
    try {
      final response = await http.get(
        Uri.parse('$_profileBase/admin'),
        headers: const {'Cache-Control': 'no-cache'},
      );
      final html = response.body;
      final block = RegExp(
        r'''<div[^>]+id=["']user-left-box["'][\s\S]*?</div>''',
        caseSensitive: false,
      ).firstMatch(html)?.group(0);
      if (block == null) return;
      final src = RegExp(
        r'''<img[^>]+src=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(block)?.group(1);
      if (src == null || src.isEmpty) return;
      var image = src;
      if (!image.startsWith('http')) {
        image = '$_profileBase/${image.replaceFirst(RegExp(r'^/+'), '')}';
      }
      if (mounted) setState(() => _profileImage = image);
    } catch (_) {}
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    return parsed?.toLocal().toString() ?? iso;
  }

  Future<void> _reloadApplication() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(session: widget.session)),
      (_) => false,
    );
  }

  Future<void> _clearSessionCache() async {
    for (final key in <String>[
      StorageKeys.crmLastUrl,
      StorageKeys.crmActiveTab,
      StorageKeys.authLastLoginAt,
      StorageKeys.legacyAuthUser,
    ]) {
      await _storage.remove(key);
    }
    if (!mounted) return;
    setState(() => _lastUrl = '—');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session cache cleared'), duration: Duration(milliseconds: 1200)),
    );
  }

  Future<void> _logout() async {
    await _storage.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _switchTab(String tab) async {
    setState(() => _activeTab = tab);
    await _storage.setString(StorageKeys.crmActiveTab, tab);
    if (tab == 'profile') return;

    final target = tab == 'dashboard'
        ? '$_profileBase/dashboard'
        : '$_profileBase/admin';
    await _storage.setString(StorageKeys.crmLastUrl, target);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(session: widget.session)),
      (_) => false,
    );
  }

  Future<void> _handleBack() async {
    if (_activeTab != 'home') {
      await _storage.setString(StorageKeys.crmActiveTab, 'home');
      final last = await _storage.getString(StorageKeys.crmLastUrl);
      if (last != null && last.isNotEmpty) {
        await _storage.setString(StorageKeys.crmLastUrl, last);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(session: widget.session)),
        (_) => false,
      );
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFDC3545),
          foregroundColor: Colors.white,
          leading: IconButton(onPressed: _handleBack, icon: const Icon(Icons.arrow_back)),
          title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  if (_profileImage != null)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFDC3545), width: 3),
                        image: DecorationImage(image: NetworkImage(_profileImage!), fit: BoxFit.cover),
                      ),
                    )
                  else
                    const Icon(Icons.account_circle, size: 80, color: Color(0xFFDC3545)),
                  const SizedBox(height: 8),
                  Text(_displayUser, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Last Login: ${_formatDate(_lastLoginAt)}', style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
                  const SizedBox(height: 6),
                  Text(
                    _online ? '🟢 Online' : '🔴 Offline',
                    style: TextStyle(fontSize: 14, color: _online ? const Color(0xFF28A745) : const Color(0xFFDC3545)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                leading: const Icon(Icons.link, color: Colors.grey),
                title: const Text('Last ERP URL'),
                subtitle: Text(_lastUrl),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _reloadApplication,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload Application'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _clearSessionCache,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Session Cache'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), foregroundColor: Colors.white),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _activeTab == 'dashboard' ? 1 : (_activeTab == 'profile' ? 2 : 0),
          selectedItemColor: const Color(0xFF16A34A),
          onTap: (index) => _switchTab(index == 0 ? 'home' : (index == 1 ? 'dashboard' : 'profile')),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.apps_outlined), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.account_circle_outlined), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
