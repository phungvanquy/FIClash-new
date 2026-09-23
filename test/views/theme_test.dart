import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1400, 1400);
  });

  tearDown(() => container.dispose());

  Future<void> pumpThemeView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: ThemeView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  ThemeProps readTheme() => container.read(themeSettingProvider);

  group('theme mode', () {
    testWidgets('defaults to the dark theme', (tester) async {
      await pumpThemeView(tester);

      expect(readTheme().themeMode, ThemeMode.dark);
    });

    testWidgets('switches to light and back to dark', (tester) async {
      await pumpThemeView(tester);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.light);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.dark);

      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(readTheme().themeMode, ThemeMode.system);
    });
  });

  testWidgets(
    'uses Tonal Spot and resets colors without changing text or mode',
    (tester) async {
      await pumpThemeView(tester);
      expect(find.text('Tonal spot'), findsOneWidget);
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith(
              primaryColor: 0xFFD8C0C3,
              schemeVariant: DynamicSchemeVariant.content,
              themeMode: ThemeMode.light,
              textScale: const TextScale(enable: true, scale: 1.2),
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(readTheme().primaryColor, defaultPrimaryColor);
      expect(readTheme().primaryColors, defaultPrimaryColors);
      expect(readTheme().schemeVariant, DynamicSchemeVariant.tonalSpot);
      expect(readTheme().themeMode, ThemeMode.light);
      expect(readTheme().textScale.scale, 1.2);
      expect(find.byTooltip('Reset'), findsNothing);
    },
  );

  testWidgets('applies the default 80 percent scale to application content', (
    tester,
  ) async {
    double? actualScale;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: ThemeManager(
            child: Builder(
              builder: (context) {
                actualScale = MediaQuery.textScalerOf(context).scale(100);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    expect(actualScale, 80);
  });

  group('pure black', () {
    testWidgets('toggles both ways', (tester) async {
      await pumpThemeView(tester);
      final toggle = find.byType(Switch).first;

      expect(readTheme().pureBlack, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(readTheme().pureBlack, isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(readTheme().pureBlack, isFalse);
    });
  });

  group('text scale', () {
    testWidgets('defaults to 80 percent and can follow system scaling', (
      tester,
    ) async {
      await pumpThemeView(tester);

      expect(readTheme().textScale.enable, isTrue);
      expect(readTheme().textScale.scale, 0.8);
      expect(find.text('80%'), findsOneWidget);

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(readTheme().textScale.enable, isFalse);
    });

    testWidgets('the slider writes a new scale from the default', (
      tester,
    ) async {
      await pumpThemeView(tester);
      final before = readTheme().textScale.scale;

      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      await tester.drag(slider, const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(readTheme().textScale.scale, isNot(before));
    });

    testWidgets('renders the scale as a rounded percentage', (tester) async {
      container
          .read(themeSettingProvider.notifier)
          .update(
            (state) => state.copyWith.textScale(enable: true, scale: 1.2),
          );

      await pumpThemeView(tester);

      expect(find.text('120%'), findsOneWidget);
    });
  });
}
