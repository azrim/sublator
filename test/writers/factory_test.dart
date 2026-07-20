import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_translator/models/subtitle_format.dart';
import 'package:subtitle_translator/services/writers/ass_writer.dart';
import 'package:subtitle_translator/services/writers/srt_writer.dart';
import 'package:subtitle_translator/services/writers/sub_writer.dart';
import 'package:subtitle_translator/services/writers/subtitle_writer_factory.dart';
import 'package:subtitle_translator/services/writers/vtt_writer.dart';

void main() {
  const factory = SubtitleWriterFactory();

  test('returns SrtWriter for srt format', () {
    expect(factory.create(SubtitleFormat.srt), isA<SrtWriter>());
  });

  test('returns VttWriter for vtt format', () {
    expect(factory.create(SubtitleFormat.vtt), isA<VttWriter>());
  });

  test('returns SubWriter for sub format', () {
    expect(factory.create(SubtitleFormat.sub), isA<SubWriter>());
  });

  test('returns AssWriter for ass format', () {
    expect(factory.create(SubtitleFormat.ass), isA<AssWriter>());
  });

  test('SubWriter honours custom frame rate', () {
    final w = factory.create(SubtitleFormat.sub, frameRate: 25.0) as SubWriter;
    expect(w.frameRate, equals(25.0));
  });

  test('default frame rate is 23.976', () {
    final w = factory.create(SubtitleFormat.sub) as SubWriter;
    expect(w.frameRate, equals(23.976));
  });
}
