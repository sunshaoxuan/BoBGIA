import 'dart:async';
import '../services/monitoring/monitor.dart';
import '../services/logging/logger.dart';

class MonitoringMiddleware {
  final ServiceMonitor _monitor;
  final AppLogger _logger;

  MonitoringMiddleware({
    ServiceMonitor? monitor,
    AppLogger? logger,
  })  : _monitor = monitor ?? ServiceMonitor(),
        _logger = logger ?? AppLogger();

  Future<T> monitorServiceCall<T>({
    required String service,
    required String endpoint,
    required Future<T> Function() call,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _monitor.recordRequest(service, endpoint);
      
      final result = await call();
      
      stopwatch.stop();
      _monitor.recordResponseTime(
        service,
        endpoint,
        stopwatch.elapsedMilliseconds / 1000,
      );
      
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      _monitor.recordError(service, e.runtimeType.toString());
      _logger.log(
        LogLevel.error,
        'Service call failed',
        error: e,
        stackTrace: stackTrace,
        extra: {
          'service': service,
          'endpoint': endpoint,
          'duration': stopwatch.elapsedMilliseconds / 1000,
        },
      );
      
      rethrow;
    }
  }
} 