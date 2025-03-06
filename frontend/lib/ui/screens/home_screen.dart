import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(
          title: const Text('BoBGIA'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to BoBGIA',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  try {
                    developer.log('正在导航到地图页面');
                    Navigator.pushNamed(context, '/map');
                  } catch (e, stack) {
                    developer.log('导航到地图页面失败', error: e, stackTrace: stack);
                  }
                },
                child: const Text('打开地图'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  try {
                    developer.log('正在导航到设置页面');
                    Navigator.pushNamed(context, '/settings');
                  } catch (e, stack) {
                    developer.log('导航到设置页面失败', error: e, stackTrace: stack);
                  }
                },
                child: const Text('设置'),
              ),
            ],
          ),
        ),
      );
    } catch (e, stack) {
      developer.log('构建主页面时发生错误', error: e, stackTrace: stack);
      return Scaffold(
        body: Center(
          child: Text('加载失败: $e'),
        ),
      );
    }
  }
} 