import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../security/redactor.dart';

enum LogLevel { debug, info, warning, error }

/// A log record after redaction. Exposed so tests and future sinks
/// (e.g. an exportable diagnostics file) can observe it.
@immutable
class LogRecord {
  const LogRecord(this.level, this.tag, this.message, this.time);

  final LogLevel level;
  final String tag;
  final String message;
  final DateTime time;
}

typedef LogSink = void Function(LogRecord record);

/// Structured, redacting logger.
///
/// * debug/profile builds: everything from [LogLevel.debug] up.
/// * release builds: [LogLevel.warning] and above only.
/// * every message and error passes through [Redactor] before any sink.
class AppLogger {
  AppLogger(this.tag);

  final String tag;

  static LogLevel minimumLevel = kReleaseMode
      ? LogLevel.warning
      : LogLevel.debug;

  static LogSink sink = _developerSink;

  /// The last warnings and errors (already redacted), newest last, for the
  /// installer's service screen. Kept in memory only.
  static final List<LogRecord> recentProblems = [];
  static const _keepProblems = 50;

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message, [Object? error]) =>
      _log(LogLevel.warning, message, error);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (level.index < minimumLevel.index) return;
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | $error');
    // Stack traces are useful in development only.
    if (stackTrace != null && !kReleaseMode) buffer.write('\n$stackTrace');
    final record = LogRecord(
      level,
      tag,
      Redactor.redact(buffer.toString()),
      DateTime.now(),
    );
    if (level.index >= LogLevel.warning.index) {
      recentProblems.add(record);
      if (recentProblems.length > _keepProblems) recentProblems.removeAt(0);
    }
    sink(record);
  }

  static void _developerSink(LogRecord record) {
    developer.log(
      record.message,
      name: record.tag,
      level: switch (record.level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      time: record.time,
    );
  }
}
