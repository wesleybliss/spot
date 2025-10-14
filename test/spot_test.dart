import 'package:spot/spot.dart';
import 'package:test/test.dart';

// Test interfaces and implementations
abstract class ITestService {
  String getMessage();
}

class TestService implements ITestService {
  @override
  String getMessage() => 'Hello from TestService';
}

class AnotherTestService implements ITestService {
  @override
  String getMessage() => 'Hello from AnotherTestService';
}

abstract class IDependentService {
  String getServiceMessage();
}

class DependentService implements IDependentService {
  final ITestService testService;

  DependentService(this.testService);

  @override
  String getServiceMessage() => 'Dependent: ${testService.getMessage()}';
}

class DisposableService implements SpotDisposable {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
  }
}

abstract class IAsyncService {
  Future<String> getData();
}

class AsyncService implements IAsyncService {
  bool initialized = false;

  AsyncService._();

  static Future<AsyncService> create() async {
    final service = AsyncService._();
    await Future.delayed(Duration(milliseconds: 10));
    service.initialized = true;
    return service;
  }

  @override
  Future<String> getData() async => 'Async data';
}

class CircularA {
  CircularA(CircularB b);
}

class CircularB {
  CircularB(CircularA a);
}

void main() {
  // Cleanup after each test
  tearDown(() {
    Spot.disposeAll();
  });

  group('Factory Registration', () {
    test('should create new instance on each resolution', () {
      Spot.registerFactory<ITestService, TestService>((get) => TestService());

      final instance1 = spot<ITestService>();
      final instance2 = spot<ITestService>();

      expect(instance1, isNotNull);
      expect(instance2, isNotNull);
      expect(identical(instance1, instance2), isFalse);
      expect(instance1.getMessage(), equals('Hello from TestService'));
    });

    test('should support named factory instances', () {
      Spot.registerFactory<ITestService, TestService>(
        (get) => TestService(),
        name: 'default',
      );
      Spot.registerFactory<ITestService, AnotherTestService>(
        (get) => AnotherTestService(),
        name: 'another',
      );

      final defaultService = spot<ITestService>(name: 'default');
      final anotherService = spot<ITestService>(name: 'another');

      expect(defaultService.getMessage(), equals('Hello from TestService'));
      expect(
        anotherService.getMessage(),
        equals('Hello from AnotherTestService'),
      );
    });
  });

  group('Singleton Registration', () {
    test('should return same instance on each resolution', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      final instance1 = spot<ITestService>();
      final instance2 = spot<ITestService>();

      expect(instance1, isNotNull);
      expect(identical(instance1, instance2), isTrue);
    });

    test('should support named singleton instances', () {
      Spot.registerSingle<ITestService, TestService>(
        (get) => TestService(),
        name: 'singleton1',
      );
      Spot.registerSingle<ITestService, AnotherTestService>(
        (get) => AnotherTestService(),
        name: 'singleton2',
      );

      final service1 = spot<ITestService>(name: 'singleton1');
      final service2 = spot<ITestService>(name: 'singleton2');
      final service1Again = spot<ITestService>(name: 'singleton1');

      expect(service1.getMessage(), equals('Hello from TestService'));
      expect(service2.getMessage(), equals('Hello from AnotherTestService'));
      expect(identical(service1, service1Again), isTrue);
    });

    test('should initialize singleton lazily', () {
      var initCount = 0;
      Spot.registerSingle<ITestService, TestService>((get) {
        initCount++;
        return TestService();
      });

      expect(initCount, equals(0));

      spot<ITestService>();
      expect(initCount, equals(1));

      spot<ITestService>();
      expect(initCount, equals(1)); // Still 1, not initialized again
    });
  });

  group('Async Singleton Registration', () {
    test('should resolve async singleton correctly', () async {
      Spot.registerAsync<IAsyncService, AsyncService>(
        (get) async => await AsyncService.create(),
      );

      final service = await spotAsync<IAsyncService>();

      expect(service, isNotNull);
      expect((service as AsyncService).initialized, isTrue);
      expect(await service.getData(), equals('Async data'));
    });

    test('should return same instance for async singleton', () async {
      Spot.registerAsync<IAsyncService, AsyncService>(
        (get) async => await AsyncService.create(),
      );

      final instance1 = await spotAsync<IAsyncService>();
      final instance2 = await spotAsync<IAsyncService>();

      expect(identical(instance1, instance2), isTrue);
    });

    test('should throw error when resolving async singleton synchronously', () {
      Spot.registerAsync<IAsyncService, AsyncService>(
        (get) async => await AsyncService.create(),
      );

      expect(() => spot<IAsyncService>(), throwsA(isA<SpotException>()));
    });
  });

  group('Dependency Injection', () {
    test('should inject dependencies into constructors', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());
      Spot.registerSingle<IDependentService, DependentService>(
        (get) => DependentService(get<ITestService>()),
      );

      final service = spot<IDependentService>();

      expect(
        service.getServiceMessage(),
        equals('Dependent: Hello from TestService'),
      );
    });

    test('should resolve nested dependencies', () {
      Spot.init((factory, single) {
        single<ITestService, TestService>((get) => TestService());
        single<IDependentService, DependentService>(
          (get) => DependentService(get<ITestService>()),
        );
      });

      final service = spot<IDependentService>();
      expect(service, isNotNull);
      expect(service.getServiceMessage(), contains('Hello from TestService'));
    });
  });

  group('Circular Dependency Detection', () {
    test('should detect circular dependencies', () {
      Spot.registerSingle<CircularA, CircularA>(
        (get) => CircularA(get<CircularB>()),
      );
      Spot.registerSingle<CircularB, CircularB>(
        (get) => CircularB(get<CircularA>()),
      );

      expect(
        () => spot<CircularA>(),
        throwsA(
          predicate(
            (e) =>
                e is SpotException && e.message.contains('Circular dependency'),
          ),
        ),
      );
    });
  });

  group('Error Handling', () {
    test('should throw exception for unregistered type', () {
      expect(
        () => spot<ITestService>(),
        throwsA(
          predicate(
            (e) => e is SpotException && e.message.contains('not registered'),
          ),
        ),
      );
    });

    test('should throw exception for unregistered named instance', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      expect(
        () => spot<ITestService>(name: 'nonexistent'),
        throwsA(isA<SpotException>()),
      );
    });
  });

  group('Registry Utilities', () {
    test('isRegistered should return true for registered types', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      expect(Spot.isRegistered<ITestService>(), isTrue);
      expect(Spot.isRegistered<IDependentService>(), isFalse);
    });

    test('isRegistered should work with named instances', () {
      Spot.registerSingle<ITestService, TestService>(
        (get) => TestService(),
        name: 'named',
      );

      expect(Spot.isRegistered<ITestService>(name: 'named'), isTrue);
      expect(Spot.isRegistered<ITestService>(name: 'other'), isFalse);
      expect(Spot.isRegistered<ITestService>(), isFalse);
    });

    test('isEmpty should reflect registry state', () {
      expect(Spot.isEmpty, isTrue);

      Spot.registerSingle<ITestService, TestService>((get) => TestService());
      expect(Spot.isEmpty, isFalse);

      Spot.disposeAll();
      expect(Spot.isEmpty, isTrue);
    });
  });

  group('Disposal', () {
    test('should dispose specific service and allow re-registration', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      final instance1 = spot<ITestService>();
      Spot.dispose<ITestService>();

      expect(Spot.isRegistered<ITestService>(), isFalse);

      // Re-register after disposal
      Spot.registerSingle<ITestService, TestService>((get) => TestService());
      final instance2 = spot<ITestService>();

      expect(identical(instance1, instance2), isFalse);
    });

    test('should call dispose on SpotDisposable services', () {
      final disposableService = DisposableService();
      Spot.registerSingle<DisposableService, DisposableService>(
        (get) => disposableService,
      );

      spot<DisposableService>(); // Initialize
      expect(disposableService.isDisposed, isFalse);

      Spot.dispose<DisposableService>();
      expect(disposableService.isDisposed, isTrue);
    });

    test('should dispose all services', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());
      Spot.registerFactory<IDependentService, DependentService>(
        (get) => DependentService(get<ITestService>()),
      );

      spot<ITestService>();
      expect(Spot.isEmpty, isFalse);

      Spot.disposeAll();
      expect(Spot.isEmpty, isTrue);
    });
  });

  group('Scoped Containers', () {
    test('should create isolated scope', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      final scope = Spot.createScope();
      scope.registerSingle<ITestService, AnotherTestService>(
        (get) => AnotherTestService(),
      );

      final globalService = spot<ITestService>();
      final scopedService = scope.spot<ITestService>();

      expect(globalService.getMessage(), equals('Hello from TestService'));
      expect(
        scopedService.getMessage(),
        equals('Hello from AnotherTestService'),
      );
    });

    test('should fall back to parent scope', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      final scope = Spot.createScope();
      final service = scope.spot<ITestService>();

      expect(service.getMessage(), equals('Hello from TestService'));
    });

    test('should support nested scopes', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      final parentScope = Spot.createScope();
      final childScope = parentScope.createChild();
      childScope.registerSingle<ITestService, AnotherTestService>(
        (get) => AnotherTestService(),
      );

      final globalService = spot<ITestService>();
      final parentService = parentScope.spot<ITestService>();
      final childService = childScope.spot<ITestService>();

      expect(globalService.getMessage(), equals('Hello from TestService'));
      expect(parentService.getMessage(), equals('Hello from TestService'));
      expect(
        childService.getMessage(),
        equals('Hello from AnotherTestService'),
      );
    });

    test('should dispose scope independently', () {
      final scope = Spot.createScope();
      scope.registerSingle<ITestService, TestService>((get) => TestService());

      scope.spot<ITestService>();
      expect(scope.isRegistered<ITestService>(), isTrue);

      scope.dispose();
      expect(scope.isRegistered<ITestService>(), isFalse);
    });

    test('should not affect global registry when disposing scope', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      final scope = Spot.createScope();
      scope.registerSingle<IDependentService, DependentService>(
        (get) => DependentService(get<ITestService>()),
      );

      scope.dispose();

      expect(Spot.isRegistered<ITestService>(), isTrue);
      expect(scope.isRegistered<IDependentService>(), isFalse);
    });
  });

  group('SpotKey', () {
    test('should differentiate unnamed and named instances', () {
      final unnamedKey = SpotKey<ITestService>(ITestService);
      final namedKey = SpotKey<ITestService>(ITestService, 'named');

      expect(unnamedKey == namedKey, isFalse);
      expect(unnamedKey.hashCode == namedKey.hashCode, isFalse);
    });

    test('should have correct string representation', () {
      final unnamedKey = SpotKey<ITestService>(ITestService);
      final namedKey = SpotKey<ITestService>(ITestService, 'test');

      expect(unnamedKey.toString(), contains('ITestService'));
      expect(namedKey.toString(), contains('ITestService'));
      expect(namedKey.toString(), contains('test'));
    });

    test('should have proper equality', () {
      final key1 = SpotKey<ITestService>(ITestService, 'name');
      final key2 = SpotKey<ITestService>(ITestService, 'name');
      final key3 = SpotKey<ITestService>(ITestService, 'other');

      expect(key1 == key2, isTrue);
      expect(key1 == key3, isFalse);
      expect(key1.hashCode, equals(key2.hashCode));
    });
  });

  group('Init Helper', () {
    test('should register multiple services at once', () {
      Spot.init((factory, single) {
        single<ITestService, TestService>((get) => TestService());
        factory<IDependentService, DependentService>(
          (get) => DependentService(get<ITestService>()),
        );
      });

      expect(Spot.isRegistered<ITestService>(), isTrue);
      expect(Spot.isRegistered<IDependentService>(), isTrue);

      final testService = spot<ITestService>();
      final dependentService = spot<IDependentService>();

      expect(testService, isNotNull);
      expect(dependentService, isNotNull);
    });
  });

  group('Global Convenience Functions', () {
    test('spot function should resolve dependencies', () {
      Spot.registerSingle<ITestService, TestService>((get) => TestService());

      final service = spot<ITestService>();
      expect(service.getMessage(), equals('Hello from TestService'));
    });

    test('spotAsync function should resolve async dependencies', () async {
      Spot.registerAsync<IAsyncService, AsyncService>(
        (get) async => await AsyncService.create(),
      );

      final service = await spotAsync<IAsyncService>();
      expect(service, isNotNull);
    });
  });
}
