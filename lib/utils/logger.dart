import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum _Level { debug, info, warn, error }

/// 轻量日志工具，仅在 debug 模式下输出。
///
/// 用法：
/// ```dart
/// final _log = Logger('MyClass');
/// _log.d('item added: $id');
/// _log.dDebounced('scroll offset: $offset');  // 高频场景防抖
/// ```
class Logger {
  final String tag;

  /// debounce 间隔，默认 500ms
  final Duration debounceDuration;

  Logger(this.tag, {this.debounceDuration = const Duration(milliseconds: 500)});

  // ── 普通日志 ──────────────────────────────────────────

  void d(String message) => _log(_Level.debug, message);
  void i(String message) => _log(_Level.info, message);
  void w(String message) => _log(_Level.warn, message);
  void e(String message, {Object? error, StackTrace? stackTrace}) {
    _log(_Level.error, message, error: error, stackTrace: stackTrace);
  }

  // ── Debounced 版本（高频调用场景，如滚动、动画每帧）──────

  void dDebounced(String message) => _debounced(_Level.debug, message);
  void iDebounced(String message) => _debounced(_Level.info, message);
  void wDebounced(String message) => _debounced(_Level.warn, message);

  // ── 内部实现 ──────────────────────────────────────────

  static const _levelLabels = {
    _Level.debug: 'D',
    _Level.info:  'I',
    _Level.warn:  'W',
    _Level.error: 'E',
  };

  void _log(_Level level, String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    final label = _levelLabels[level]!;
    final output = '[$label/$tag] $message';
    developer.log(
      output,
      name: tag,
      error: error,
      stackTrace: stackTrace,
    );

    print(output);
  }

  // debounce 状态：key = message前缀（取前40字符），value = 上次输出时间
  final Map<String, DateTime> _lastLogTime = {};

  void _debounced(_Level level, String message) {
    if (!kDebugMode) return;
    final key = '${level.name}:${message.length > 40 ? message.substring(0, 40) : message}';
    final now = DateTime.now();
    final last = _lastLogTime[key];
    if (last != null && now.difference(last) < debounceDuration) return;
    _lastLogTime[key] = now;
    _log(level, message);
  }
}
