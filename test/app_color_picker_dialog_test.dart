import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storm_teleprompter_plus/widgets/common/app_color_picker_dialog.dart';

void main() {
  testWidgets('HEX input fills the color dialog on a mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => AppColorPickerDialog.show(
                context,
                title: '选择颜色',
                currentColor: Colors.red,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(AppColorPickerDialog), findsOneWidget);
    final input = find.descendant(
      of: find.byType(AppColorPickerDialog),
      matching: find.byType(TextField),
    );
    expect(input, findsOneWidget);
    expect(tester.getSize(input).width, greaterThanOrEqualTo(260));
    expect(tester.takeException(), isNull);
  });
}
