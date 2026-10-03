import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_session.dart';

class StorageKeys {
  static const authUserSession = 'auth:user_session';
  static const authLastLoginAt = 'auth:lastLoginAt';
  static const erpLastUrl = 'erp:lastUrl';
  static const erpRecentDomains = 'erp:recentDomains';
  static const erpAllowedDomains = 'erp:allowedDomains';
  static const erpAllowedDomainsUpdatedAt = 'erp:allowedDomainsUpdatedAt';
  static const erpLastUser = 'erp:lastUser';
  static const crmLastUrl = 'crm:lastUrl';
  static const crmBaseUrl = 'crm:baseUrl';
  static const crmActiveTab = 'crm:activeTab';
  static const mobileApiToken = 'mobile:apiToken';
  static const legacyUserSession = 'user_session';
  static const legacyAuthUser = 'auth:user';
}

class StorageService {
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getString(String key) async => (await _prefs).getString(key);

  Future<void> setString(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  Future<List<String>> getStringList(String key) async {
    return (await _prefs).getStringList(key) ?? <String>[];
  }

  Future<void> setStringList(String key, List<String> values) async {
    await (await _prefs).setStringList(key, values);
  }

  Future<List<String>> getRecentDomains() async {
    return getStringList(StorageKeys.erpRecentDomains);
  }

  Future<void> addRecentDomain(String domain) async {
    final value = domain.trim().toLowerCase();
    if (value.isEmpty) return;

    final domains = await getRecentDomains();
    domains.removeWhere((item) => item.toLowerCase() == value);
    domains.insert(0, domain.trim());

    if (domains.length > 20) {
      domains.removeRange(20, domains.length);
    }

    await setStringList(StorageKeys.erpRecentDomains, domains);
    await setString(StorageKeys.erpLastUrl, domain.trim());
  }

  Future<List<String>> retainRecentDomains(Set<String> allowedDomains) async {
    final domains = await getRecentDomains();
    final result = <String>[];
    final seen = <String>{};

    for (final item in domains) {
      final normalized = item.trim().toLowerCase();
      if (normalized.isEmpty || !allowedDomains.contains(normalized)) continue;
      if (seen.add(normalized)) result.add(item.trim());
    }

    await setStringList(StorageKeys.erpRecentDomains, result);
    return result;
  }

  Future<void> remove(String key) async {
    await (await _prefs).remove(key);
  }

  Future<AppSession?> getAuthSession() async {
    final raw = await getString(StorageKeys.authUserSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppSession.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAuthSession(AppSession session) async {
    await setString(StorageKeys.authUserSession, session.encode());
  }

  Future<void> logout() async {
    // Keep recent/approved domains cached. Only the local app session is reset.
    await remove(StorageKeys.authUserSession);
  }
}
