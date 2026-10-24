import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_scale_app/main.dart';

void main() {
  testWidgets('renders seven segment display text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SevenSegmentText(text: '12.3'),
        ),
      ),
    );

    expect(find.byType(SevenSegmentText), findsOneWidget);
    expect(find.byType(SegmentDigit), findsNWidgets(3));
  });
}
