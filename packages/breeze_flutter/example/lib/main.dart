import 'package:flutter/material.dart';
import 'package:breeze/breeze.dart';
import 'package:breeze_flutter/breeze_flutter.dart';

class Counter extends ValueNotifier<int> implements Disposable {
  Counter() : super(0);

  void increment() => super.value += 1;
}

void main() {
  final rootScope = ServiceProviderBuilder()
      .configureServices((services) => services.addSingleton((sp) => Counter()))
      .build();

  runApp(ServiceContext(
    provider: rootScope.serviceProvider,
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return With<Counter>(
      builder: (context, counter, _) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Counter example')),
          body: Center(
            child: ValueListenableBuilder(
              valueListenable: counter,
              builder: (context, value, child) => Text('$value'),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => counter.increment(),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
