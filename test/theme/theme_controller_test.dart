import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:artham/theme/artham_theme.dart';
import 'package:artham/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ArthamColors.use(ArthamPalette.artham));

  test('unknown or missing ids fall back to the original Artham theme', () {
    expect(ArthamPalette.byId(null).id, 'artham');
    expect(ArthamPalette.byId('nope').id, 'artham');
    expect(ArthamPalette.byId('dark').id, 'dark');
    expect(ArthamPalette.byId('light').id, 'light');
  });

  test('choice is saved and loaded again', () async {
    final dir = await Directory.systemTemp.createTemp('theme_test');
    addTearDown(() => dir.delete(recursive: true));
    final store = ThemeStore(documentsDirectoryProvider: () async => dir);
    expect(await store.loadId(), isNull);
    final controller = ArthamThemeController(store: store);
    await controller.select(ArthamPalette.light);
    expect(ArthamColors.palette.id, 'light');
    expect(await store.loadId(), 'light');
    ArthamColors.use(ArthamPalette.artham);
    await controller.load();
    expect(ArthamColors.palette.id, 'light');
  });
}
