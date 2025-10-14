abstract class ISpotExampleClass {
  String exampleMethod();
}

class SpotExampleClass implements ISpotExampleClass {
  @override
  String exampleMethod() {
    return "This is an example method.";
  }
}
