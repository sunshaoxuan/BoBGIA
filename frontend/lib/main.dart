import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'config/routes.dart';
import 'config/theme.dart';

void main() async {
  runZonedGuarded(() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      developer.log('Flutter绑定初始化成功');
      
      try {
        await dotenv.load(fileName: ".env");
        developer.log('环境变量加载成功: ${dotenv.env}');
      } catch (e, stack) {
        developer.log('环境变量加载失败', error: e, stackTrace: stack);
      }
      
      FlutterError.onError = (FlutterErrorDetails details) {
        developer.log(
          'Flutter错误',
          error: details.exception,
          stackTrace: details.stack,
        );
      };
      
      runApp(const MyApp());
      developer.log('应用启动成功');
    } catch (e, stack) {
      developer.log('启动过程中发生错误', error: e, stackTrace: stack);
    }
  }, (error, stack) {
    developer.log('未捕获的错误', error: error, stackTrace: stack);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return MaterialApp(
        title: 'BoBGIA',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        initialRoute: AppRoutes.home,
        routes: AppRoutes.getRoutes(),
        builder: (context, child) {
          return Banner(
            message: 'Debug',
            location: BannerLocation.topEnd,
            child: child!,
          );
        },
        navigatorObservers: [
          NavigatorObserver(),
        ],
        onUnknownRoute: (settings) {
          developer.log('未知路由: ${settings.name}');
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: Text('未找到页面: ${settings.name}'),
              ),
            ),
          );
        },
      );
    } catch (e, stack) {
      developer.log('构建应用时发生错误', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
