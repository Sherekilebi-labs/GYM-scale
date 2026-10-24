import 'package:flutter_test/flutter_test.dart';
import 'package:gym_scale_app/measurement_packet.dart';
import 'package:gym_scale_app/scale_state.dart';

MeasurementPacket packet(double grams, {int flags = 0x01, int sequence = 1}) {
  return MeasurementPacket(
    version: 1,
    flags: MeasurementFlags(flags),
    sequence: sequence,
    uptimeMs: sequence * 200,
    grossGrams: grams,
    rawDelta: 100,
  );
}

void main() {
  test('tare makes current gross grams display as zero', () {
    final ScaleDisplayState state = ScaleDisplayState();
    final DateTime now = DateTime(2026);
    state.applyPacket(packet(100), now);
    state.applyPacket(packet(125, sequence: 2), now.add(const Duration(milliseconds: 200)));

    expect(state.displayGrams, closeTo(25, 0.001));

    state.tare();

    expect(state.displayGrams, closeTo(0, 0.001));
  });

  test('freezes after stable hold and releases above two grams', () {
    final ScaleDisplayState state = ScaleDisplayState();
    final DateTime start = DateTime(2026);
    state.applyPacket(packet(100), start);
    state.applyPacket(packet(100.6, sequence: 2), start.add(const Duration(milliseconds: 900)));
    state.applyPacket(packet(100.8, sequence: 3), start.add(const Duration(milliseconds: 1900)));

    expect(state.frozen, true);
    expect(state.stableEvent, 1);

    state.applyPacket(packet(103.1, sequence: 4), start.add(const Duration(milliseconds: 2100)));
    expect(state.frozen, false);
  });
}
