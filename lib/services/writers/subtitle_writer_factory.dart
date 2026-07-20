import '../../models/subtitle_format.dart';
import 'ass_writer.dart';
import 'srt_writer.dart';
import 'sub_writer.dart';
import 'subtitle_writer.dart';
import 'vtt_writer.dart';

/// Creates [SubtitleWriter] instances for a given [SubtitleFormat].
///
/// Stateless writers (SRT, VTT, ASS) return const singletons; the MicroDVD
/// writer is constructed per-call because it carries a user-specified
/// [frameRate].
class SubtitleWriterFactory {
  const SubtitleWriterFactory();

  SubtitleWriter create(SubtitleFormat format, {double frameRate = 23.976}) {
    switch (format) {
      case SubtitleFormat.srt:
        return const SrtWriter();
      case SubtitleFormat.vtt:
        return const VttWriter();
      case SubtitleFormat.sub:
        return SubWriter(frameRate: frameRate);
      case SubtitleFormat.ass:
        return const AssWriter();
    }
  }
}
