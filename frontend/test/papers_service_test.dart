import 'package:flutter_test/flutter_test.dart';
import 'package:orbirag/services/papers_service.dart';

void main() {
  // ── Paper toJson / fromJson round-trip ──────────────────────
  group('Paper serialization', () {
    test('toJson / fromJson round-trip preserves all fields', () {
      final bookmark = Bookmark(
        id: 'bm1',
        label: 'My note',
        progress: 0.42,
        type: BookmarkType.note,
        createdAt: DateTime(2024, 6, 1, 12, 0),
        quote: 'interesting quote',
      );

      final paper = Paper(
        id: '123',
        title: 'Test Paper',
        authors: 'Smith, J.',
        category: 'NATURE',
        year: '2024',
        status: 'reading',
        progress: 0.42,
        url: 'https://example.com/paper',
        pdfUrl: 'https://example.com/paper.pdf',
        abstract: 'An abstract.',
        summary: 'A summary.',
        isFavorite: true,
        bookmarks: [bookmark],
        lastReadAt: DateTime(2024, 6, 2),
        totalReadingTimeSeconds: 600,
      );

      final json = paper.toJson();

      // Verify JSON keys
      expect(json['id'], '123');
      expect(json['title'], 'Test Paper');
      expect(json['pdf_url'], 'https://example.com/paper.pdf');
      expect(json['is_favorite'], true);
      expect((json['bookmarks'] as List).length, 1);
      expect(json['totalReadingTimeSeconds'], 600);

      // fromJson (server-side format, without bookmarks/lastReadAt)
      final serverJson = {
        'id': '123',
        'title': 'Test Paper',
        'authors': 'Smith, J.',
        'journal': 'NATURE',
        'year': '2024',
        'status': 'reading',
        'progress': 0.42,
        'url': 'https://example.com/paper',
        'pdf_url': 'https://example.com/paper.pdf',
        'abstract': 'An abstract.',
        'ai_summary': 'A summary.',
        'is_favorite': true,
      };
      final restored = Paper.fromJson(serverJson);
      expect(restored.id, '123');
      expect(restored.title, 'Test Paper');
      expect(restored.pdfUrl, 'https://example.com/paper.pdf');
      expect(restored.summary, 'A summary.');
      expect(restored.bookmarks, isEmpty); // loaded separately from prefs
    });
  });

  // ── fromJson with OLD JSON (no new fields) ──────────────────
  group('Paper.fromJson backwards compatibility', () {
    test('Old JSON without pdfUrl/bookmarks does NOT throw', () {
      final oldJson = {
        'id': '99',
        'title': 'Old Paper',
        'authors': 'Doe, J.',
        'year': '2020',
        'status': 'unread',
        'progress': 0.0,
        // no pdf_url, no bookmarks, no lastReadAt
      };
      expect(() => Paper.fromJson(oldJson), returnsNormally);
      final paper = Paper.fromJson(oldJson);
      expect(paper.pdfUrl, isNull);
      expect(paper.bookmarks, isEmpty);
      expect(paper.lastReadAt, isNull);
      expect(paper.totalReadingTimeSeconds, 0);
    });

    test('fromJson with null fields does NOT throw', () {
      final json = <String, dynamic>{
        'id': null,
        'title': null,
        'authors': null,
        'year': null,
        'status': null,
        'progress': null,
      };
      expect(() => Paper.fromJson(json), returnsNormally);
      final paper = Paper.fromJson(json);
      expect(paper.id, '');
      expect(paper.title, 'Untitled');
      expect(paper.status, 'unread');
      expect(paper.progress, 0.0);
    });
  });

  // ── Bookmark serialization ─────────────────────────────────
  group('Bookmark serialization', () {
    test('toJson / fromJson round-trip', () {
      final b = Bookmark(
        id: 'bk42',
        label: 'Key insight',
        progress: 0.75,
        type: BookmarkType.note,
        createdAt: DateTime(2024, 1, 15, 9, 30),
        quote: 'quoted text',
      );
      final json = b.toJson();
      final restored = Bookmark.fromJson(json);
      expect(restored.id, 'bk42');
      expect(restored.label, 'Key insight');
      expect(restored.progress, 0.75);
      expect(restored.type, BookmarkType.note);
      expect(restored.quote, 'quoted text');
    });

    test('fromJson with missing optional fields does NOT throw', () {
      final json = <String, dynamic>{
        'id': 'x',
        'label': 'test',
        'progress': 0.5,
        'type': 'progress',
        // no createdAt, no quote
      };
      expect(() => Bookmark.fromJson(json), returnsNormally);
      final b = Bookmark.fromJson(json);
      expect(b.quote, isNull);
      expect(b.type, BookmarkType.progress);
    });
  });

  // ── exportNotes ────────────────────────────────────────────
  group('PapersService.exportNotes', () {
    test('returns empty string for unknown paperId', () {
      final svc = PapersService();
      expect(svc.exportNotes('nonexistent'), '');
    });
  });
}
