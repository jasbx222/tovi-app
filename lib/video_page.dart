import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'session.dart';
import 'ui.dart';

/// Plays a lesson's YouTube link inside the app. Links that are not YouTube
/// open in the browser instead.
class LessonVideoPage extends StatefulWidget {
  const LessonVideoPage({super.key, required this.session, required this.title, required this.youtubeId, this.subtitle = '', this.onWatched});
  final Session session;
  final String title;
  final String subtitle;
  final String youtubeId;
  final VoidCallback? onWatched;

  @override
  State<LessonVideoPage> createState() => _LessonVideoPageState();
}

class _LessonVideoPageState extends State<LessonVideoPage> {
  late final YoutubePlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = YoutubePlayerController.fromVideoId(
      videoId: widget.youtubeId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true, playsInline: true),
    );
    widget.onWatched?.call();
  }

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final player = YoutubePlayer(controller: controller, aspectRatio: 16 / 9);
    return Scaffold(
      backgroundColor: ToviTokens.night,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        if (widget.subtitle.isNotEmpty)
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: copy.pick('فتح في يوتيوب', 'Open in YouTube'),
                    onPressed: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=${widget.youtubeId}'), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(borderRadius: BorderRadius.circular(ToviTokens.radiusMd), child: player),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a lesson video: in the app for YouTube, in the browser otherwise.
Future<void> playLesson(BuildContext context, Session session, {required String title, required String reference, String youtubeId = '', String subtitle = '', VoidCallback? onWatched}) async {
  if (youtubeId.isNotEmpty) {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LessonVideoPage(session: session, title: title, subtitle: subtitle, youtubeId: youtubeId, onWatched: onWatched),
      ),
    );
    return;
  }
  final uri = Uri.tryParse(reference);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
  onWatched?.call();
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
