// Basic smoke test for RevenueScope app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/locale_notifier.dart';
import 'package:mobile/core/theme/theme_mode_notifier.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    await ThemeModeNotifier.load();
    await LocaleNotifier.load();
    await tester.pumpWidget(const App());
    await tester.pump();
  });
}
