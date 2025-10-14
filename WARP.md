# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

**Spot** is a lightweight dependency injection (DI) framework for Dart applications. It provides a minimal yet powerful service locator pattern with support for singletons, factories, async initialization, scoped containers, and lifecycle management.

## Development Commands

### Dependencies
```bash
# Install dependencies
dart pub get

# Update dependencies
dart pub upgrade
```

### Testing
```bash
# Run all tests
dart test

# Run a specific test file
dart test test/spot_test.dart

# Run tests with coverage
dart test --coverage=coverage

# Run tests in verbose mode
dart test --reporter=expanded
```

### Code Quality
```bash
# Analyze code for issues
dart analyze

# Format all code
dart format .

# Format specific files
dart format lib/ test/
```

### Running Examples
```bash
# Run the basic example
dart run example/spot_example.dart

# Run the Flutter example (commented out - requires Flutter project)
dart run example/spot_flutter_example.dart
```

## Architecture Overview

### Core Concepts

**Spot** implements a service locator pattern with the following key concepts:

1. **Service Registration**: Register dependencies as singletons, factories, or async singletons
2. **Service Resolution**: Resolve dependencies using `spot<T>()` or `spotAsync<T>()`
3. **Scoped Containers**: Create isolated dependency scopes for testing or feature modules
4. **Named Instances**: Register multiple implementations of the same type with name qualifiers
5. **Lifecycle Management**: Automatic cleanup via `SpotDisposable` interface

### Service Types

- **Factory** (`SpotType.factory`): Creates a new instance on each resolution
- **Singleton** (`SpotType.singleton`): Creates one instance lazily and caches it
- **Async Singleton** (`SpotType.asyncSingleton`): Creates one async instance with async initialization

### Key Components

#### `Spot` (lib/src/spot_base.dart)
The main static service locator class. Provides:
- `registerFactory<T, R>()` - Register factory services
- `registerSingle<T, R>()` - Register singleton services  
- `registerAsync<T, R>()` - Register async singleton services
- `spot<T>()` - Resolve service synchronously
- `spotAsync<T>()` - Resolve service asynchronously
- `init()` - Convenience method for bulk registration
- `dispose<T>()` - Dispose specific service
- `disposeAll()` - Dispose all services
- `createScope()` - Create scoped container
- `isRegistered<T>()` - Check if type is registered
- `printRegistry()` - Debug helper to print all registered types

#### `SpotService` (lib/src/spot_base.dart)
Internal representation of a registered service. Handles:
- Lazy initialization of singletons
- Thread-safe initialization (prevents re-entrant initialization)
- Circular dependency detection
- Async initialization for async singletons
- Disposal via `SpotDisposable` interface

#### `SpotKey` (lib/src/spot_key.dart)
Registry key that combines `Type` and optional `name` string. Enables:
- Multiple implementations of the same type (named instances)
- Proper equality and hashing for registry lookups
- Clear error messages showing `Type(name)` format

#### `SpotContainer` (lib/src/spot_container.dart)
Scoped DI container with parent-child hierarchy. Features:
- Local registry that shadows parent registrations
- Fallback to parent container for missing dependencies
- Independent disposal (doesn't affect parent or siblings)
- Supports nested scopes via `createChild()`

#### `SpotDisposable` (lib/src/disposable.dart)
Interface for services requiring cleanup. When disposed:
- `dispose()` method is called automatically
- Instance is removed from registry and cache
- Useful for closing connections, files, streams, etc.

#### `Logger` (lib/src/logger.dart)
Internal logging system with:
- Multiple log levels (verbose, debug, info, warning, error)
- Color-coded output (when supported)
- Global and per-logger configuration
- Tag-based context (e.g., `[Spot]`, `[SpotContainer]`)

### Resolution Flow

1. **Check singleton cache** - Fast O(1) lookup for previously resolved singletons
2. **Check registry** - Look up `SpotKey<T>(T, name)` in registry
3. **Detect circular dependencies** - Add key to resolution stack, check for cycles
4. **Locate instance** - Call `SpotService.locate()` or `locateAsync()`
   - For factories: Call locator function every time
   - For singletons: Call locator once, cache result
   - For async singletons: Await async locator, cache result
5. **Cache result** - Add singleton to cache for fast subsequent access
6. **Pop resolution stack** - Remove key from stack

### Scoped Container Hierarchy

```
Spot (global/static registry)
  ├─ Container A (test scope)
  │   └─ Container A1 (nested test scope)
  └─ Container B (feature scope)
      └─ Container B1 (sub-feature scope)
```

Resolution order: Current scope → Parent scope → Grandparent scope → ... → Global `Spot`

## File Structure

### Core Library Files
- `lib/spot.dart` - Package entry point, exports public API
- `lib/src/spot_base.dart` - Main `Spot` class with registration/resolution logic
- `lib/src/spot_container.dart` - `SpotContainer` for scoped DI
- `lib/src/spot_key.dart` - `SpotKey` for registry lookups (supports named instances)
- `lib/src/disposable.dart` - `SpotDisposable` interface for lifecycle management
- `lib/src/spot_exception.dart` - `SpotException` for DI errors
- `lib/src/logger.dart` - `Logger` for internal logging
- `lib/src/spot_base1.dart` - Legacy file with `Awesome` test class (to be removed)

### Examples
- `example/spot_example.dart` - Basic usage with `SpotModule` pattern
- `example/spot_flutter_example.dart` - Flutter integration example (commented out)
- `example/example_class.dart` - Simple factory example
- `example/example_singleton_class.dart` - Simple singleton example

### Tests
- `test/spot_test.dart` - Test suite (currently minimal, needs expansion)

## Important Patterns

### Registration Pattern (SpotModule)
The examples use a `SpotModule` pattern for organizing registrations:

```dart
abstract class SpotModule {
  static void registerDependencies() {
    Spot.init((factory, single) {
      single<ISettings, Settings>((get) => Settings());
      factory<IRepository, Repository>((get) => Repository(get<Database>()));
    });
  }
}
```

### Dependency Injection in Constructors
The `locator` function receives a `get` parameter for resolving dependencies:

```dart
single<IApiClient, ApiClient>((get) => ApiClient(
  dio: get<Dio>(),
  settings: get<ISettings>(),
));
```

### Named Instances
Use the `name` parameter to register multiple implementations:

```dart
Spot.registerSingle<HttpClient, PublicHttpClient>(
  (get) => PublicHttpClient(),
  name: 'public',
);

final client = spot<HttpClient>(name: 'public');
```

### Test Isolation with Scopes
Create isolated test scopes without affecting global state:

```dart
final testScope = Spot.createScope();
testScope.registerSingle<ISettings, MockSettings>((get) => MockSettings());

// Test uses mock
final settings = testScope.spot<ISettings>();

// Cleanup (doesn't affect global)
testScope.dispose();
```

### Async Initialization
Use `registerAsync` for services requiring async setup:

```dart
Spot.registerAsync<Database, AppDatabase>((get) async {
  final db = AppDatabase();
  await db.initialize();
  return db;
});

// Resolve with await
final db = await spotAsync<Database>();
```

## Debugging

### Enable Logging
```dart
Spot.logging = true;  // Enable verbose logging
```

### Print Registry Contents
```dart
Spot.printRegistry();  // Prints all registered types
```

### Check Registration Status
```dart
if (Spot.isRegistered<MyService>()) {
  // Service is registered
}
```

## Common Issues

### Circular Dependencies
If you see "Circular dependency detected", review your dependency graph. The error message shows the cycle:
```
Circular dependency detected: ServiceA -> ServiceB -> ServiceA
```

### Async Singleton Resolution
Always use `spotAsync<T>()` for async singletons, not `spot<T>()`:
```dart
// ❌ Wrong - throws error
final db = spot<Database>();

// ✅ Correct
final db = await spotAsync<Database>();
```

### Re-entrant Initialization
If you see "Re-entrant initialization detected", you likely have a circular dependency or multiple threads trying to initialize the same singleton.

## Development Notes

- **Dart SDK Version**: 3.8.1 or higher (specified in `pubspec.yaml`)
- **Lints**: Uses `package:lints` recommended rules
- **Testing**: Uses `package:test` for unit tests
- **No external dependencies**: Core library has zero runtime dependencies
