import 'dart:async';
import 'dart:io';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'constants.dart';
import 'measurement_packet.dart';

enum BleScaleStatus { permissionsNeeded, scanning, connecting, connected, disconnected, error }

class BleScaleSnapshot {
  const BleScaleSnapshot({
    required this.status,
    this.packet,
    this.message,
  });

  final BleScaleStatus status;
  final MeasurementPacket? packet;
  final String? message;
}

class BleScaleClient {
  BleScaleClient({FlutterReactiveBle? ble}) : _ble = ble ?? FlutterReactiveBle();

  final FlutterReactiveBle _ble;
  final StreamController<BleScaleSnapshot> _snapshots = StreamController<BleScaleSnapshot>.broadcast();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _measurementSubscription;
  QualifiedCharacteristic? _measurementCharacteristic;

  Stream<BleScaleSnapshot> get snapshots => _snapshots.stream;

  Future<void> start() async {
    if (!await _requestPermissions()) {
      _snapshots.add(const BleScaleSnapshot(status: BleScaleStatus.permissionsNeeded, message: 'Bluetooth permission needed'));
      return;
    }
    await _stopSubscriptions();
    _snapshots.add(const BleScaleSnapshot(status: BleScaleStatus.scanning));
    _scanSubscription = _ble.scanForDevices(
      withServices: <Uuid>[Uuid.parse(scaleServiceUuid)],
      scanMode: ScanMode.lowLatency,
    ).listen((DiscoveredDevice device) {
      if (device.name == scaleDeviceName || device.serviceUuids.contains(Uuid.parse(scaleServiceUuid))) {
        _connect(device.id);
      }
    }, onError: (Object error) {
      _snapshots.add(BleScaleSnapshot(status: BleScaleStatus.error, message: error.toString()));
    });
  }

  Future<void> stop() async {
    await _stopSubscriptions();
    _snapshots.add(const BleScaleSnapshot(status: BleScaleStatus.disconnected));
  }

  Future<bool> _requestPermissions() async {
    final List<Permission> permissions = <Permission>[];
    if (Platform.isAndroid) {
      permissions.addAll(<Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ]);
    } else if (Platform.isIOS) {
      permissions.add(Permission.bluetooth);
    }
    if (permissions.isEmpty) {
      return true;
    }
    final Map<Permission, PermissionStatus> result = await permissions.request();
    return result.values.every((PermissionStatus status) => status.isGranted || status.isLimited);
  }

  Future<void> _connect(String deviceId) async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _snapshots.add(const BleScaleSnapshot(status: BleScaleStatus.connecting));
    _measurementCharacteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(scaleServiceUuid),
      characteristicId: Uuid.parse(measurementCharacteristicUuid),
      deviceId: deviceId,
    );
    _connectionSubscription = _ble.connectToDevice(
      id: deviceId,
      servicesWithCharacteristicsToDiscover: <Uuid, List<Uuid>>{
        Uuid.parse(scaleServiceUuid): <Uuid>[Uuid.parse(measurementCharacteristicUuid)],
      },
      connectionTimeout: const Duration(seconds: 12),
    ).listen((ConnectionStateUpdate update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        _snapshots.add(const BleScaleSnapshot(status: BleScaleStatus.connected));
        _subscribeMeasurements();
      } else if (update.connectionState == DeviceConnectionState.disconnected) {
        _snapshots.add(const BleScaleSnapshot(status: BleScaleStatus.disconnected));
      }
    }, onError: (Object error) {
      _snapshots.add(BleScaleSnapshot(status: BleScaleStatus.error, message: error.toString()));
    });
  }

  void _subscribeMeasurements() {
    final QualifiedCharacteristic? characteristic = _measurementCharacteristic;
    if (characteristic == null) {
      return;
    }
    _measurementSubscription?.cancel();
    _measurementSubscription = _ble.subscribeToCharacteristic(characteristic).listen((List<int> bytes) {
      try {
        _snapshots.add(BleScaleSnapshot(status: BleScaleStatus.connected, packet: MeasurementPacket.decode(bytes)));
      } catch (error) {
        _snapshots.add(BleScaleSnapshot(status: BleScaleStatus.error, message: error.toString()));
      }
    }, onError: (Object error) {
      _snapshots.add(BleScaleSnapshot(status: BleScaleStatus.error, message: error.toString()));
    });
  }

  Future<void> _stopSubscriptions() async {
    await _measurementSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _scanSubscription?.cancel();
    _measurementSubscription = null;
    _connectionSubscription = null;
    _scanSubscription = null;
  }

  Future<void> dispose() async {
    await _stopSubscriptions();
    await _snapshots.close();
  }
}
