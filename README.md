# Spot

**Spot** is a lightweight dependency injection (DI) framework for Dart and Flutter applications. Technically implemented as a service locator pattern, Spot provides a minimal yet powerful API for managing dependencies with support for singletons, factories, async initialization, and scoped containers.

> Spot is currently in early development. The API may change in future releases.


## Features

- 🎯 **Simple API** - Register and resolve dependencies with minimal boilerplate
- 🏭 **Factory & Singleton Support** - Choose the right lifecycle for each dependency
- ⚡ **Async Initialization** - Handle services that require async setup
- 🔍 **Named Instances** - Register multiple implementations of the same type
- 🧪 **Scoped Containers** - Isolate dependencies for testing or feature modules
- ♻️ **Lifecycle Management** - Automatic cleanup via `SpotDisposable` interface
- 🔒 **Type Safety** - Full compile-time type checking with generics
- 🚫 **Circular Dependency Detection** - Clear error messages when things go wrong
- 📦 **Zero Dependencies** - No external runtime dependencies

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  spot_di: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic Usage

```dart
import 'package:spot_di/spot.dart';

// 1. Define your interfaces and implementations
abstract class ILogger {
  void log(String message);
}

class ConsoleLogger implements ILogger {
  @override
  void log(String message) => print('[LOG] $message');
}

// 2. Register dependencies
void main() {
  Spot.registerSingle<ILogger, ConsoleLogger>((get) => ConsoleLogger());
  
  // 3. Resolve and use
  final logger = spot<ILogger>();
  logger.log('Hello, Spot!');
}
```

### Registration Patterns

**Singleton** - One instance shared across the app:

```dart
Spot.registerSingle<ISettings, AppSettings>((get) => AppSettings());

final settings1 = spot<ISettings>();
final settings2 = spot<ISettings>();
print(identical(settings1, settings2)); // true
```

**Factory** - New instance on each resolution:

```dart
Spot.registerFactory<IRepository, UserRepository>(
  (get) => UserRepository(),
);

final repo1 = spot<IRepository>();
final repo2 = spot<IRepository>();
print(identical(repo1, repo2)); // false
```

**Async Singleton** - For services requiring async initialization:

```dart
Spot.registerAsync<Database, AppDatabase>((get) async {
  final db = AppDatabase();
  await db.initialize();
  return db;
});

// Must use spotAsync for async singletons
final db = await spotAsync<Database>();
```

### Dependency Injection

Services can depend on other services using the `get` parameter:

```dart
// Register dependencies in order
Spot.registerSingle<ILogger, ConsoleLogger>((get) => ConsoleLogger());

Spot.registerSingle<IApiClient, ApiClient>((get) {
  return ApiClient(
    logger: get<ILogger>(),  // Inject dependencies
  );
});

// Spot handles the dependency graph
final apiClient = spot<IApiClient>();
```

### Bulk Registration

Use the `init` helper for cleaner registration:

```dart
Spot.init((factory, single) {
  // Register singletons
  single<ILogger, ConsoleLogger>((get) => ConsoleLogger());
  single<ISettings, AppSettings>((get) => AppSettings());
  
  // Register factories
  factory<IRepository, UserRepository>(
    (get) => UserRepository(get<ILogger>()),
  );
});
```

### Named Instances

Register multiple implementations of the same type:

```dart
Spot.registerSingle<HttpClient, PublicHttpClient>(
  (get) => PublicHttpClient(),
  name: 'public',
);

Spot.registerSingle<HttpClient, AuthenticatedHttpClient>(
  (get) => AuthenticatedHttpClient(),
  name: 'authenticated',
);

// Resolve by name
final publicClient = spot<HttpClient>(name: 'public');
final authClient = spot<HttpClient>(name: 'authenticated');
```

### Lifecycle Management

Implement `SpotDisposable` for automatic cleanup:

```dart
class DatabaseService implements SpotDisposable {
  late Database _db;
  
  @override
  void dispose() {
    _db.close();
  }
}

Spot.registerSingle<DatabaseService, DatabaseService>(
  (get) => DatabaseService(),
);

// Cleanup specific service
Spot.dispose<DatabaseService>();  // Calls dispose() automatically

// Or cleanup everything on app shutdown
Spot.disposeAll();
```

### Scoped Containers

Create isolated dependency scopes for testing or feature modules:

```dart
// Global dependencies
Spot.registerSingle<ISettings, AppSettings>((get) => AppSettings());

// Create test scope
final testScope = Spot.createScope();
testScope.registerSingle<ISettings, MockSettings>(
  (get) => MockSettings(),
);

// Each scope has its own version
final prodSettings = spot<ISettings>();        // Gets AppSettings
final testSettings = testScope.spot<ISettings>();  // Gets MockSettings

// Cleanup test scope (doesn't affect global)
testScope.dispose();
```

### Nested Scopes

Scopes can inherit from parent scopes:

```dart
final parentScope = Spot.createScope();
final childScope = parentScope.createChild();

// Child falls back to parent for missing dependencies
parentScope.registerSingle<ILogger, ConsoleLogger>(
  (get) => ConsoleLogger(),
);

final logger = childScope.spot<ILogger>();  // Gets from parent
```

## Advanced Usage

### Checking Registration

```dart
if (Spot.isRegistered<ILogger>()) {
  print('Logger is registered');
}

if (Spot.isRegistered<HttpClient>(name: 'public')) {
  print('Public HTTP client is registered');
}
```

### Debugging

```dart
// Enable verbose logging
Spot.logging = true;

// Print all registered types
Spot.printRegistry();
// Output:
// === Spot Registry (3 types) ===
//   ILogger -> ConsoleLogger [singleton] (initialized)
//   ISettings -> AppSettings [singleton]
//   IRepository -> UserRepository [factory]
// ==================================================
```

### Error Handling

Spot provides clear error messages:

```dart
// Unregistered type
try {
  final service = spot<UnregisteredService>();
} catch (e) {
  // SpotException: Type UnregisteredService is not registered in Spot container.
  // Registered types: ILogger, ISettings
}

// Circular dependency
Spot.registerSingle<ServiceA, ServiceA>(
  (get) => ServiceA(get<ServiceB>()),
);
Spot.registerSingle<ServiceB, ServiceB>(
  (get) => ServiceB(get<ServiceA>()),
);

try {
  spot<ServiceA>();
} catch (e) {
  // SpotException: Circular dependency detected: ServiceA -> ServiceB -> ServiceA
}
```

## Testing

Spot makes testing easy with scoped containers:

```dart
import 'package:test/test.dart';
import 'package:spot/spot.dart';

void main() {
  // Setup production dependencies once
  setUpAll(() {
    Spot.registerSingle<IApiClient, ApiClient>((get) => ApiClient());
  });
  
  // Clean up after each test
  tearDown(() {
    Spot.disposeAll();
  });
  
  test('with mocked dependencies', () {
    // Create isolated test scope
    final testScope = Spot.createScope();
    testScope.registerSingle<IApiClient, MockApiClient>(
      (get) => MockApiClient(),
    );
    
    // Test with mock
    final apiClient = testScope.spot<IApiClient>();
    expect(apiClient, isA<MockApiClient>());
    
    // Cleanup
    testScope.dispose();
  });
}
```

## Service Locator Pattern

Spot is technically a **service locator** pattern rather than pure dependency injection. This means:

**What it is:**
- A centralized registry where services can be registered and retrieved
- Dependencies are resolved at runtime using `spot<T>()`
- Simple, straightforward, and easy to understand

**What it's not:**
- Not constructor injection (dependencies aren't automatically injected)
- Not compile-time dependency resolution
- Not a full-featured DI container like Angular's injector

**Why this is fine for Dart/Flutter:**
- Dart doesn't have built-in reflection for constructor injection
- Service locator pattern is lightweight and performant
- Most Flutter apps use similar patterns (GetIt, Provider, etc.)
- You get the benefits of DI (loose coupling, testability) with minimal overhead

## API Reference

### Registration Methods

| Method | Description |
|--------|-------------|
| `registerSingle<T, R>(locator)` | Register a singleton (lazy initialization) |
| `registerFactory<T, R>(locator)` | Register a factory (new instance each time) |
| `registerAsync<T, R>(locator)` | Register async singleton |
| `init(initializer)` | Bulk registration helper |

### Resolution Methods

| Method | Description |
|--------|-------------|
| `spot<T>({name})` | Resolve dependency synchronously |
| `spotAsync<T>({name})` | Resolve async singleton |
| `Spot.spot<T>({name})` | Static method (same as global `spot`) |
| `Spot.spotAsync<T>({name})` | Static method (same as global `spotAsync`) |

### Lifecycle Methods

| Method | Description |
|--------|-------------|
| `dispose<T>({name})` | Dispose specific service |
| `disposeAll()` | Dispose all services |

### Utility Methods

| Method | Description |
|--------|-------------|
| `isRegistered<T>({name})` | Check if type is registered |
| `printRegistry()` | Print all registered types (debugging) |
| `createScope()` | Create scoped container |

### Container Methods

| Method | Description |
|--------|-------------|
| `container.registerSingle<T, R>(locator)` | Register in scope |
| `container.registerFactory<T, R>(locator)` | Register factory in scope |
| `container.registerAsync<T, R>(locator)` | Register async in scope |
| `container.spot<T>({name})` | Resolve from scope |
| `container.spotAsync<T>({name})` | Resolve async from scope |
| `container.createChild()` | Create nested scope |
| `container.dispose()` | Dispose scope |

## Examples

See the [example](example/) directory for complete examples:

- [spot_example.dart](example/spot_example.dart) - Basic usage patterns
- [spot_flutter_example.dart](example/spot_flutter_example.dart) - Flutter integration

## Development

### Git Hooks

This repository includes Git hooks to ensure code quality:

- **pre-push**: Runs `dart analyze` and `dart test` before pushing any branch

To install the hooks after cloning:

```bash
./hooks/install.sh
```

The hooks will automatically prevent pushes if analysis or tests fail.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

Before submitting a PR, make sure to:
1. Install the Git hooks: `./hooks/install.sh`
2. Run `dart analyze` to check for issues
3. Run `dart test` to ensure all tests pass
4. Run `dart format .` to format your code

## License

This project is licensed under the MIT License - see the LICENSE file for details.
