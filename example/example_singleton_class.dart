abstract class ISpotExampleSingletonClass {
  String exampleMethod();
}

class SpotExampleSingletonClass implements ISpotExampleSingletonClass {
  @override
  String exampleMethod() {
    return "This is an example method.";
  }
}
