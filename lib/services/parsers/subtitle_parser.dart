import 'dart:async';
import 'dart:convert';

import '../../models/subtitle_document.dart';

/// Contract for format-specific subtitle parsers.
///
/// Implementations read a byte stream ([Stream<List<int>>]) and return a
/// [SubtitleDocument]. The optional [frameRate] parameter is honoured by
/// frame-based formats (e.g. MicroDVD).
abstract class SubtitleParser {
  const SubtitleParser();

  Future<SubtitleDocument> parse(Stream<List<int>> stream, {double? frameRate});

  /// Consumes the entire byte stream, strips a UTF-8 BOM if present, decodes
  /// the remainder as UTF-8 (allowing malformed sequences), and normalises
  /// CRLF / CR line endings to `\n`.
  ///
  /// Shared by every concrete parser so BOM + encoding handling lives once.
  static Future<String> decodeStream(Stream<List<int>> stream) async {
    final bytes = await stream.expand((b) => b).toList();
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }
    final text = utf8.decode(data, allowMalformed: true);
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }
}
