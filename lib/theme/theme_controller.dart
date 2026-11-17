import 'dart:convert';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'artham_theme.dart';

/// Remembers which theme the user picked, in a small file next to the other
/// app files. The original Artham look is used until a choice is saved.
class ThemeStore {
  ThemeStore({this.documentsDirectoryProvider});

  final Future<Directory> Function()? documentsDirectoryProvider;

  Future<File> _file() async {
    final provider = documentsDirectoryProvider;
    final documents = provider == null
        ? await getApplicationDocumentsDirectory()
        : await provider();
    return File(p.join(documents.path, 'Artham', 'theme.json'));
  }

  Future<String?> loadId() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map && decoded['theme'] is String) {
        return decoded['theme'] as String;
      }
    } catch (_) {
      // A missing or damaged file just means the default theme.
    }
    return null;
  }

  Future<void> saveId(String id) async {
    try {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({'theme': id}), flush: true);
    } catch (_) {
      // Not being able to remember the choice must never break switching.
    }
  }
}

/// Holds the active theme and restyles the running app when it changes.
class ArthamThemeController extends ChangeNotifier {
  ArthamThemeController({ThemeStore? store}) : _store = store ?? ThemeStore();

  /// The one controller the app uses.
  static final ArthamThemeController instance = ArthamThemeController();

  final ThemeStore _store;

  ArthamPalette get palette => ArthamColors.palette;

  /// Applies the saved theme. Call once before the first frame.
  Future<void> load() async {
    final id = await _store.loadId();
    ArthamColors.use(ArthamPalette.byId(id));
    _applySystemChrome();
  }

  /// Switches theme, saves the choice and repaints every screen.
  Future<void> select(ArthamPalette next) async {
    if (next.id == palette.id) return;
    ArthamColors.use(next);
    _applySystemChrome();
    notifyListeners();
    _repaintEverything();
    await _store.saveId(next.id);
  }

  void _applySystemChrome() {
    final dark = palette.brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: palette.ink,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  /// Colours are read when a widget builds, and a `const` widget is skipped
  /// when its parent rebuilds. Marking every element dirty makes each one
  /// build again with the new colours.
  void _repaintEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.rootElement?.visitChildren(mark);
    });
    SchedulerBinding.instance.scheduleFrame();
  }
}
