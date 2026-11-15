import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bisho_ide/core/services/github_repository_service.dart';

void main() {
  group('GitHubRepositoryService', () {
    test('returns the authenticated account without exposing the token', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/user');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(jsonEncode({
          'login': 'bisho-developer',
          'avatar_url': 'https://avatars.githubusercontent.com/u/1',
        }), 200);
      });
      final service = GitHubRepositoryService(client: client);
      final account = await service.verifyToken('test-token');
      expect(account.login, 'bisho-developer');
      expect(account.avatarUrl, contains('githubusercontent.com'));
      client.close();
    });


    test('dispatches the requested workflow on the selected branch', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/repos/demo/app/actions/workflows/build-android.yml/dispatches');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['ref'], 'main');
        expect((body['inputs'] as Map)['flutter_version'], '3.47.2');
        return http.Response('', 204);
      });
      final service = GitHubRepositoryService(client: client);
      await service.dispatchBuild(
        token: 'test-token',
        owner: 'demo',
        repository: 'app',
        workflow: 'build-android.yml',
        branch: 'main',
        flutterVersion: '3.47.2',
      );
      client.close();
    });

    test('rejects an invalid token with a safe Arabic message', () async {
      final client = MockClient((request) async =>
          http.Response(jsonEncode({'message': 'Bad credentials'}), 401));
      final service = GitHubRepositoryService(client: client);
      await expectLater(
        service.verifyToken('invalid-token'),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('رمز GitHub غير صالح'),
        )),
      );
      client.close();
    });
  });
}
