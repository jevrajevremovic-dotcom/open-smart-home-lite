import 'package:flutter_test/flutter_test.dart';
import 'package:open_smart_home_lite/core/logging/app_logger.dart';
import 'package:open_smart_home_lite/core/security/redactor.dart';

const jwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhYmMxMjMifQ.c2lnbmF0dXJlX3ZhbHVl';

void main() {
  group('Redactor', () {
    test('masks bearer tokens', () {
      final out = Redactor.redact('Authorization: Bearer $jwt');
      expect(out, isNot(contains(jwt)));
      expect(out, contains(Redactor.mask));
    });

    test('masks secret JSON fields', () {
      final out = Redactor.redact(
        '{"type":"auth","access_token":"abc.def-123"}',
      );
      expect(out, '{"type":"auth","access_token":"${Redactor.mask}"}');
      expect(
        Redactor.redact('{"password": "hunter2"}'),
        isNot(contains('hunter2')),
      );
    });

    test('masks query parameters and bare JWTs', () {
      expect(
        Redactor.redact('/auth?code=XYZ&state=1'),
        '/auth?code=${Redactor.mask}&state=1',
      );
      expect(
        Redactor.redact('token is $jwt ok'),
        'token is ${Redactor.mask} ok',
      );
    });

    test('leaves normal text alone', () {
      const text = 'GET /api/states → 200 (light.living_room)';
      expect(Redactor.redact(text), text);
    });

    test('tail shows only the end of long secrets', () {
      expect(Redactor.tail('abcdefghijkl'), '…ijkl');
      expect(Redactor.tail('short'), Redactor.mask);
    });
  });

  test('AppLogger redacts messages and errors before the sink', () {
    final records = <LogRecord>[];
    final previousSink = AppLogger.sink;
    final previousLevel = AppLogger.minimumLevel;
    AppLogger.sink = records.add;
    AppLogger.minimumLevel = LogLevel.debug;
    addTearDown(() {
      AppLogger.sink = previousSink;
      AppLogger.minimumLevel = previousLevel;
    });

    AppLogger('Test')
      ..info('sending {"access_token":"$jwt"}')
      ..error('failed', Exception('Bearer $jwt'));

    expect(records, hasLength(2));
    for (final r in records) {
      expect(r.message, isNot(contains(jwt)));
    }
  });

  test('AppLogger respects minimum level', () {
    final records = <LogRecord>[];
    final previousSink = AppLogger.sink;
    final previousLevel = AppLogger.minimumLevel;
    AppLogger.sink = records.add;
    AppLogger.minimumLevel = LogLevel.warning;
    addTearDown(() {
      AppLogger.sink = previousSink;
      AppLogger.minimumLevel = previousLevel;
    });

    AppLogger('Test')
      ..debug('x')
      ..info('y')
      ..warning('z');
    expect(records.map((r) => r.level), [LogLevel.warning]);
  });
}
