import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftly/widgets/app_widgets.dart';
import 'package:shiftly/widgets/shiftly_logo.dart';
import 'package:shiftly/core/theme/app_colors.dart';

void main() {
  testWidgets('ShiftlyLogo renders correctly with text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShiftlyLogo(size: 100, showText: true),
        ),
      ),
    );

    expect(find.text('SHIFTLY'), findsOneWidget);
    expect(find.text('Vardiyan. Takvimin. Ekibin.'), findsOneWidget);
  });

  testWidgets('AppButton displays label and responds to tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            text: 'Vardiya Oluştur',
            onPressed: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Vardiya Oluştur'), findsOneWidget);

    await tester.tap(find.text('Vardiya Oluştur'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('ShiftChip renders and reflects selection state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShiftChip(
            label: 'N • Gece',
            color: AppColors.shiftNight,
            isSelected: true,
          ),
        ),
      ),
    );

    expect(find.text('N • Gece'), findsOneWidget);
  });
}
