import 'constants.dart';
import 'measurement_packet.dart';

enum ScaleUnit { grams, pounds }

class ScaleDisplayState {
  ScaleDisplayState();

  double? _tareOffsetGrossGrams;
  double _liveNetGrams = 0;
  double _stableAnchorGrams = 0;
  double _frozenGrams = 0;
  DateTime? _stableSince;
  bool _hasAnchor = false;
  bool _frozen = false;
  int _stableEvent = 0;

  ScaleUnit unit = ScaleUnit.grams;
  MeasurementPacket? latestPacket;

  double get liveNetGrams => _liveNetGrams;
  double get displayGrams => _frozen ? _frozenGrams : _liveNetGrams;
  bool get frozen => _frozen;
  int get stableEvent => _stableEvent;

  void applyPacket(MeasurementPacket packet, DateTime now) {
    latestPacket = packet;
    if (!packet.usable) {
      _hasAnchor = false;
      _frozen = false;
      _stableSince = null;
      return;
    }

    _tareOffsetGrossGrams ??= packet.grossGrams;
    _liveNetGrams = packet.grossGrams - _tareOffsetGrossGrams!;
    if (_liveNetGrams.abs() < 0.4) {
      _liveNetGrams = 0;
    }
    _updateStability(now);
  }

  void tare() {
    final MeasurementPacket? packet = latestPacket;
    if (packet == null || !packet.usable) {
      return;
    }
    _tareOffsetGrossGrams = packet.grossGrams;
    _liveNetGrams = 0;
    _hasAnchor = false;
    _frozen = false;
    _stableSince = null;
  }

  void toggleUnit() {
    unit = unit == ScaleUnit.grams ? ScaleUnit.pounds : ScaleUnit.grams;
  }

  void _updateStability(DateTime now) {
    if (_frozen) {
      if ((_liveNetGrams - _frozenGrams).abs() > freezeReleaseDeltaGrams) {
        _frozen = false;
        _hasAnchor = false;
        _stableSince = null;
      }
      return;
    }

    if (!_hasAnchor) {
      _hasAnchor = true;
      _stableAnchorGrams = _liveNetGrams;
      _stableSince = now;
      return;
    }

    if ((_liveNetGrams - _stableAnchorGrams).abs() > stableBandGrams) {
      _stableAnchorGrams = _liveNetGrams;
      _stableSince = now;
      return;
    }

    final DateTime? since = _stableSince;
    if (since != null && now.difference(since) >= stableHold) {
      _frozen = true;
      _frozenGrams = _liveNetGrams;
      _stableAnchorGrams = _liveNetGrams;
      _stableEvent += 1;
    }
  }

  String get displayText {
    final double value = unit == ScaleUnit.pounds ? displayGrams * gramsToPounds : displayGrams;
    if (unit == ScaleUnit.pounds) {
      return value.abs() < 10 ? value.toStringAsFixed(3) : value.toStringAsFixed(2);
    }
    return value.abs() < 1000 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
  }

  String get unitLabel => unit == ScaleUnit.pounds ? 'lb' : 'g';
}
