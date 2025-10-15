
import 'package:spot_di/spot_di.dart';

// Since this is a Dart library, we will comment out the Flutter-specific code.
// You can uncomment this code when you use it in a Flutter project.
// import 'package:flutter/material.dart';

void main() {
  // Initialize Spot for dependency injection.
  // This is where you would register your services.
  Spot.init((factory, single) {
    // Register a singleton service that will be created only once.
    single<IMyService, MyService>((get) => MyService());
  });

  // runApp(const MyApp());
}

// A simple service that we want to inject.
abstract class IMyService {
  String get message;
}

class MyService implements IMyService {
  @override
  String get message => 'Hello from MyService!';
}

/*
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spot Flutter Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Resolve the service from the Spot container.
    final myService = spot<IMyService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spot Flutter Example'),
      ),
      body: Center(
        child: Text(myService.message),
      ),
    );
  }
}
*/
