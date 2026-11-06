import 'dart:convert';

import 'package:http/http.dart' as http;

class DigitalyxApiException implements Exception {
  const DigitalyxApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DigitalyxLoginResult {
  const DigitalyxLoginResult({
    required this.userId,
    required this.clientId,
    required this.displayName,
    required this.groupToken,
    required this.rawMessage,
  });

  final String userId;
  final String clientId;
  final String displayName;
  final String groupToken;
  final Map<String, dynamic> rawMessage;
}

/// HTTP integration for the account and login endpoints documented by Digitalyx.
class DigitalyxApi {
  DigitalyxApi({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _createAccountUri = Uri.parse(
    'https://dev.inovyx.net/digitalyx/Inyx/api-public/createAccount/',
  );
  static final Uri _loginUri = Uri.parse(
    'https://dev.inovyx.net/digitalyx/Inyx/api/login',
  );

  final http.Client _client;
  DigitalyxLoginResult? _currentSession;

  /// Last successful login; contains C_ID and GROUPS for documented follow-up APIs.
  DigitalyxLoginResult? get currentSession => _currentSession;

  Future<Map<String, dynamic>> createAccount({
    required String name,
    required String email,
    required String contact,
  }) async {
    final response = await _client
        .post(
          _createAccountUri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'C_TYPE': 'entreprise',
            'C_NAME': name.trim(),
            'C_EMAIL': email.trim(),
            'C_CONTACT': contact.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DigitalyxApiException(_errorMessage(body, response.statusCode));
    }
    if (body['status'] != 'OK' || '${body['code']}' != '1') {
      throw DigitalyxApiException(_errorMessage(body, response.statusCode));
    }
    return (body['message'] as Map?)?.cast<String, dynamic>() ?? body;
  }

  Future<DigitalyxLoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client
        .post(
          _loginUri,
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: {'U_LOGIN': email.trim(), 'U_PWD': password},
        )
        .timeout(const Duration(seconds: 20));
    final body = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DigitalyxApiException(_errorMessage(body, response.statusCode));
    }

    final message = (body['message'] as Map?)?.cast<String, dynamic>() ?? body;
    // The sandbox returns HTTP 200 even for invalid credentials.
    if (message['error'] == 1 || '${message['error']}' == '1') {
      throw DigitalyxApiException(
        message['text']?.toString() ?? 'Adresse ou mot de passe incorrect.',
      );
    }
    if (body['status'] != 'OK' || '${body['code']}' != '1') {
      throw DigitalyxApiException(_errorMessage(body, response.statusCode));
    }

    final firstName = message['U_PRENOM']?.toString().trim() ?? '';
    final lastName = message['U_NOM']?.toString().trim() ?? '';
    final displayName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final result = DigitalyxLoginResult(
      userId: message['U_ID']?.toString() ?? '',
      clientId: message['C_ID']?.toString() ?? '',
      displayName: displayName.isEmpty ? email.trim() : displayName,
      groupToken: message['GROUPS']?.toString() ?? '',
      rawMessage: message,
    );
    _currentSession = result;
    return result;
  }

  Map<String, dynamic> _decodeObject(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Report a short, stable message below instead of leaking HTML/server output.
    }
    throw const DigitalyxApiException(
      'Réponse illisible du serveur Digitalyx.',
    );
  }

  String _errorMessage(Map<String, dynamic> body, int statusCode) {
    final message = body['message'];
    if (message is Map && message['text'] != null) {
      return message['text'].toString();
    }
    if (message is String && message.isNotEmpty) return message;
    return 'Le serveur Digitalyx a répondu avec le code $statusCode.';
  }

  void close() => _client.close();
}
