import 'dart:convert';

class AppSession {
  const AppSession({
    required this.username,
    required this.loginUrl,
    required this.lastLoginAt,
    required this.raw,
    this.id,
  });

  final String username;
  final String loginUrl;
  final String lastLoginAt;
  final Map<String, dynamic> raw;
  final dynamic id;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'username': username,
        if (id != null) 'id': id,
        'loginURL': loginUrl,
        'lastLoginAt': lastLoginAt,
        'raw': raw,
      };

  String encode() => jsonEncode(toJson());

  factory AppSession.fromJson(Map<String, dynamic> json) => AppSession(
        username: (json['username'] ?? 'guest').toString(),
        id: json['id'],
        loginUrl: (json['loginURL'] ?? '').toString(),
        lastLoginAt: (json['lastLoginAt'] ?? '').toString(),
        raw: json['raw'] is Map
            ? Map<String, dynamic>.from(json['raw'] as Map)
            : <String, dynamic>{},
      );

  factory AppSession.decode(String raw) =>
      AppSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
}
