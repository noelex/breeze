import 'package:breeze/breeze.dart';
import 'package:breeze_flutter/breeze_flutter.dart';
import 'package:flutter/material.dart';

class Counter extends ValueNotifier<int> implements Disposable {
  Counter() : super(0);

  void increment() {
    super.value = super.value + 1;
  }
}

void main() {
  final rootScope = ServiceProviderBuilder()
      .configureServices((services) => services.addSingleton((sp) => Counter()))
      .build();

  runApp(
    ServiceContext(
      provider: rootScope.serviceProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Flutter Demo Home Page'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.directions_car)),
                Tab(icon: Icon(Icons.directions_transit)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildTabPage(context),
              _buildTabPage(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabPage(BuildContext context) {
    return ServiceContext.scoped(
      child: Center(
        child: With<Counter>(
          builder: (context, counter, child) => TextButton(
            onPressed: () => counter.increment(),
            child: ValueListenableBuilder(
              valueListenable: counter,
              builder: (context, value, widget) => Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
