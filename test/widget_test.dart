// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_care/models/auth_session.dart';

void main() {
  group('AuthSession parsing', () {
    test('extracts token and role from a standard login payload', () {
      final session = AuthSession.fromLoginPayload({
        'success': true,
        'data': {
          'accessToken': 'abc123',
          'user': {'role': 'admin', 'name': 'Admin User'}
        }
      });

      expect(session.token, 'abc123');
      expect(session.role, 'admin');
    });

    test('supports alternate token and role field names', () {
      final session = AuthSession.fromLoginPayload({
        'token': 'xyz789',
        'user': {'roles': ['USER']}
      });

      expect(session.token, 'xyz789');
      expect(session.role, 'user');
    });
  });
}
