import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:subtitle_studio/app/providers/core_providers.dart';
import 'package:subtitle_studio/database/models/models.dart';

final olamDictionaryRepositoryProvider =
    Provider<OlamDictionaryRepository>((ref) {
  return OlamDictionaryRepository(ref.watch(isarProvider));
});

class OlamDictionaryRepository {
  final Isar _isar;

  const OlamDictionaryRepository(this._isar);

  Future<int> countEntries() {
    return _isar.dictionaryEntrys.count();
  }

  Future<void> clearEntries() async {
    await _isar.writeTxn(() async {
      await _isar.dictionaryEntrys.clear();
    });
  }

  Future<void> addEntries(List<DictionaryEntry> entries) async {
    const batchSize = 1000;

    for (int i = 0; i < entries.length; i += batchSize) {
      final end = min(i + batchSize, entries.length);
      final batch = entries.sublist(i, end);

      await _isar.writeTxn(() async {
        await _isar.dictionaryEntrys.putAll(batch);
      });
    }
  }

  Future<bool> probeWritable() async {
    final entry = DictionaryEntry(
      word: '__subtitle_studio_probe__',
      meaning: 'പരീക്ഷ',
      partOfSpeech: 'n',
      dictionaryType: 'EN-ML',
    );

    await _isar.writeTxn(() async {
      await _isar.dictionaryEntrys.put(entry);
    });

    final inserted = await _isar.dictionaryEntrys.get(entry.id) != null;

    await _isar.writeTxn(() async {
      await _isar.dictionaryEntrys.delete(entry.id);
    });

    return inserted;
  }

  Future<List<DictionaryEntry>> searchByWord(
    String query,
    String dictionaryType, {
    bool wholeWord = false,
    bool caseSensitive = false,
  }) {
    return _search(
      query,
      dictionaryType,
      searchByWord: true,
      wholeWord: wholeWord,
      caseSensitive: caseSensitive,
    );
  }

  Future<List<DictionaryEntry>> searchByMeaning(
    String query,
    String dictionaryType, {
    bool wholeWord = false,
    bool caseSensitive = false,
  }) {
    return _search(
      query,
      dictionaryType,
      searchByWord: false,
      wholeWord: wholeWord,
      caseSensitive: caseSensitive,
    );
  }

  Future<List<DictionaryEntry>> _search(
    String query,
    String dictionaryType, {
    required bool searchByWord,
    required bool wholeWord,
    required bool caseSensitive,
  }) async {
    final allEntries = await _isar.dictionaryEntrys.where().findAll();

    final matching = allEntries.where((entry) {
      if (entry.dictionaryType != dictionaryType) return false;

      final rawText = searchByWord ? entry.word : entry.meaning;
      final text = caseSensitive ? rawText : rawText.toLowerCase();
      final pattern = caseSensitive ? query : query.toLowerCase();

      if (!wholeWord) {
        return text.contains(pattern);
      }

      final regexPattern =
          r'(?:^|[\s\p{P}\p{Z}])' +
          RegExp.escape(pattern) +
          r'(?=[\s\p{P}\p{Z}]|$)';
      return RegExp(
        regexPattern,
        unicode: true,
        caseSensitive: caseSensitive,
      ).hasMatch(text);
    }).toList();

    return _sortByRelevance(
      matching,
      query,
      caseSensitive: caseSensitive,
      searchByWord: searchByWord,
    );
  }

  List<DictionaryEntry> _sortByRelevance(
    List<DictionaryEntry> entries,
    String query, {
    required bool caseSensitive,
    required bool searchByWord,
  }) {
    if (entries.isEmpty || query.isEmpty) return entries;

    final normalizedQuery =
        caseSensitive ? query : query.toLowerCase();

    entries.sort((a, b) {
      final rawA = searchByWord ? a.word : a.meaning;
      final rawB = searchByWord ? b.word : b.meaning;
      final textA = caseSensitive ? rawA : rawA.toLowerCase();
      final textB = caseSensitive ? rawB : rawB.toLowerCase();

      final scoreA = _relevanceScore(textA, normalizedQuery);
      final scoreB = _relevanceScore(textB, normalizedQuery);

      final scoreComparison = scoreB.compareTo(scoreA);
      return scoreComparison != 0
          ? scoreComparison
          : textA.compareTo(textB);
    });

    return entries;
  }

  int _relevanceScore(String text, String query) {
    if (text == query) return 1000;
    if (text.startsWith(query)) return 500;
    if (text.contains(query)) {
      return 100 + max(0, 100 - text.length);
    }
    return 0;
  }
}
