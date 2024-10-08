import 'package:test/test.dart';
import 'package:breeze/breeze.dart';

abstract class MyInterface {
  int get id;
}

class MyService implements MyInterface {
  final int _id;
  MyService(this._id);

  @override
  int get id => _id;
}

class AnotherService implements MyInterface {
  final int _id;
  AnotherService(this._id);

  @override
  int get id => _id;
}

// For testing cyclic dependency.
// ServiceA <-> ServiceB
class ServiceA {
  final ServiceB s;
  ServiceA(this.s);
}

class ServiceB {
  final ServiceA s;
  ServiceB(this.s);
}

// For testing indirect cyclic dependency.
// Service1 -> Service2 -> Service3 -> Service1
class Service1 {
  final Service3 s;
  Service1(this.s);
}

class Service2 {
  final Service1 s;
  Service2(this.s);
}

class Service3 {
  final Service2 s;
  Service3(this.s);
}

class DisposableService implements Disposable {
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  group('Singleton service resolution', () {
    test('resolve singleton registered as externally created instance', () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addSingletonInstance(MyService(1)))
          .build();
      try {
        final s1 = root.serviceProvider.getRequiredService<MyService>();
        final s2 = root.serviceProvider.getRequiredService<MyService>();
        expect(s1, equals(s2));
      } finally {
        root.dispose();
      }
    });

    test('resolve singleton registered as factory method', () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addSingleton((sp) => MyService(1)))
          .build();
      try {
        final s1 = root.serviceProvider.getRequiredService<MyService>();
        final s2 = root.serviceProvider.getRequiredService<MyService>();
        expect(s1, equals(s2));
      } finally {
        root.dispose();
      }
    });

    test(
        'externally created singleton instance is not disposed along with the root service scope',
        () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addSingletonInstance(DisposableService()))
          .build();

      DisposableService s;
      try {
        s = root.serviceProvider.getRequiredService<DisposableService>();
      } finally {
        root.dispose();
      }

      expect(s.disposed, equals(false));
    });

    test(
        'non externally created singleton instance is disposed along with the root service scope',
        () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addSingleton((sp) => DisposableService()))
          .build();

      DisposableService s;
      try {
        s = root.serviceProvider.getRequiredService<DisposableService>();
      } finally {
        root.dispose();
      }

      expect(s.disposed, equals(true));
    });
  });

  group('Service scopes', () {
    test(
        'ServiceProvider is the resolved to the root ServiceProvider when resolved in root service scope',
        () {
      final root = ServiceProviderBuilder().build();

      try {
        final rootServiceProvider =
            root.serviceProvider.getRequiredService<ServiceProvider>();
        expect(rootServiceProvider, equals(root.serviceProvider));
      } finally {
        root.dispose();
      }
    });

    test('create service scope', () {
      final root = ServiceProviderBuilder().build();

      try {
        final facotry =
            root.serviceProvider.getRequiredService<ServiceScopeFactory>();
        final scope = facotry.createScope();
        scope.dispose();
      } finally {
        root.dispose();
      }
    });

    test(
        'ServiceProvider is the resolved to the scoped ServiceProvider when resolved in a non-root service scope',
        () {
      final root = ServiceProviderBuilder().build();
      try {
        final scopeFactory =
            root.serviceProvider.getRequiredService<ServiceScopeFactory>();

        final scope1 = scopeFactory.createScope();
        final scope2 = scopeFactory.createScope();

        try {
          final scope1Sp1 =
              scope1.serviceProvider.getRequiredService<ServiceProvider>();
          final scope1Sp2 =
              scope1.serviceProvider.getRequiredService<ServiceProvider>();
          final scope2Sp1 =
              scope2.serviceProvider.getRequiredService<ServiceProvider>();
          final scope2Sp2 =
              scope2.serviceProvider.getRequiredService<ServiceProvider>();

          expect(scope1Sp1, equals(scope1Sp2));
          expect(scope2Sp1, equals(scope2Sp2));

          expect(scope1Sp1, isNot(equals(root.serviceProvider)));
          expect(scope2Sp1, isNot(equals(root.serviceProvider)));

          expect(scope1Sp1, isNot(equals(scope2Sp1)));
        } finally {
          scope1.dispose();
          scope2.dispose();
        }
      } finally {
        root.dispose();
      }
    });
  });

  group('Scoped service resolution', () {
    test('scoped service is not resolvable from root service scope', () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addScoped((sp) => MyService(1)))
          .build();

      Object? err;
      try {
        root.serviceProvider.getRequiredService<MyService>();
      } catch (e) {
        err = e;
      } finally {
        root.dispose();
      }

      expect(err, isA<UnresolvableServiceError>());
    });

    test('scoped service is created only once in a given service scope', () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addScoped((sp) => MyService(1)))
          .build();
      try {
        final scope = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        try {
          final s1 = scope.serviceProvider.getRequiredService<MyService>();
          final s2 = scope.serviceProvider.getRequiredService<MyService>();
          expect(s1, equals(s2));
        } finally {
          scope.dispose();
        }
      } finally {
        root.dispose();
      }
    });

    test(
        'different scoped service instances are created for different service scopes',
        () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addScoped((sp) => MyService(1)))
          .build();
      try {
        final scope1 = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        final scope2 = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        try {
          final s1 = scope1.serviceProvider.getRequiredService<MyService>();
          final s2 = scope2.serviceProvider.getRequiredService<MyService>();
          expect(s1, isNot(equals(s2)));
        } finally {
          scope1.dispose();
          scope2.dispose();
        }
      } finally {
        root.dispose();
      }
    });

    test(
        'scoped service instance is disposed along with associated service scope',
        () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addScoped((sp) => DisposableService()))
          .build();
      try {
        final scope = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        DisposableService s;
        try {
          s = scope.serviceProvider.getRequiredService<DisposableService>();
        } finally {
          scope.dispose();
        }
        expect(s.disposed, equals(true));
      } finally {
        root.dispose();
      }
    });
  });

  group('Transient service resolution', () {
    test('new instance of transient service is created each time when resolved',
        () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addTransient((sp) => MyService(1)))
          .build();
      try {
        final MyService s1 = root.serviceProvider.getRequiredService(),
            s2 = root.serviceProvider.getRequiredService();
        expect(s1, isNot(equals(s2)));
      } finally {
        root.dispose();
      }
    });

    test(
        'instance of transient service is not disposed along with root or non-root service scopes',
        () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addTransient((sp) => DisposableService()))
          .build();

      DisposableService sRoot, sScoped;
      try {
        sRoot = root.serviceProvider.getRequiredService();
        final scope = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        try {
          sScoped = scope.serviceProvider.getRequiredService();
        } finally {
          scope.dispose();
        }
      } finally {
        root.dispose();
      }

      expect(sRoot, isNot(equals(sScoped)));
      expect(sRoot.disposed, equals(false));
      expect(sScoped.disposed, equals(false));
    });
  });

  group('Multiple registrations', () {
    test(
        'resolve to last registered service when there are multiple registrations',
        () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingletonInstance(MyService(0))
              .addSingleton((sp) => MyService(1))
              .addTransient((sp) => MyService(2)))
          .build();

      try {
        final MyService s1 = root.serviceProvider.getRequiredService(),
            s2 = root.serviceProvider.getRequiredService();
        expect(s1, isNot(equals(s2)));
        expect(s1.id, equals(2));
        expect(s2.id, equals(2));
      } finally {
        root.dispose();
      }
    });

    test(
        'getServices/getRequiredServices returns a list of all instances in the order of registration',
        () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingletonInstance(MyService(0))
              .addSingleton((sp) => MyService(1))
              .addTransient((sp) => MyService(2)))
          .build();

      try {
        final services = root.serviceProvider.getRequiredServices<MyService>();
        expect(services.length, equals(3));
        expect(services[0].id, equals(0));
        expect(services[1].id, equals(1));
        expect(services[2].id, equals(2));
      } finally {
        root.dispose();
      }
    });

    test(
        'getServices/getRequiredServices ignores scoped services when called on root scope',
        () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingletonInstance(MyService(0))
              .addSingleton((sp) => MyService(1))
              .addTransient((sp) => MyService(2))
              .addScoped((sp) => MyService(3)))
          .build();

      try {
        final services = root.serviceProvider.getRequiredServices<MyService>();
        expect(services.length, equals(3));
        expect(services[0].id, equals(0));
        expect(services[1].id, equals(1));
        expect(services[2].id, equals(2));
      } finally {
        root.dispose();
      }
    });

    test(
        'getServices/getRequiredServices includes scoped services when called on non-root scope',
        () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingletonInstance(MyService(0))
              .addSingleton((sp) => MyService(1))
              .addTransient((sp) => MyService(2))
              .addScoped((sp) => MyService(3)))
          .build();

      try {
        final scope = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        try {
          final services =
              scope.serviceProvider.getRequiredServices<MyService>();
          expect(services.length, equals(4));
          expect(services[0].id, equals(0));
          expect(services[1].id, equals(1));
          expect(services[2].id, equals(2));
          expect(services[3].id, equals(3));
        } finally {
          scope.dispose();
        }
      } finally {
        root.dispose();
      }
    });

    test('resolution result is cached when there is not transient service', () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingletonInstance(MyService(0))
              .addSingleton((sp) => MyService(1))
              .addScoped((sp) => MyService(2)))
          .build();

      try {
        final scope = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        try {
          final s1 = scope.serviceProvider.getServices<MyService>();
          final s2 = scope.serviceProvider.getServices<MyService>();
          expect(s1, equals(s2));
        } finally {
          scope.dispose();
        }
      } finally {
        root.dispose();
      }
    });

    test(
        'resolution result is NOT cached when there is at least one transient service',
        () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingletonInstance(MyService(0))
              .addSingleton((sp) => MyService(1))
              .addTransient((sp) => MyService(2))
              .addScoped((sp) => MyService(3)))
          .build();

      try {
        final scope = root.serviceProvider
            .getRequiredService<ServiceScopeFactory>()
            .createScope();
        try {
          final s1 = scope.serviceProvider.getServices<MyService>();
          final s2 = scope.serviceProvider.getServices<MyService>();
          expect(s1, isNot(equals(s2)));
        } finally {
          scope.dispose();
        }
      } finally {
        root.dispose();
      }
    });

    test('multiple registration with different implementation types', () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingleton<MyInterface>((sp) => MyService(0))
              .addSingleton<MyInterface>((sp) => AnotherService(1)))
          .build();

      try {
        final services =
            root.serviceProvider.getRequiredServices<MyInterface>();
        expect(services.length, equals(2));
        expect(services[0], isA<MyService>());
        expect(services[1], isA<AnotherService>());
      } finally {
        root.dispose();
      }
    });
  });

  group('Cyclic dependency detection', () {
    test('detect cyclic dependency', () {
      final root = ServiceProviderBuilder()
          .configureServices(
            (services) => services
                .addSingleton((sp) => ServiceA(sp.getRequiredService()))
                .addSingleton((sp) => ServiceB(sp.getRequiredService())),
          )
          .build();

      try {
        root.serviceProvider.getRequiredService<ServiceA>();
      } catch (e) {
        expect(e, isA<CyclicDependencyError>());
      } finally {
        root.dispose();
      }
    });

    test('detect indirect cyclic dependency', () {
      final root = ServiceProviderBuilder()
          .configureServices(
            (services) => services
                .addSingleton((sp) => Service1(sp.getRequiredService()))
                .addSingleton((sp) => Service2(sp.getRequiredService()))
                .addSingleton((sp) => Service3(sp.getRequiredService())),
          )
          .build();

      try {
        root.serviceProvider.getRequiredService<Service1>();
      } catch (e) {
        expect(e, isA<CyclicDependencyError>());
      } finally {
        root.dispose();
      }
    });
  });

  group('Non-generic resolution', () {
    test('results of generic and non-generic resolutions is the same', () {
      final root = ServiceProviderBuilder()
          .configureServices(
              (services) => services.addSingleton((sp) => MyService(0)))
          .build();
      try {
        final s1 = root.serviceProvider.getRequiredServiceOfType(MyService);
        final s2 = root.serviceProvider.getRequiredService<MyService>();
        expect(s1, equals(s2));
      } finally {
        root.dispose();
      }
    });

    test(
        'non-generic service list resolution result is cached when there is no transient service',
        () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingleton((sp) => MyService(0))
              .addSingleton((sp) => MyService(1)))
          .build();
      try {
        final s1 = root.serviceProvider.getRequiredServicesOfType(MyService);
        final s2 = root.serviceProvider.getRequiredServicesOfType(MyService);
        expect(s1, equals(s2));
        expect((s1[0] as MyService).id, equals(0));
        expect((s1[1] as MyService).id, equals(1));
      } finally {
        root.dispose();
      }
    });

    test(
        'non-generic service list resolution result is NOT cached when there is at least one transient service',
        () {
      final root = ServiceProviderBuilder()
          .configureServices((services) => services
              .addSingleton((sp) => MyService(0))
              .addSingleton((sp) => MyService(1))
              .addTransient((sp) => MyService(2)))
          .build();
      try {
        final s1 = root.serviceProvider.getRequiredServicesOfType(MyService);
        final s2 = root.serviceProvider.getRequiredServicesOfType(MyService);
        expect(s1, isNot(equals(s2)));
        expect(s1[2], isNot(equals(s2[2])));
      } finally {
        root.dispose();
      }
    });
  });
}
