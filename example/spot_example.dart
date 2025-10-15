import 'package:spot_di/spot_di.dart';

import 'example_class.dart';
import 'example_singleton_class.dart';

abstract class SpotModule {
  static void registerDependencies() {
    Spot.init((factory, single) {
      // Example singleton
      single<ISpotExampleSingletonClass, SpotExampleSingletonClass>((get) => SpotExampleSingletonClass());

      // Example class instance
      factory<ISpotExampleClass, SpotExampleClass>((get) => SpotExampleClass());
    });
  }
}

abstract class TestSpotModule extends SpotModule {
  static void registerDependencies() {
    Spot.init((factory, single) {
      // You can override dependencies here for testing
    });
  }
}

void main() {
  SpotModule.registerDependencies();

  // Example usage
  var singleton1 = spot<ISpotExampleSingletonClass>();
  var singleton2 = spot<ISpotExampleSingletonClass>();
  print(singleton1 == singleton2); // true, same instance

  var instance1 = spot<ISpotExampleClass>();
  var instance2 = spot<ISpotExampleClass>();
  
  print(instance1 == instance2); // false, different instances
}
