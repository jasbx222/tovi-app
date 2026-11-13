import 'package:material_ui/material_ui.dart';

import '../session.dart';
import 'hub_kit.dart';
import 'tiles.dart';

/// Courses the student saved or liked, with undo from each card.
class SavedPage extends StatefulWidget {
  const SavedPage({super.key, required this.session});
  final Session session;
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  var tab = 0;
  var list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    final copy = widget.session.copy;
    final kind = tab == 0 ? 'saved' : 'liked';
    return HubScaffold(
      title: copy.pick('المحفوظات', 'Saved'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: HubSegments(
            labels: [copy.pick('محفوظة', 'Saved'), copy.pick('أعجبتني', 'Liked')],
            index: tab,
            onChanged: (i) => setState(() { tab = i; list = GlobalKey<PagedListState>(); }),
          ),
        ),
        Expanded(
          child: PagedList(
            key: list,
            session: widget.session,
            grid: true,
            skeletonHeight: 120,
            load: (page) => widget.session.api.get('/api/student/saved?kind=$kind&page=$page&pageSize=20'),
            empty: HubEmpty(
              icon: tab == 0 ? Icons.bookmark_rounded : Icons.favorite_rounded,
              title: tab == 0 ? copy.pick('ما حفظت أي دورة', 'Nothing saved yet') : copy.pick('ما عجبتك أي دورة بعد', 'No liked courses yet'),
              body: copy.pick('اضغط على العلامة فوق أي دورة حتى تلكاها هنا.', 'Tap the icon on any course card to keep it here.'),
            ),
            itemBuilder: (context, row, i, refresh) => CourseTileCard(
              session: widget.session,
              row: row,
              onChanged: (next) {
                if (next[kind] != true) list.currentState?.removeAt(i);
              },
            ),
          ),
        ),
      ]),
    );
  }
}
