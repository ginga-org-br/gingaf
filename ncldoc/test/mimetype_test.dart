import 'package:test/test.dart';
import 'package:ncldoc/mimetype.dart';

void main() {
  group('MIME Type Resolution Tests', () {
    test('resolves standard video mime types', () {
      expect(getMimeTypeFromExtension('video.mp4'), equals('video/mp4'));
      expect(getMimeTypeFromExtension('clip.webm'), equals('video/webm'));
      expect(getMimeTypeFromExtension('movie.mpeg'), equals('video/mpeg'));
      expect(getMimeTypeFromExtension('sample.avi'), equals('video/avi'));
    });

    test('resolves standard audio mime types', () {
      expect(getMimeTypeFromExtension('track.mp3'), equals('audio/mpeg'));
      expect(getMimeTypeFromExtension('audio.wav'), equals('audio/wav'));
      expect(getMimeTypeFromExtension('sound.aac'), equals('audio/aac'));
      expect(getMimeTypeFromExtension('music.ogg'), equals('audio/ogg'));
      expect(getMimeTypeFromExtension('song.m4a'), equals('audio/mp4'));
      expect(getMimeTypeFromExtension('file.flac'), equals('audio/flac'));
    });

    test('resolves standard image mime types', () {
      expect(getMimeTypeFromExtension('photo.png'), equals('image/png'));
      expect(getMimeTypeFromExtension('picture.jpeg'), equals('image/jpeg'));
      expect(getMimeTypeFromExtension('picture.jpg'), equals('image/jpeg'));
      expect(getMimeTypeFromExtension('vector.svg'), equals('image/svg+xml'));
      expect(getMimeTypeFromExtension('graphic.webp'), equals('image/webp'));
    });

    test('handles uppercase extensions and empty or unknown paths', () {
      expect(getMimeTypeFromExtension('VIDEO.MP4'), equals('video/mp4'));
      expect(getMimeTypeFromExtension(''), equals('application/x-ginga-time'));
      expect(getMimeTypeFromExtension('file_without_ext'), equals('application/x-ginga-time'));
      expect(getMimeTypeFromExtension('unknown.xyz'), equals('application/x-ginga-time'));
    });
  });
}
