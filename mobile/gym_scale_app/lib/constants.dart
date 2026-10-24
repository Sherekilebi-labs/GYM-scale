import 'dart:ui';

const String scaleDeviceName = 'GYM-Scale';
const String scaleServiceUuid = '7e57c000-6f7a-4b64-9c98-7fdc2d2f7c01';
const String measurementCharacteristicUuid = '7e57c001-6f7a-4b64-9c98-7fdc2d2f7c01';

const double gramsToPounds = 0.00220462262;
const double stableBandGrams = 1.4;
const double freezeReleaseDeltaGrams = 2.0;
const Duration stableHold = Duration(milliseconds: 1800);

const List<Color> foodPalette = <Color>[
  Color(0xff2f80ed),
  Color(0xff219653),
  Color(0xfff2994a),
  Color(0xffeb5757),
  Color(0xff9b51e0),
  Color(0xff00a3a3),
  Color(0xff6f4e37),
  Color(0xff455a64),
];
