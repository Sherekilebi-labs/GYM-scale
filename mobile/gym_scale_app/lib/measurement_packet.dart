import 'dart:typed_data';

class MeasurementFlags {
  const MeasurementFlags(this.value);

  final int value;

  bool get ready => value & 0x01 != 0;
  bool get saturated => value & 0x02 != 0;
  bool get overload => value & 0x04 != 0;
  bool get warmingUp => value & 0x08 != 0;
}

class MeasurementPacket {
  const MeasurementPacket({
    required this.version,
    required this.flags,
    required this.sequence,
    required this.uptimeMs,
    required this.grossGrams,
    required this.rawDelta,
  });

  final int version;
  final MeasurementFlags flags;
  final int sequence;
  final int uptimeMs;
  final double grossGrams;
  final int rawDelta;

  bool get usable => version == 1 && flags.ready && !flags.saturated && !flags.overload;

  static MeasurementPacket decode(List<int> bytes) {
    if (bytes.length != 16) {
      throw FormatException('Expected 16 measurement bytes, got ${bytes.length}');
    }

    final ByteData data = ByteData.sublistView(Uint8List.fromList(bytes));
    return MeasurementPacket(
      version: data.getUint8(0),
      flags: MeasurementFlags(data.getUint8(1)),
      sequence: data.getUint16(2, Endian.little),
      uptimeMs: data.getUint32(4, Endian.little),
      grossGrams: data.getFloat32(8, Endian.little),
      rawDelta: data.getInt32(12, Endian.little),
    );
  }
}
