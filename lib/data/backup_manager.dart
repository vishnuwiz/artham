import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';
import 'data_export_service.dart';

enum BackupFrequency { daily, weekly, monthly }

enum BackupKind { automatic, manual, restoreSafety }

extension BackupFrequencyLabel on BackupFrequency {
  String get label => switch (this) {
    BackupFrequency.daily => 'Daily',
    BackupFrequency.weekly => 'Weekly',
    BackupFrequency.monthly => 'Monthly',
  };
}

extension BackupKindLabel on BackupKind {
  String get label => switch (this) {
    BackupKind.automatic => 'Automatic backup',
    BackupKind.manual => 'Manual backup',
    BackupKind.restoreSafety => 'Pre-restore safety copy',
  };
}

class BackupSettings {
  final bool automaticBackupsEnabled;
  final BackupFrequency frequency;
  final int maxAutomaticBackups;
  final DateTime? lastAutomaticBackupAt;

  const BackupSettings({
    this.automaticBackupsEnabled = false,
    this.frequency = BackupFrequency.weekly,
    this.maxAutomaticBackups = 10,
    this.lastAutomaticBackupAt,
  });

  BackupSettings copyWith({
    bool? automaticBackupsEnabled,
    BackupFrequency? frequency,
    int? maxAutomaticBackups,
    DateTime? lastAutomaticBackupAt,
  }) {
    return BackupSettings(
      automaticBackupsEnabled:
          automaticBackupsEnabled ?? this.automaticBackupsEnabled,
      frequency: frequency ?? this.frequency,
      maxAutomaticBackups: maxAutomaticBackups ?? this.maxAutomaticBackups,
      lastAutomaticBackupAt:
          lastAutomaticBackupAt ?? this.lastAutomaticBackupAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'settingsVersion': 1,
    'automaticBackupsEnabled': automaticBackupsEnabled,
    'frequency': frequency.name,
    'maxAutomaticBackups': maxAutomaticBackups,
    'lastAutomaticBackupAt': lastAutomaticBackupAt?.toUtc().toIso8601String(),
  };

  factory BackupSettings.fromJson(Map<String, dynamic> json) {
    if (json['settingsVersion'] != 1) {
      throw const FormatException('Unsupported backup settings version.');
    }

    final frequencyName = json['frequency'];
    final frequency = BackupFrequency.values.firstWhere(
      (value) => value.name == frequencyName,
      orElse: () => BackupFrequency.weekly,
    );
    final rawRetention = json['maxAutomaticBackups'];
    final retention =
        rawRetention is int && rawRetention >= 1 && rawRetention <= 100
        ? rawRetention
        : 10;
    final rawLastBackup = json['lastAutomaticBackupAt'];
    final lastBackup = rawLastBackup is String
        ? DateTime.tryParse(rawLastBackup)
        : null;

    return BackupSettings(
      automaticBackupsEnabled: json['automaticBackupsEnabled'] == true,
      frequency: frequency,
      maxAutomaticBackups: retention,
      lastAutomaticBackupAt: lastBackup?.toUtc(),
    );
  }
}

class BackupHistoryEntry {
  final File file;
  final BackupKind kind;
  final DateTime createdAt;
  final int sizeBytes;

  const BackupHistoryEntry({
    required this.file,
    required this.kind,
    required this.createdAt,
    required this.sizeBytes,
  });
}

/// Stores local backup settings and managed backup files in app-private storage.
///
/// Automatic backups are checked by the app when it starts or resumes. This
/// service does not schedule an operating-system background task.
class BackupManagerService {
  final AppDatabase database;
  final Future<Directory> Function()? documentsDirectoryProvider;
  final DateTime Function() clock;

  Future<File?>? _automaticBackupInProgress;

  BackupManagerService(
    this.database, {
    this.documentsDirectoryProvider,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<Directory> _documentsDirectory() async {
    final provider = documentsDirectoryProvider;
    return provider == null ? getApplicationDocumentsDirectory() : provider();
  }

  Future<Directory> _arthamDirectory() async {
    final documents = await _documentsDirectory();
    return Directory(p.join(documents.path, 'Artham'));
  }

  Future<Directory> _managedBackupsDirectory() async {
    final directory = Directory(
      p.join((await _arthamDirectory()).path, 'managed_backups'),
    );
    return directory;
  }

  Future<Directory> _restoreSafetyDirectory() async {
    return Directory(
      p.join((await _arthamDirectory()).path, 'restore_safety_backups'),
    );
  }

  Future<File> _settingsFile() async {
    return File(
      p.join((await _arthamDirectory()).path, 'backup_settings.json'),
    );
  }

  Future<BackupSettings> loadSettings() async {
    final file = await _settingsFile();
    if (!await file.exists()) return const BackupSettings();

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const BackupSettings();
      return BackupSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      // A damaged settings file must not prevent app startup. The safe default
      // is to leave automatic backups disabled until the user enables them.
      return const BackupSettings();
    }
  }

  Future<void> saveSettings(BackupSettings settings) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      encoding: utf8,
      flush: true,
    );
  }

  Future<File> createManualBackup() {
    return _writeManagedBackup(BackupKind.manual);
  }

  /// Creates at most one scheduled backup at a time for this service instance.
  Future<File?> maybeCreateScheduledBackup() {
    final inProgress = _automaticBackupInProgress;
    if (inProgress != null) return inProgress;

    final task = _maybeCreateScheduledBackup();
    _automaticBackupInProgress = task;
    return task.whenComplete(() {
      if (identical(_automaticBackupInProgress, task)) {
        _automaticBackupInProgress = null;
      }
    });
  }

  Future<File?> _maybeCreateScheduledBackup() async {
    final settings = await loadSettings();
    if (!settings.automaticBackupsEnabled) return null;

    final now = clock().toUtc();
    if (!_isBackupDue(settings, now)) return null;

    final file = await _writeManagedBackup(BackupKind.automatic);
    await saveSettings(settings.copyWith(lastAutomaticBackupAt: now));
    await _pruneAutomaticBackups(settings.maxAutomaticBackups);
    return file;
  }

  bool _isBackupDue(BackupSettings settings, DateTime now) {
    final last = settings.lastAutomaticBackupAt;
    if (last == null) return true;
    final previous = last.toUtc();
    if (now.isBefore(previous)) return false;

    return switch (settings.frequency) {
      BackupFrequency.daily =>
        now.difference(previous) >= const Duration(days: 1),
      BackupFrequency.weekly =>
        now.difference(previous) >= const Duration(days: 7),
      BackupFrequency.monthly =>
        (now.year * 12 + now.month) - (previous.year * 12 + previous.month) >=
            1,
    };
  }

  Future<void> pruneAutomaticBackups() async {
    final settings = await loadSettings();
    await _pruneAutomaticBackups(settings.maxAutomaticBackups);
  }

  Future<void> _pruneAutomaticBackups(int keepCount) async {
    final history = await listBackupHistory();
    final automatic =
        history.where((entry) => entry.kind == BackupKind.automatic).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final entry in automatic.skip(keepCount)) {
      await deleteBackup(entry);
    }
  }

  Future<List<BackupHistoryEntry>> listBackupHistory() async {
    final entries = <BackupHistoryEntry>[];
    final managedDirectory = await _managedBackupsDirectory();
    final safetyDirectory = await _restoreSafetyDirectory();

    await _appendDirectoryEntries(
      directory: managedDirectory,
      entries: entries,
      kindForName: (name) {
        if (name.startsWith('artham_automatic_')) return BackupKind.automatic;
        if (name.startsWith('artham_manual_')) return BackupKind.manual;
        return null;
      },
    );
    await _appendDirectoryEntries(
      directory: safetyDirectory,
      entries: entries,
      kindForName: (name) => name.startsWith('artham_pre_restore_')
          ? BackupKind.restoreSafety
          : null,
    );

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> _appendDirectoryEntries({
    required Directory directory,
    required List<BackupHistoryEntry> entries,
    required BackupKind? Function(String name) kindForName,
  }) async {
    if (!await directory.exists()) return;

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith('.json')) continue;
      final kind = kindForName(name);
      if (kind == null) continue;

      final stat = await entity.stat();
      entries.add(
        BackupHistoryEntry(
          file: entity,
          kind: kind,
          createdAt: _createdAtFromName(name, kind) ?? stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
  }

  DateTime? _createdAtFromName(String name, BackupKind kind) {
    if (kind == BackupKind.restoreSafety) return null;
    final timestampText = name
        .substring(0, name.length - '.json'.length)
        .split('_')
        .last;
    final timestamp = int.tryParse(timestampText);
    if (timestamp == null) return null;
    return DateTime.fromMicrosecondsSinceEpoch(timestamp, isUtc: true);
  }

  Future<void> deleteBackup(BackupHistoryEntry entry) async {
    final absolutePath = p.normalize(p.absolute(entry.file.path));
    final directories = [
      await _managedBackupsDirectory(),
      await _restoreSafetyDirectory(),
    ];
    final isAllowed = directories.any((directory) {
      final root = p.normalize(p.absolute(directory.path));
      return p.isWithin(root, absolutePath);
    });

    if (!isAllowed) {
      throw ArgumentError('The selected file is not an Artham backup.');
    }
    if (await entry.file.exists()) {
      await entry.file.delete();
    }
  }

  Future<File> _writeManagedBackup(BackupKind kind) async {
    if (kind == BackupKind.restoreSafety) {
      throw ArgumentError('Restore safety backups use the restore flow.');
    }

    final directory = await _managedBackupsDirectory();
    await directory.create(recursive: true);
    final contents = await DataExportService(database).buildFullBackupJson();
    final timestamp = clock().toUtc().microsecondsSinceEpoch;
    var file = File(
      p.join(directory.path, 'artham_${kind.name}_$timestamp.json'),
    );
    var suffix = timestamp;
    while (await file.exists()) {
      suffix += 1;
      file = File(p.join(directory.path, 'artham_${kind.name}_$suffix.json'));
    }

    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(contents, encoding: utf8, flush: true);
    if (await temporaryFile.length() == 0) {
      await temporaryFile.delete();
      throw FileSystemException(
        'The backup could not be saved completely.',
        temporaryFile.path,
      );
    }

    final savedFile = await temporaryFile.rename(file.path);
    return savedFile;
  }
}
