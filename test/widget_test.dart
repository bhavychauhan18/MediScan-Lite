import 'package:flutter_test/flutter_test.dart';

import 'package:med_scan_lite/main.dart';

void main() {
  testWidgets('MediScan Lite app loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MediScanApp());

    expect(find.text('MediScan Lite'), findsOneWidget);
    expect(find.text('Stay on top of your medicines'), findsOneWidget);
    expect(find.text('Scan a prescription'), findsOneWidget);
  });
}