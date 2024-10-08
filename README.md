# Breeze

Breeze is a light-weight dependency injection library for Dart and Flutter apps.

## Features

- Supports singleton, scoped and transient service lifetime
- Automatical disposal of disposable services
- Cyclic dependency detection
- Allows registering and resolving multiple services registered with the same type
- Helper widgets to seamlessly integrate Breeze into the Flutter widget tree
- In-app service hosting API for managing in-app background services

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
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
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
