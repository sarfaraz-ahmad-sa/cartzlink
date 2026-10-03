import 'dart:convert';

import 'package:http/http.dart' as http;

import 'runtime_helpers.dart';
import 'storage_service.dart';

class DomainService {
  DomainService._();

  static final DomainService instance = DomainService._();

  static const String apiUrl = String.fromEnvironment(
    'CARTZ_DOMAIN_API_URL',
    defaultValue:
        'https://crm.cartzlink.com/admin/?r=api/fetchMobileDomainList',
  );

  // Must match the $secret string in actionfetchMobileDomainList() on the CRM side.
  static const String _authSecret = 'cartzlink-mobile-2026';

  final StorageService _storage = StorageService();
  final Set<String> _allowedDomains = <String>{};

  bool _verifiedThisSession = false;
  bool _refreshing = false;
  DateTime? _lastRefreshAt;

  bool get verifiedThisSession => _verifiedThisSession;
  bool get refreshing => _refreshing;
  DateTime? get lastRefreshAt => _lastRefreshAt;

  List<String> get domains {
    final values = _allowedDomains.toList()..sort();
    return List<String>.unmodifiable(values);
  }

  Future<List<String>> loadCachedDomains() async {
    final cached = await _storage.getStringList(StorageKeys.erpAllowedDomains);

    _allowedDomains
      ..clear()
      ..addAll(
        cached
            .map(normalizeDomain)
            .where((domain) => domain.isNotEmpty),
      );

    _verifiedThisSession = false;

    return domains;
  }

  String _buildAuthToken() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    return base64Encode(utf8.encode('$_authSecret|$timestamp'));
  }

  Future<List<String>> refreshDomains() async {
    if (_refreshing) return domains;
    _refreshing = true;

    try {
      final token = _buildAuthToken();

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Accept': 'application/json'},
            body: {'token': token},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        _verifiedThisSession = false;
        throw const DomainServiceException(
          'CARTZ Link authentication failed while loading approved domains.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _verifiedThisSession = false;
        throw DomainServiceException(
          'Domain service returned HTTP ${response.statusCode}.',
        );
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        _verifiedThisSession = false;
        throw const DomainServiceException(
          'Invalid response received from domain service.',
        );
      }

      if (decoded is! Map) {
        _verifiedThisSession = false;
        throw const DomainServiceException(
          'Invalid response received from domain service.',
        );
      }

      final ok = decoded['ok'];
      final success = ok == 1 || ok == true || ok?.toString() == '1';

      if (!success) {
        _verifiedThisSession = false;
        final message = decoded['msg']?.toString().trim();
        throw DomainServiceException(
          message?.isNotEmpty == true
              ? message!
              : 'Unable to load approved domains.',
        );
      }

      final data = decoded['data'];
      if (data is! List) {
        _verifiedThisSession = false;
        throw const DomainServiceException(
          'Domain service returned an invalid domain list.',
        );
      }

      final fresh = <String>{};
      for (final item in data) {
        if (item is Map) {
          final domain = normalizeDomain(item['domain']?.toString() ?? '');
          if (domain.isNotEmpty) fresh.add(domain);
        } else if (item is String) {
          final domain = normalizeDomain(item);
          if (domain.isNotEmpty) fresh.add(domain);
        }
      }

      if (fresh.isEmpty) {
        _verifiedThisSession = false;
        throw const DomainServiceException(
          'No approved domains were returned by the server.',
        );
      }

      _allowedDomains
        ..clear()
        ..addAll(fresh);

      _verifiedThisSession = true;
      _lastRefreshAt = DateTime.now();

      await _storage.setStringList(
        StorageKeys.erpAllowedDomains,
        domains,
      );
      await _storage.setString(
        StorageKeys.erpAllowedDomainsUpdatedAt,
        _lastRefreshAt!.toUtc().toIso8601String(),
      );

      return domains;
    } on DomainServiceException {
      rethrow;
    } catch (_) {
      _verifiedThisSession = false;
      throw const DomainServiceException(
        'Unable to verify approved domains. Check your internet connection and retry.',
      );
    } finally {
      _refreshing = false;
    }
  }

  bool isAllowed(String value) {
    if (!_verifiedThisSession) return false;
    final domain = normalizeDomain(value);
    return domain.isNotEmpty && _allowedDomains.contains(domain);
  }

  bool isKnownFromCache(String value) {
    final domain = normalizeDomain(value);
    return domain.isNotEmpty && _allowedDomains.contains(domain);
  }

  List<String> filterKnownDomains(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};

    for (final value in values) {
      final domain = normalizeDomain(value);
      if (domain.isEmpty || !_allowedDomains.contains(domain)) continue;
      if (seen.add(domain)) result.add(domain);
    }

    return result;
  }

  static String normalizeDomain(String input) {
    return normalizeErpHost(input).trim().toLowerCase();
  }
}

class DomainServiceException implements Exception {
  const DomainServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}