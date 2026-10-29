import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/app/repositories/app_data_maintenance_repository.dart';
import 'package:subtitle_studio/database/models/models.dart';
import 'package:subtitle_studio/database/stores/preferences_store.dart';

import 'support/test_isar_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('temporary cache matcher never targets unrelated files', () {
    expect(AppDataMaintenanceRepository.isOwnedTemporaryWaveformFile(
        'waveform_audio_12_8ba8a1ff.raw'), isTrue);
    expect(AppDataMaintenanceRepository.isOwnedTemporaryWaveformFile(
        'waveform_temp_123456_1.raw'), isTrue);
    for (final name in [
      'notes.srt', 'waveform_audio_custom.raw', 'waveform_audio_4_aabbccdd.srt',
      'waveform_temp_notes.raw', 'waveform_audio_4_aabbccdd.raw.bak',
      'subtitle_studio_backup.zip',
    ]) {
      expect(AppDataMaintenanceRepository.isOwnedTemporaryWaveformFile(name),
          isFalse, reason: name);
    }
  });

  test('clear project data includes history refs and preserves dictionaries',
      () async {
    final harness = await TestIsarHarness.open();
    addTearDown(harness.close);
    final isar = harness.isar;
    await PreferencesStore(isar).update((prefs) {
      prefs.maxCheckpoints = 100;
    });

    final now = DateTime.utc(2026, 10, 27);
    await isar.writeTxn(() async {
      await isar.historyRefs.put(HistoryRef(
        sessionId: 4,
        subtitleCollectionId: 9,
        name: 'refs/heads/main',
        kind: 'branch',
        targetCheckpointId: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await isar.dictionaryEntrys.put(DictionaryEntry(
        word: 'test', meaning: 'sample', partOfSpeech: 'n',
        dictionaryType: 'EN-ML',
      ));
    });

    await AppDataMaintenanceRepository(isar).clearStoredApplicationData();

    expect(await isar.preferences.count(), 0);
    expect(await isar.historyRefs.count(), 0);
    expect(await isar.checkpoints.count(), 0);
    expect(await isar.dictionaryEntrys.count(), 1);
  });
}
