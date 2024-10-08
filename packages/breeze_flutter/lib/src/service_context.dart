import 'package:flutter/widgets.dart';
import 'package:breeze/breeze.dart';

/// Enables access to [ServiceProvider] for resolving services in the widget tree.
class ServiceContext extends StatefulWidget {
  final Widget child;
  final ServiceProvider? provider;

  /// Creates a top-level [ServiceContext] with the specified [provider].
  ///
  /// Only a single top-level [ServiceContext] can exist in a widget tree. A [StateError]
  /// is thrown if another top-level [ServiceContext] already exists.
  const ServiceContext(
      {super.key, required ServiceProvider provider, required this.child})
      // ignore: prefer_initializing_formals
      : provider = provider;

  /// Creates a scoped [ServiceContext] from existing top-level [ServiceContext], which allows
  /// resolving scoped services.
  ///
  /// The service scope is created when [ServiceContext] is built for the first time.
  /// [Disposable] scoped services resolved from this [ServiceContext] will be disposed
  /// automatically when the [ServiceContext] is disposed.
  const ServiceContext.scoped({super.key, required this.child})
      : provider = null;

  @override
  State<StatefulWidget> createState() {
    return _ServiceContextState();
  }
}

class _ServiceContextState extends State<ServiceContext> {
  ServiceScope? _scope;

  @override
  void dispose() {
    _scope?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scope == null) {
      if (widget.provider != null) {
        _scope = widget.provider!.createScope();
      } else {
        _scope =
            _ServiceScopeSlot.of(context).scope.serviceProvider.createScope();
      }
    }

    if (widget.provider != null) {
      if (_RootSlot.maybeOf(context) != null) {
        throw StateError(
            'Top-level ServiceContext cannot be nested. Use ServiceContext.scoped instead.');
      } else {
        return _RootSlot(
          child: _ServiceScopeSlot(scope: _scope!, child: widget.child),
        );
      }
    } else {
      return _ServiceScopeSlot(scope: _scope!, child: widget.child);
    }
  }
}

class _RootSlot extends InheritedWidget {
  const _RootSlot({required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }

  static _RootSlot? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_RootSlot>();
  }
}

class _ServiceScopeSlot extends InheritedWidget {
  final ServiceScope scope;
  const _ServiceScopeSlot({required this.scope, required super.child});

  @override
  bool updateShouldNotify(_ServiceScopeSlot oldWidget) {
    return false;
  }

  static _ServiceScopeSlot of(BuildContext context) {
    final r = context.dependOnInheritedWidgetOfExactType<_ServiceScopeSlot>();
    assert(r != null);
    return r!;
  }
}

/// Resolves [TService] from the nearest [ServiceContext] and build a widget with the resolved service.
class With<TService> extends StatelessWidget {
  /// A function for building the widget using the resolved service(s).
  final Widget Function(BuildContext, TService, Widget?) builder;

  /// A service-independent widget which is passed back to the [builder].
  final Widget? child;

  /// Resolves [TService] from the nearest [ServiceContext] and build a widget with the resolved service.
  ///
  /// The [child] is optional but is good practice to use if part of the widget subtree does not depend on the resolved service(s).
  const With({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
        context, sp.scope.serviceProvider.getRequiredService(), child);
  }
}

/// Resolves [T1] and [T2] from the nearest [ServiceContext] and build a widget with the resolved service.
class With2<T1, T2> extends StatelessWidget {
  /// A function for building the widget using the resolved service(s).
  final Widget Function(BuildContext, T1, T2, Widget?) builder;

  /// A service-independent widget which is passed back to the [builder].
  final Widget? child;

  /// Resolves [T1] and [T2] from the nearest [ServiceContext] and build a widget with the resolved service.
  ///
  /// The [child] is optional but is good practice to use if part of the widget subtree does not depend on the resolved service(s).
  const With2({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

/// Resolves [T1], [T2] and [T3] from the nearest [ServiceContext] and build a widget with the resolved service.
class With3<T1, T2, T3> extends StatelessWidget {
  /// A function for building the widget using the resolved service(s).
  final Widget Function(BuildContext, T1, T2, T3, Widget?) builder;

  /// A service-independent widget which is passed back to the [builder].
  final Widget? child;

  /// Resolves [T1], [T2] and [T3] from the nearest [ServiceContext] and build a widget with the resolved service.
  ///
  /// The [child] is optional but is good practice to use if part of the widget subtree does not depend on the resolved service(s).
  const With3({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

class With4<T1, T2, T3, T4> extends StatelessWidget {
  final Widget Function(BuildContext, T1, T2, T3, T4, Widget?) builder;
  final Widget? child;
  const With4({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

class With5<T1, T2, T3, T4, T5> extends StatelessWidget {
  final Widget Function(BuildContext, T1, T2, T3, T4, T5, Widget?) builder;
  final Widget? child;
  const With5({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

class With6<T1, T2, T3, T4, T5, T6> extends StatelessWidget {
  final Widget Function(BuildContext, T1, T2, T3, T4, T5, T6, Widget?) builder;
  final Widget? child;
  const With6({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

class With7<T1, T2, T3, T4, T5, T6, T7> extends StatelessWidget {
  final Widget Function(BuildContext, T1, T2, T3, T4, T5, T6, T7, Widget?)
      builder;
  final Widget? child;
  const With7({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

class With8<T1, T2, T3, T4, T5, T6, T7, T8> extends StatelessWidget {
  final Widget Function(BuildContext, T1, T2, T3, T4, T5, T6, T7, T8, Widget?)
      builder;
  final Widget? child;
  const With8({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

class With9<T1, T2, T3, T4, T5, T6, T7, T8, T9> extends StatelessWidget {
  final Widget Function(
      BuildContext, T1, T2, T3, T4, T5, T6, T7, T8, T9, Widget?) builder;
  final Widget? child;
  const With9({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}

class With10<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10> extends StatelessWidget {
  final Widget Function(
      BuildContext, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, Widget?) builder;
  final Widget? child;
  const With10({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final sp = _ServiceScopeSlot.of(context);
    return builder(
      context,
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      sp.scope.serviceProvider.getRequiredService(),
      child,
    );
  }
}
