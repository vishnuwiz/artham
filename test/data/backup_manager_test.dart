import 'dart:io';

import 'package:artham/data/app_database.dart';
import 'package:artham/data/backup_manager.dart';
import 'package:artham/data/data_export_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late Directory documentsDirectory;
  late DateTime now;
  late BackupManagerService manager;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    documentsDirectory = await Directory.systemTemp.createTemp(
      'artham-backup-manager-test-',
    );
    now = DateTime.utc(2026, 11, 12, 10);
    manager = BackupManagerService(
      database,
      documentsDirectoryProvider: () async => documentsDirectory,
      clock: () => now,
    );
  });

  tearDown(() async {
    await database.close();
    await documentsDirectory.delete(recursive: true);
  });

  test('automatic backups are disabled by default', () async {
    final settings = await manager.loadSettings();

    expect(settings.automaticBackupsEnabled, isFalse);
    expect(settings.frequency, BackupFrequency.weekly);
    expect(settings.maxAutomaticBackups, 10);
    expect(await manager.maybeCreateScheduledBackup(), isNull);
    expect(await manager.listBackupHistory(), isEmpty);
  });

  test('saves and reloads backup settings', () async {
    const settings = BackupSettings(
      automaticBackupsEnabled: true,
      frequency: BackupFrequency.monthly,
      maxAutomaticBackups: 5,
    );

    await manager.saveSettings(settings);
    final loaded = await manager.loadSettings();

    expect(loaded.automaticBackupsEnabled, isTrue);
    expect(loaded.frequency, BackupFrequency.monthly);
    expect(loaded.maxAutomaticBackups, 5);
  });

  test(
    'creates scheduled backups only when due and prunes old automatic copies',
    () async {
      await manager.saveSettings(
        const BackupSettings(
          automaticBackupsEnabled: true,
          frequency: BackupFrequency.daily,
          maxAutomaticBackups: 2,
        ),
      );

      final first = await manager.maybeCreateScheduledBackup();
      expect(first, isNotNull);
      expect(await manager.maybeCreateScheduledBackup(), isNull);

      now = now.add(const Duration(days: 1));
      expect(await manager.maybeCreateScheduledBackup(), isNotNull);

      now = now.add(const Duration(days: 1));
      expect(await manager.maybeCreateScheduledBackup(), isNotNull);

      final history = await manager.listBackupHistory();
      final automatic = history
          .where((entry) => entry.kind == BackupKind.automatic)
          .toList();
      expect(automatic, hasLength(2));
      expect(automatic.every((entry) => entry.file.existsSync()), isTrue);
    },
  );

  test('manual backups appear in history and can be deleted', () async {
    final file = await manager.createManualBackup();
    expect(await file.exists(), isTrue);

    final history = await manager.listBackupHistory();
    expect(history, hasLength(1));
    expect(history.single.kind, BackupKind.manual);

    await manager.deleteBackup(history.single);
    expect(await manager.listBackupHistory(), isEmpty);
  });

  test('history includes existing pre-restore safety copies', () async {
    final exportService = DataExportService(
      database,
      documentsDirectoryProvider: () async => documentsDirectory,
    );
    final safetyCopy = await exportService.createLocalSafetyBackupFile();

    final history = await manager.listBackupHistory();
    expect(history, hasLength(1));
    expect(history.single.kind, BackupKind.restoreSafety);
    expect(history.single.file.path, safetyCopy.path);
  });
}
