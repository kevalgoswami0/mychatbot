import 'dart:async';

/// Utility to debounce fast repetitive invocations (e.g. search input).
class Debouncer {
  Debouncer({required this.duration});

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Utility to throttle continuous stream updates (e.g. 50ms batching for 60/120fps streaming).
class Throttler {
  Throttler({required this.duration});

  final Duration duration;
  Timer? _timer;
  bool _isWaiting = false;

  void run(void Function() action) {
    if (!_isWaiting) {
      action();
      _isWaiting = true;
      _timer = Timer(duration, () {
        _isWaiting = false;
      });
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _isWaiting = false;
  }
}
