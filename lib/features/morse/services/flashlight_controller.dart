abstract class FlashlightController {
  Future<bool> prepare();

  Future<void> turnOn();

  Future<void> turnOff();
}
