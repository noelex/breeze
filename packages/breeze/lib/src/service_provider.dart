import 'builder.dart';

/// Provides a mechanism for manually discarding resources.
abstract class Disposable {
  /// Discards any resources used by the object. After this is called, the
  /// object is not in a usable state and should be discarded.
  void dispose();
}

/// Defines a mechanism for retrieving a service object.
abstract class ServiceProvider {
  /// Gets the service object of the specified type.
  ///
  /// Returns null if the service is not resolved.
  T? getService<T>();

  /// Gets the service object of the specified type.
  ///
  /// An [UnresolvableServiceError] is thrown if the service is not resolved.
  T getRequiredService<T>();

  /// Gets all available service objects of the specified type.
  ///
  /// Returns null if the service is not resolved.
  List<T>? getServices<T>();

  /// Gets all available service objects of the specified type.
  ///
  /// An [UnresolvableServiceError] is thrown if the service is not resolved.
  List<T> getRequiredServices<T>();

  /// Gets the service object of the specified type.
  ///
  /// Returns null if the service is not resolved.
  Object? getServiceOfType(Type type);

  /// Gets the service object of the specified type.
  ///
  /// An [UnresolvableServiceError] is thrown if the service is not resolved.
  Object getRequiredServiceOfType(Type type);

  /// Gets all available service objects of the specified type.
  ///
  /// Returns null if the service is not resolved.
  List<Object>? getServicesOfType(Type type);

  /// Gets all available service objects of the specified type.
  ///
  /// An [UnresolvableServiceError] is thrown if the service is not resolved.
  List<Object> getRequiredServicesOfType(Type type);

  /// Creates a new [ServiceScope] for resolving scoped services.
  ServiceScope createScope();
}

/// Error thrown when the [ServiceProvider] is not able to resolve the specified service,
/// either because the service is not registered, or because the caller is trying to
/// resolve a scoped service inside a root [ServiceProvider].
class UnresolvableServiceError extends Error {
  /// Type of the service which caused this error.
  final Type serviceType;

  UnresolvableServiceError(this.serviceType);

  @override
  String toString() {
    return "Service '${serviceType.toString()}' is not resolvable from current ServiceScope.";
  }
}

/// Error thrown when the [ServiceProvider] detects a cyclic dependency when resolving the specified service.
class CyclicDependencyError extends Error {
  /// A list of service identifiers describing how the cyclic dependency is formed.
  final List<String> dependencyPath;

  /// Type of the service which caused this error.
  final Type serviceType;

  CyclicDependencyError(this.serviceType, this.dependencyPath);

  @override
  String toString() {
    return "Cyclic dependency detected when trying to resolve service '$serviceType': ${dependencyPath.join(' -> ')}.";
  }
}

/// Represents a service scope which controls the lifetime of scoped services resolved via [serviceProvider].
abstract class ServiceScope implements Disposable {
  /// Gets the [ServiceProvider] associated with current [ServiceScope].
  ServiceProvider get serviceProvider;
}

/// Provides factory method for creating [ServiceScope]s.
abstract class ServiceScopeFactory {
  /// Creates a [ServiceScope].
  /// All scoped services resolved via [ServiceScope.serviceProvider] are
  /// automatically disposed when the returned [ServiceScope] is disposed.
  ServiceScope createScope();
}

typedef _ServiceAccessor = Object Function(ServiceProvider serviceProvider);

class _ServiceEntry {
  /// Id of the [_ServiceEntry]. This is essentially the index of the associated [ServiceDescriptor]
  /// in the [ServiceProviderBuilder].
  final int id;

  /// Type of the service.
  final Type type;

  /// Is the service registered as transient?
  final bool transient;

  /// A [_ServiceAccessor] for accessing the instance of the service.
  final _ServiceAccessor accessor;

  _ServiceEntry(this.id, this.type, this.transient, this.accessor);
}

class DefaultServiceProvider
    implements ServiceProvider, Disposable, ServiceScopeFactory, ServiceScope {
  final List<_ServiceEntry> _services = [];

  /// Service instances created by current [DefaultServiceProvider].
  final Map<int, Object> _ownedInstances = {};

  /// Cached resolve results of [T]s
  final Map<Type, Object> _resolutionCacheSingle = {};

  /// Non-generic lists cached by _resolveAll
  final Map<Type, List<Object>> _resolutionCacheList = {};

  // Generic lists cached by getServices/getRequiredServices
  final Map<Type, Object> _resolutionCacheListTyped = {};

  /// Registered service descriptors. Set only in root [DefaultServiceProvider].
  late final List<ServiceDescriptor>? _serviceDescriptors;

  /// Reference to the root service provider. Set only in scoped [DefaultServiceProvider].
  late final DefaultServiceProvider? _rootProvider;

  /// Creates a [DefaultServiceProvider] which represents a root service scope.
  DefaultServiceProvider(List<ServiceDescriptor> services) {
    int id = 0;
    _rootProvider = null;
    _serviceDescriptors = services;

    final dependencyPath = <String>[];
    for (final descriptor in services) {
      if (descriptor.lifetime == ServiceLifetime.singleton) {
        if (descriptor.instance != null) {
          _services.add(_ServiceEntry(
              id, descriptor.type, false, (sp) => descriptor.instance!));
        } else {
          final entryId = id;
          final identifier = '${descriptor.type} (#$entryId)';
          _services.add(_ServiceEntry(entryId, descriptor.type, false, (sp) {
            var instance = _ownedInstances[entryId];
            if (instance == null) {
              if (dependencyPath.contains(identifier)) {
                dependencyPath.add(identifier);
                throw CyclicDependencyError(
                    descriptor.type, List.unmodifiable(dependencyPath));
              }

              dependencyPath.add(identifier);
              try {
                instance = descriptor.factory!(sp);
              } finally {
                dependencyPath.removeLast();
              }

              _ownedInstances[entryId] = instance;
            }
            return instance;
          }));
        }
      } else if (descriptor.lifetime == ServiceLifetime.transient) {
        // We don't track transient services, pass the factory as-is.
        _services
            .add(_ServiceEntry(id, descriptor.type, true, descriptor.factory!));
      }

      id += 1;
    }

    // In the root service provider, id is used just for storing/retrieving singleton service instances.
    // ServiceProvider and ServiceScopeFactory registered below are not owned by the service provider
    // anyway. Thus the value of the id is irrelavent.
    _services.add(_ServiceEntry(id++, ServiceProvider, false, (sp) => this));
    _services
        .add(_ServiceEntry(id++, ServiceScopeFactory, false, (sp) => this));
  }

  /// Creates a scoped [DefaultServiceProvider].
  DefaultServiceProvider._scoped(DefaultServiceProvider rootProvider) {
    _rootProvider = rootProvider;
    _serviceDescriptors = null;

    int id = 0;
    final dependencyPath = <String>[];
    for (final descriptor in rootProvider._serviceDescriptors!) {
      if (descriptor.lifetime == ServiceLifetime.singleton ||
          descriptor.lifetime == ServiceLifetime.transient) {
        // Singleton and transient services are handled by the root provider.
        // We just need to get the accessor in the root provider by using the index of the ServiceDescriptor. 
        _services.add(_ServiceEntry(
            id,
            descriptor.type,
            descriptor.lifetime == ServiceLifetime.transient,
            rootProvider._services.where((s) => s.id == id).first.accessor));
      } else {
        assert(descriptor.lifetime == ServiceLifetime.scoped &&
            descriptor.factory != null);

        // Create and cache scoped services when requested,
        // these are disposed along with current ServiceProviderImpl instance.
        final entryId = id;
        final identifier = '${descriptor.type} (#$entryId)';
        _services.add(_ServiceEntry(entryId, descriptor.type, false, (sp) {
          var instance = _ownedInstances[entryId];
          if (instance == null) {
            if (dependencyPath.contains(identifier)) {
              dependencyPath.add(identifier);
              throw CyclicDependencyError(
                  descriptor.type, List.unmodifiable(dependencyPath));
            }

            dependencyPath.add(identifier);
            try {
              instance = descriptor.factory!(sp);
            } finally {
              dependencyPath.removeLast();
            }

            _ownedInstances[entryId] = instance;
          }
          return instance;
        }));
      }

      id += 1;
    }

    // Make sure ServiceProvider is resolved to the scoped one.
    _services.add(_ServiceEntry(id++, ServiceProvider, false, (sp) => this));
    _services.add(_ServiceEntry(
        id, ServiceScopeFactory, false, rootProvider._services.last.accessor));
  }

  /// Resolve a single service instance of the specified type.
  /// If multiple registrations are found, the one registered last is returned.
  /// Services registered as scoped are not returned by this method if current
  /// ServiceProvider is the root provider.
  /// If no registration found for the type, null is returned.
  Object? _resolveSingle(Type type) {
    var result = _resolutionCacheSingle[type];
    if (result == null) {
      for (var i = _services.length - 1; i >= 0; i--) {
        if (_services[i].type == type) {
          result = _services[i].accessor(this);
          if (!_services[i].transient) {
            _resolutionCacheSingle[type] = result;
          }
          break;
        }
      }
    }
    return result;
  }

  /// Resolve all single service instances of the specified type.
  /// Services registered as scoped are not returned by this method if current
  /// ServiceProvider is the root provider.
  /// If no registration found for the type, null is returned.
  (List<Object>? result, bool canCache) _resolveAll(Type type) {
    var result = _resolutionCacheList[type];
    bool canCache = true;
    if (result == null) {
      for (final service in _services) {
        if (service.type == type) {
          result ??= [];
          result.add(service.accessor(this));

          // Transient services need to be created each time when _resolveAll is called.
          // Thus we cannot cache the result if any of the service is registered an transient.
          if (service.transient) {
            canCache = false;
          }
        }
      }

      if (result != null) {
        // Seal the list to avoid being modified by the caller.
        result = List.unmodifiable(result);

        // Cache the result if applicable.
        if (canCache) {
          _resolutionCacheList[type] = result;
        }
      }
    }
    return (result, canCache);
  }

  @override
  ServiceScope createScope() =>
      DefaultServiceProvider._scoped(_rootProvider ?? this);

  @override
  void dispose() {
    for (final item in _ownedInstances.values) {
      if (item is Disposable) {
        item.dispose();
      }
    }

    _ownedInstances.clear();
    _resolutionCacheSingle.clear();
    _resolutionCacheList.clear();
    _resolutionCacheListTyped.clear();
    _services.clear();
  }

  @override
  T getRequiredService<T>() => getRequiredServiceOfType(T) as T;

  @override
  T? getService<T>() => getServiceOfType(T) as T?;

  @override
  List<T>? getServices<T>() {
    var result = _resolutionCacheListTyped[T] as List<T>?;
    if (result == null) {
      final (services, canCache) = _resolveAll(T);
      result = services?.cast<T>();
      if (result != null && canCache) {
        _resolutionCacheListTyped[T] = result;
      }
    }
    return result;
  }

  @override
  List<T> getRequiredServices<T>() {
    var result = _resolutionCacheListTyped[T] as List<T>?;
    if (result == null) {
      final (services, canCache) = _resolveAll(T);
      result = services?.cast<T>();
      if (result == null) {
        throw UnresolvableServiceError(T);
      } else if (canCache) {
        _resolutionCacheListTyped[T] = result;
      }
    }
    return result;
  }

  @override
  ServiceProvider get serviceProvider => this;

  @override
  Object getRequiredServiceOfType(Type type) {
    final service = _resolveSingle(type);
    if (service == null) {
      throw UnresolvableServiceError(type);
    }
    return service;
  }

  @override
  List<Object> getRequiredServicesOfType(Type type) {
    final (services, _) = _resolveAll(type);
    if (services == null) {
      throw UnresolvableServiceError(type);
    }
    return services;
  }

  @override
  Object? getServiceOfType(Type type) => _resolveSingle(type);

  @override
  List<Object>? getServicesOfType(Type type) {
    final (services, _) = _resolveAll(type);
    return services;
  }
}
