import 'package:breeze/breeze.dart';

/// Defines methods for objects that are managed by the host.
abstract class HostedService {
  /// Triggered when the application host is ready to start the service.
  Future<void> start(CancellationToken cancellationToken);

  /// Triggered when the application host is performing a graceful shutdown.
  Future<void> stop(CancellationToken cancellationToken);
}

/// Extension methods for registering [HostedService]s.
extension ServiceHostServiceCollectionExtensions on ServiceCollection {
  /// Add a [HostedService] registration for the given type.
  ServiceCollection addHostedService<TService extends HostedService>(
      ServiceFactory<TService> factory) {
    return addSingleton<HostedService>(factory);
  }

  /// Add a [HostedService] registration for the given type with the specified instance.
  ServiceCollection addHostedServiceInstance<TService extends HostedService>(
      TService instance) {
    return addSingletonInstanceWithType<HostedService, TService>(instance);
  }
}

/// Extension methods for manipulating [Host]s.
extension ServiceHostServiceHostExtensions on Host {
  /// Waits until shutdown is triggered via the given [cancellationToken].
  ///
  /// This method does not throw even if [cancellationToken] gets canceled.
  Future<void> waitForShutdown(CancellationToken cancellationToken) async {
    await cancellationToken.future;
    await stop(CancellationToken.none);
  }

  /// Runs the [Host] and returns a [Future] that only completes when the [cancellationToken] is triggered or shutdown is triggered.
  /// The [Host] instance is disposed of after running.
  Future<void> run(CancellationToken cancellationToken) async {
    await start(cancellationToken);
    try {
      await waitForShutdown(cancellationToken);
    } finally {
      dispose();
    }
  }
}

/// Represents a program for hosting services.
abstract class Host implements Disposable {
  /// Provides access to the services configured for the program.
  ServiceProvider get services;

  /// Starts the [HostedService]s configured for the program.
  /// The application will run until [stop] is called.
  Future<void> start(CancellationToken cancellationToken);

  /// Attempts to gracefully stop the program.
  Future<void> stop(CancellationToken cancellationToken);

  /// Creates an instance of [DefaultHostBuilder].
  static HostBuilder createDefaultBuilder() {
    return DefaultHostBuilder();
  }
}

/// Encapsulates options for [Host]s.
class HostOptions {

  /// Determines if the [Host] will start registered instances of [HostedService]s  concurrently or sequentially.
  final bool servicesStartConcurrently;

  /// Determines if the [Host] will stop registered instances of [HostedService]s  concurrently or sequentially.
  final bool servicesStopConcurrently;

  /// Creates an instance of [HostOptions].
  HostOptions(
      {this.servicesStartConcurrently = false,
      this.servicesStopConcurrently = false});
}

/// Provides an extension point for creating a custom [ServiceProvider].
typedef ServiceProviderFactory = ServiceScope Function(
    ServiceCollection services);

/// Provides essential methods to build a [Host].
abstract class HostBuilder {

  /// A central location for sharing state between components during the host building process.
  Map<String, Object?> get properties;

  /// Overrides the factory used to create the service provider.
  HostBuilder useServiceProviderFactory(ServiceProviderFactory factory);

  /// Adds services to the container.
  /// This can be called multiple times and the results will be additive.
  HostBuilder configureServices(
      void Function(ServiceCollection services) configure);

  /// Runs the given actions to initialize the host. This can only be called once.
  Host build();
}

/// A default implementation of [HostBuilder].
class DefaultHostBuilder implements HostBuilder {
  final _services = ServiceProviderBuilder();
  final _properties = <String, Object?>{};

  ServiceProviderFactory? _providerFactory;

  @override
  HostBuilder configureServices(
      void Function(ServiceCollection services) configure) {
    configure(_services);
    return this;
  }

  @override
  Map<String, Object?> get properties => _properties;

  @override
  Host build() {
    final root = _providerFactory?.call(_services) ?? _services.build();
    return DefaultHost(root);
  }

  @override
  HostBuilder useServiceProviderFactory(ServiceProviderFactory factory) {
    _providerFactory = factory;
    return this;
  }
}

/// A default implementation of [Host].
class DefaultHost implements Host {
  late final ServiceScope _rootScope;
  late final ServiceProvider _services;
  late final List<HostedService> _hostedServices;
  late final HostOptions _options;

  DefaultHost(ServiceScope rootScope) {
    _rootScope = rootScope;
    _services = rootScope.serviceProvider;
    _hostedServices = _services.getServices<HostedService>() ?? [];
    _options = _services.getService<HostOptions>() ?? HostOptions();
  }

  @override
  ServiceProvider get services => _services;

  @override
  Future<void> start(CancellationToken cancellationToken) async {
    if (_options.servicesStartConcurrently) {
      await Future.wait(_hostedServices.map((s) => s.start(cancellationToken)));
    } else {
      for (final s in _hostedServices) {
        await s.start(cancellationToken);
      }
    }
  }

  @override
  Future<void> stop(CancellationToken cancellationToken) async {
    if (_options.servicesStopConcurrently) {
      await Future.wait(_hostedServices.map((s) => s.stop(cancellationToken)));
    } else {
      for (final s in _hostedServices.reversed) {
        await s.stop(cancellationToken);
      }
    }
  }

  @override
  void dispose() => _rootScope.dispose();
}
