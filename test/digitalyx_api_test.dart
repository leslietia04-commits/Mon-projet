import 'dart:convert';

import 'package:digitalyx_exhibitor/data/digitalyx_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('createAccount sends the expected account fields as JSON', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'status': 'OK',
          'code': '1',
          'message': {'C_ID': '42'},
        }),
        201,
      );
    });
    final api = DigitalyxApi(client: client);
    addTearDown(api.close);

    final result = await api.createAccount(
      name: '  Ada Lovelace  ',
      email: '  ada@example.com ',
      contact: ' +33123456789 ',
    );

    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.method, 'POST');
    expect(
      capturedRequest!.url.toString(),
      'https://dev.inovyx.net/digitalyx/Inyx/api-public/createAccount/',
    );
    expect(capturedRequest!.headers['content-type'], 'application/json');
    expect(jsonDecode(capturedRequest!.body), {
      'C_TYPE': 'entreprise',
      'C_NAME': 'Ada Lovelace',
      'C_EMAIL': 'ada@example.com',
      'C_CONTACT': '+33123456789',
    });
    expect(result, {'C_ID': '42'});
  });

  test('createAccount reports a rejected account response', () async {
    final api = DigitalyxApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status': 'ERROR',
            'code': '0',
            'message': {'text': 'Adresse e-mail déjà utilisée'},
          }),
          200,
        ),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.createAccount(
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        contact: '+33123456789',
      ),
      throwsA(
        isA<DigitalyxApiException>().having(
          (error) => error.message,
          'message',
          'Adresse e-mail déjà utilisée',
        ),
      ),
    );
  });
}
