import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';

import 'flashlight_controller.dart';

class TorchFlashlightController implements FlashlightController {
  @override
  Future<bool> prepare() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      return false;
    }

    return TorchLight.isTorchAvailable();
  }

  @override
  Future<void> turnOn() async {
    await TorchLight.enableTorch();
  }

  @override
  Future<void> turnOff() async {
    await TorchLight.disableTorch();
  }
}
