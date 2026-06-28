import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/light_reading.dart';
import 'package:morse/features/receive/domain/receive_state.dart';
import 'package:morse/features/receive/presentation/receive_controller.dart';
import 'package:morse/features/receive/services/light_source.dart';

/// Minimal SOS luminance train at unit=200, 20ms sampling, with leading and
/// trailing silence so the idle flush commits the final letter.
List<LightReading> _sosReadings() {
  const unit = 200;
  const sampleMs = 20;
  const bright = 235.0, dark = 15.0;
  final out = <LightReading>[];
  var t = 0;
  void hold(double lum, int durMs) {
    for (var e = 0; e < durMs; e += sampleMs) {
      out.add(LightReading(luminance: lum, timestampMs: t));
      t += sampleMs;
    }
  }

  hold(dark, 400); // leading ambient
  // '... --- ...'
  const letters = ['...', '---', '...'];
  for (var l = 0; l < letters.length; l++) {
    final syms = letters[l].split('');
    for (var s = 0; s < syms.length; s++) {
      hold(bright, syms[s] == '.' ? unit : unit * 3);
      if (s < syms.length - 1) hold(dark, unit); // symbol gap
    }
    if (l < letters.length - 1) hold(dark, unit * 3); // letter gap
  }
  hold(dark, unit * 8); // trailing silence (> idle timeout)
  return out;
}

void main() {
  test('decodes SOS from a fake source, notifies, and tracks lifecycle', () async {
    final controller = ReceiveController(source: FakeLightSource(_sosReadings()));
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.startReceiving();
    await controller.stopReceiving();

    expect(notified, isTrue);
    expect(controller.state.decodedText, 'SOS');
    expect(controller.state.status, ReceiveStatus.stopped);
    expect(controller.state.quality.decodeConfidencePct, greaterThan(0));

    final before = ReceiveController.activeControllerCount;
    controller.dispose();
    expect(ReceiveController.activeControllerCount, before - 1);
  });

  test('stopReceiving notifies listeners and returns to a non-receiving state',
      () async {
    final controller = ReceiveController(source: FakeLightSource(_sosReadings()));
    await controller.startReceiving();

    // Reset the notification flag, then stop and require a rebuild signal.
    var notifiedAfterStart = false;
    controller.addListener(() => notifiedAfterStart = true);
    await controller.stopReceiving();

    expect(notifiedAfterStart, isTrue,
        reason: 'Stop must notify so the UI leaves the receiving state');
    expect(controller.state.isReceiving, isFalse);
    expect(controller.state.status, ReceiveStatus.stopped);

    // Start must be usable again afterwards.
    await controller.startReceiving();
    expect(controller.state.status, anyOf(ReceiveStatus.receiving, ReceiveStatus.stopped));
    await controller.stopReceiving();
    controller.dispose();
  });

  test('maps permission denied to an error state', () async {
    final controller = ReceiveController(
      source: FakeLightSource(const [], failWith: LightSourceError.permissionDenied),
    );

    await controller.startReceiving();

    expect(controller.state.status, ReceiveStatus.error);
    expect(controller.state.errorMessage, contains('permission'));
    controller.dispose();
  });

  test('maps camera unavailable to an error state', () async {
    final controller = ReceiveController(
      source: FakeLightSource(const [], failWith: LightSourceError.unavailable),
    );

    await controller.startReceiving();

    expect(controller.state.status, ReceiveStatus.error);
    expect(controller.state.errorMessage, contains('unavailable'));
    controller.dispose();
  });

  test('does not throw or notify after dispose', () async {
    final controller = ReceiveController(source: FakeLightSource(_sosReadings()));
    controller.dispose();
    // Calling lifecycle methods post-dispose must be safe no-ops.
    await controller.startReceiving();
    await controller.stopReceiving();
    expect(controller.state.status, ReceiveStatus.idle);
  });
}
