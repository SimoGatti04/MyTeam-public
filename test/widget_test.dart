import 'package:flutter_test/flutter_test.dart';
import 'package:myteam/core/constants/app_constants.dart';
import 'package:myteam/core/constants/api_constants.dart';

void main() {
  group('Endpoint Configuration Regression Tests', () {
    test('Production baseUrl uses .it domain and HTTPS', () {
      final baseUrl = AppConstants.baseUrl;
      expect(baseUrl, equals('https://myteam.simogatti.it'));
      expect(baseUrl.startsWith('https://'), isTrue);
      expect(baseUrl.contains('simogatti.space'), isFalse,
          reason: 'Legacy .space domain must not be used');
      expect(baseUrl.contains('simogatti.it'), isTrue);
    });

    test('ApiConstants endpoints derive correctly from AppConstants.baseUrl', () {
      expect(ApiConstants.baseUrl, equals(AppConstants.baseUrl));
      expect(ApiConstants.videos, equals('https://myteam.simogatti.it/api/videos'));
      expect(ApiConstants.health, equals('https://myteam.simogatti.it/health'));
      expect(ApiConstants.chunkedUploadInit, equals('https://myteam.simogatti.it/api/videos/chunked/init'));
      expect(ApiConstants.chunkedUploadChunk, equals('https://myteam.simogatti.it/api/videos/chunked/chunk'));
      expect(ApiConstants.chunkedUploadComplete, equals('https://myteam.simogatti.it/api/videos/chunked/complete'));
      expect(ApiConstants.uploadQueue, equals('https://myteam.simogatti.it/api/upload-queue'));
      expect(ApiConstants.players, equals('https://myteam.simogatti.it/api/players'));
      expect(ApiConstants.trainingTypes, equals('https://myteam.simogatti.it/api/training-types'));
      expect(ApiConstants.teams, equals('https://myteam.simogatti.it/api/teams'));
      expect(ApiConstants.videoDetail('123'), equals('https://myteam.simogatti.it/api/videos/123'));
      expect(ApiConstants.videoStream('123'), equals('https://myteam.simogatti.it/api/videos/123/stream'));
    });

    test('No endpoint contains the legacy .space domain', () {
      final endpoints = [
        AppConstants.baseUrl,
        AppConstants.apiBaseUrl,
        ApiConstants.baseUrl,
        ApiConstants.videos,
        ApiConstants.health,
        ApiConstants.chunkedUploadInit,
        ApiConstants.chunkedUploadChunk,
        ApiConstants.chunkedUploadComplete,
        ApiConstants.uploadQueue,
        ApiConstants.players,
        ApiConstants.trainingTypes,
        ApiConstants.teams,
        ApiConstants.videoDetail('1'),
        ApiConstants.videoThumbnail('1'),
        ApiConstants.videoDownload('1'),
        ApiConstants.videoStream('1'),
        ApiConstants.playerDetail('1'),
        ApiConstants.trainingTypeDetail('1'),
        ApiConstants.teamDetail('1'),
        ApiConstants.videoNotes('1'),
        ApiConstants.videoNoteDetail('1', '2'),
      ];

      for (final ep in endpoints) {
        expect(ep.contains('.space'), isFalse, reason: '$ep contains legacy .space domain');
        expect(ep.contains('simogatti.it'), isTrue, reason: '$ep does not contain simogatti.it domain');
      }
    });
  });
}
