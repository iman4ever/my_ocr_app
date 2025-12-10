import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_ocr_app/main.dart';

void main() {
  testWidgets('OCR App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app title is present.
    expect(find.text('OCR App'), findsOneWidget);
    
    // Verify that we have two floating action buttons (camera and gallery).
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
  });
}
