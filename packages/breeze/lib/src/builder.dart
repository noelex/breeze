import 'service_provider.dart';

/// Represents a factory method for instantiating the service of type [T].
typedef ServiceFactory<T> = T Function(ServiceProvider serviceProvider);

/// Represents the lifetime of service instances managed by [ServiceScope].
enum ServiceLifetime {
  /// New instances of transient services are created
  /// each time when service resolution is requested.
  /// The instance is not cached by any [ServiceScope] and
  /// is not disposed even if it implements [Disposable] interface.
  transient,

  /// Scoped services can only be resolve in non-root [ServiceScope]s
  /// (that is, [ServiceScope]s created explicitly using [ServiceScopeFactory]).
  /// The lifetime of a scoped service is bound to the [ServiceScope] which
  /// instantiated the services. If a scoped service implements [Disposable], it
  /// is disposed when its associated [ServiceScope] is disposed.
  scoped,

  /// A singleton service will have only one instance across a [ServiceScope] hierachy.
  /// If a singleton service implements [Disposable] and is not registered as an 
  /// externally created instance, it is disposed when its associated root [ServiceScope] is disposed.
  singleton
}

/// A non-generic version of [ServiceFactory].
typedef ServiceCreator = Object Function(ServiceProvider provider);

/// Defines how a service is created and disposed.
class ServiceDescriptor {
  late final Type _type;
  late final ServiceLifetime _lifetime;
  late final Object? _instance;
  late final ServiceCreator? _factory;

  /// Creates a [ServiceDescriptor] with specified service type, lifetime
  /// and a factory method to create instance for the service.
  ServiceDescriptor.withFactory(
      Type type,
      Object Function(ServiceProvider provider) factory,
      ServiceLifetime lifetime) {
    _type = type;
    _lifetime = lifetime;
    _factory = factory;
    _instance = null;
  }

  /// Create a [ServiceDescriptor] with specified service type and an externally created instance.
  /// The service is registered as singleton and it's not disposed along with the root [ServiceScope].
  ServiceDescriptor.withInstance(Type type, Object instance) {
    _type = type;
    _lifetime = ServiceLifetime.singleton;
    _instance = instance;
    _factory = null;
  }

  /// Type of the service.
  Type get type => _type;

  /// Lifetime of the service.
  ServiceLifetime get lifetime => _lifetime;

  /// Externally created instance of the service, if the [ServiceDescriptor] is created using [ServiceDescriptor.withInstance].
  Object? get instance => _instance;

  /// Factory method for instantiating the service, if the [ServiceDescriptor] is created using [ServiceDescriptor.withFactory].
  ServiceCreator? get factory => _factory;
}

/// Represents a container for registering services.
abstract class ServiceCollection {
  /// Adds a [ServiceDescriptor] to the collection.
  /// Returns current [ServiceCollection] instance for chaining options.
  ServiceCollection add(ServiceDescriptor descriptor);

  /// Adds a [ServiceDescriptor] to the collection. If [ServiceDescriptor.type]
  /// already exists in the collection, no action is taken.
  /// Returns current [ServiceCollection] instance for chaining options.
  ServiceCollection tryAdd(ServiceDescriptor descriptor);

  /// Returns a snapshot of currently registered services.
  List<ServiceDescriptor> getServices();
}

/// Helper methods for registering services to [ServiceCollection].
extension BuilderServiceCollectionExtensions on ServiceCollection {
  /// Adds a singleton service of type [TService] to the [ServiceCollection] only when
  /// there's not existing registration of [TService].
  ServiceCollection tryAddSingleton<TService>(
      ServiceFactory<TService> factory) {
    return tryAdd(ServiceDescriptor.withFactory(
        TService,
        (ServiceProvider sp) => factory(sp) as Object,
        ServiceLifetime.singleton));
  }

  /// Adds a singleton service of type [TService] to the [ServiceCollection].
  ServiceCollection addSingleton<TService>(ServiceFactory<TService> factory) {
    return add(ServiceDescriptor.withFactory(
        TService,
        (ServiceProvider sp) => factory(sp) as Object,
        ServiceLifetime.singleton));
  }

  /// Adds a singleton service of type [TService] to the [ServiceCollection] with an externally
  /// created instance.
  /// The service instance registered with this method is considered as owned by the caller.
  /// Thus it is NOT disposed along with the root [ServiceScope] 
  /// even if it implements the [Disposable] interface.
  ServiceCollection
      addSingletonInstanceWithType<TService, TImplementation extends TService>(
          TImplementation instance) {
    return add(ServiceDescriptor.withInstance(TService, instance as Object));
  }

  /// Adds a singleton service of type [instance.runtimeType] to the [ServiceCollection] with an externally
  /// created instance.
  /// The service instance registered with this method is considered as owned by the caller.
  /// Thus it is NOT disposed along with the root [ServiceScope] 
  /// even if it implements the [Disposable] interface.
  ServiceCollection addSingletonInstance(Object instance) {
    return add(ServiceDescriptor.withInstance(instance.runtimeType, instance));
  }

  /// Adds a scoped service of type [TService] to the [ServiceCollection].
  ServiceCollection addScoped<TService>(ServiceFactory<TService> factory) {
    return add(ServiceDescriptor.withFactory(TService,
        (ServiceProvider sp) => factory(sp) as Object, ServiceLifetime.scoped));
  }

  /// Adds a transient service of type [TService] to the [ServiceCollection].
  ServiceCollection addTransient<TService>(ServiceFactory<TService> factory) {
    return add(ServiceDescriptor.withFactory(
        TService,
        (ServiceProvider sp) => factory(sp) as Object,
        ServiceLifetime.transient));
  }
}

/// An implementation of [ServiceCollection] interface which is also able to build
/// a root [ServiceScope] for resolving services.
class ServiceProviderBuilder implements ServiceCollection {
  final List<ServiceDescriptor> _services = [];

  bool _exists(Type type) => _services.any((s) => s.type == type);

  @override
  ServiceProviderBuilder add(ServiceDescriptor descriptor) {
    _services.add(descriptor);
    return this;
  }

  @override
  ServiceCollection tryAdd(ServiceDescriptor descriptor) {
    if (!_exists(descriptor.type)) {
      _services.add(descriptor);
    }
    return this;
  }

  /// Encapsulates service registration calls in the [builder] so that
  /// the caller can chain a call to [build] when done.
  /// 
  /// e.g. scope = builder.configureServices((services) => ...).build();
  ServiceProviderBuilder configureServices(
      void Function(ServiceCollection services) builder) {
    builder(this);
    return this;
  }

  /// Builds a root [ServiceScope] using currently registered services.
  /// 
  /// Service instances can be resolved using [ServiceScope.serviceProvider].
  /// 
  /// You cannot resolve scoped service using the returned [ServiceScope].
  /// Instead, please create a non-root [ServiceScope] by using the [ServiceScopeFactory]
  /// resolved from the root [ServiceProvider], and use the [ServiceProvider]
  /// associated with the non-root [ServiceScope] to resolve scoped services. 
  ServiceScope build() {
    return DefaultServiceProvider(_services);
  }

  @override
  List<ServiceDescriptor> getServices() => List.unmodifiable(_services);
}
