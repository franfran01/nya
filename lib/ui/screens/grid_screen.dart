import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';

/// Grid paginado (directorio). Carga la página siguiente al acercarse al final,
/// tanto con scroll táctil como al bajar con el D-pad (el foco hace scroll).
class GridScreen extends StatefulWidget {
  final String title;
  final Future<List<MediaCard>> Function(int page) loadPage;

  const GridScreen({super.key, required this.title, required this.loadPage});

  @override
  State<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<GridScreen> {
  final _items = <MediaCard>[];
  int _page = 0;
  bool _loading = false;
  bool _end = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    try {
      final next = await widget.loadPage(_page + 1);
      _page++;
      _end = next.isEmpty;
      _items.addAll(next.where((c) => !_items.any((e) => e.url == c.url)));
      _error = null;
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final large = isLargeScreen(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 600) _loadMore();
          return false;
        },
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: EdgeInsets.all(large ? 40 : 12),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: large ? 190 : 140,
                childAspectRatio: 0.5,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) => PosterCard(
                card: _items[i],
                autofocus: i == 0,
                onTap: () => openCard(context, _items[i]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator(color: kAccent)
                    : _error != null
                        ? TextButton(onPressed: _loadMore, child: const Text('Error. Reintentar'))
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
