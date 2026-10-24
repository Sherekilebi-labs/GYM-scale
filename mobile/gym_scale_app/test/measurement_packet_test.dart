import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_scale_app/measurement_packet.dart';

void main() {
  test('decodes little-endian measurement packet', () {
    final ByteData data = ByteData(16);
    data.setUint8(0, 1);
    data.setUint8(1, 0x01);
    data.setUint16(2, 42, Endian.little);
    data.setUint32(4, 123456, Endian.little);
    data.setFloat32(8, 250.5, Endian.little);
    data.setInt32(12, -1000, Endian.little);

    final MeasurementPacket packet = MeasurementPacket.decode(data.buffer.asUint8List());

    expect(packet.version, 1);
    expect(packet.flags.ready, true);
    expect(packet.sequence, 42);
    expect(packet.uptimeMs, 123456);
    expect(packet.grossGrams, closeTo(250.5, 0.001));
    expect(packet.rawDelta, -1000);
    expect(packet.usable, true);
  });

  test('rejects packet with wrong size', () {
    expect(() => MeasurementPacket.decode(<int>[1, 2, 3]), throwsFormatException);
  });
}
