import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mystock/main.dart';
import 'package:mystock/features/settings/repositories/settings_repository.dart';

void main() {
  testWidgets('MyStockApp inicia corretamente', (WidgetTester tester) async {
    final repository = SettingsRepository();

    await tester.pumpWidget(
      MyStockApp(
        settingsRepository: repository,
        themeModeInicial: ThemeMode.light,
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}