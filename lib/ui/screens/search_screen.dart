import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../data/models.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/poster_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _firstResult = FocusNode();
  List<MediaCard>? _results;
  bool _loading = false;
  String? _error;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await scraper.search(q);
      setState(() => _results = r);
      // En TV, tras "Buscar" en el teclado en pantalla el foco salta al primer resultado.
      if (r.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _firstResult.requestFocus());
      }
    } catch (e) {
      setState(() => _error = '$e');
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _firstResult.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final large = isLargeScreen(context);
    final pad = large ? 40.0 : 12.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: const InputDecoration(
              hintText: 'Nombre del anime…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(color: kAccent),
        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
        if (_results != null && _results!.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Sin resultados', style: TextStyle(color: kTextDim)),
          ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(pad),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: large ? 190 : 140,
              childAspectRatio: 0.5,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
            ),
            itemCount: _results?.length ?? 0,
            itemBuilder: (context, i) => PosterCard(
              card: _results![i],
              focusNode: i == 0 ? _firstResult : null,
              onTap: () => openCard(context, _results![i]),
            ),
          ),
        ),
      ]),
    );
  }
}
