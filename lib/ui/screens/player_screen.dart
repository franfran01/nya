import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/services.dart';
import '../../data/models.dart';
import '../theme.dart';

/// Reproductor a pantalla completa (ExoPlayer/Media3 vía video_player, decodificación HW).
///
/// Mando de Android TV:
///   OK / Play-Pause ........ reproducir / pausar
///   ← / → .................. -10 s / +10 s   (Rew / FF del mando: ±30 s)
///   ↑ ...................... elegir servidor
///   ↓ ...................... mostrar controles
///   Canal+ / Siguiente ..... siguiente episodio
///   Atrás .................. salir
class PlayerScreen extends StatefulWidget {
  final String title;
  final String episodeUrl;
  final List<Episode>? playlist; // para "siguiente episodio"
  final String? animeTitle;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.episodeUrl,
    this.playlist,
    this.animeTitle,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  List<VideoServer> _servers = [];
  VideoServer? _current;
  String _status = 'Buscando servidores…';
  bool _overlay = true;
  Timer? _hideTimer;
  bool _advanced = false;

  Episode? get _next {
    final list = widget.playlist;
    if (list == null) return null;
    final i = list.indexWhere((e) => e.url == widget.episodeUrl);
    return (i >= 0 && i + 1 < list.length) ? list[i + 1] : null;
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _start();
  }

  Future<void> _start() async {
    try {
      _servers = videoExtractor.sortByPreference(await scraper.servers(widget.episodeUrl));
    } catch (e) {
      return _setStatus('Error al cargar el episodio: $e');
    }
    if (_servers.isEmpty) return _setStatus('Este episodio no tiene servidores');

    // Prueba cada servidor hasta que uno reproduzca.
    for (final s in _servers) {
      if (!mounted) return;
      if (await _playServer(s)) return;
    }
    _setStatus('Ningún servidor funcionó. Pulsa ↑ para elegir otro.');
  }

  Future<bool> _playServer(VideoServer server) async {
    _setStatus('Conectando con ${server.name}…');
    final old = _controller;
    setState(() {
      _controller = null;
      _current = server;
    });
    await old?.dispose();

    try {
      final src = await videoExtractor.extract(server);
      debugPrint('▶ ${server.name}: $src');
      final c = VideoPlayerController.networkUrl(
        Uri.parse(src.url),
        httpHeaders: src.headers,
        formatHint: src.isHls ? VideoFormat.hls : null, // la URL de Zilla no termina en .m3u8
      );
      await c.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) {
        c.dispose();
        return true;
      }
      c.addListener(_onTick);
      setState(() => _controller = c);
      await c.play();
      _showOverlay();
      return true;
    } catch (e) {
      debugPrint('✖ ${server.name}: $e');
      return false;
    }
  }

  void _onTick() {
    final v = _controller!.value;
    if (!_advanced && v.isInitialized && v.duration > Duration.zero && v.position >= v.duration) {
      _advanced = true;
      _goNext();
    }
    if (mounted) setState(() {});
  }

  void _goNext() {
    final next = _next;
    if (next == null) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        title: '${widget.animeTitle ?? ''} · Episodio ${next.number}',
        episodeUrl: next.url,
        playlist: widget.playlist,
        animeTitle: widget.animeTitle,
      ),
    ));
  }

  void _setStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  void _showOverlay() {
    setState(() => _overlay = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) setState(() => _overlay = false);
    });
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
    _showOverlay();
  }

  void _seek(int seconds) {
    final c = _controller;
    if (c == null) return;
    final target = c.value.position + Duration(seconds: seconds);
    c.seekTo(target < Duration.zero ? Duration.zero : target);
    _showOverlay();
  }

  Future<void> _pickServer() async {
    if (_servers.isEmpty) return;
    final picked = await showDialog<VideoServer>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: kSurface,
        title: const Text('Servidor'),
        children: [
          for (final (i, s) in _servers.indexed)
            ListTile(
              autofocus: s == _current || (i == 0 && _current == null),
              title: Text('${s.name} (${s.lang})'),
              trailing: s == _current ? const Icon(Icons.check, color: kAccent) : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (picked != null && !await _playServer(picked)) {
      _setStatus('${picked.name} no funcionó. Pulsa ↑ para elegir otro.');
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.mediaPlayPause) {
      if (e is KeyDownEvent) _togglePlay(); // no repetir al mantener pulsado
    } else if (k == LogicalKeyboardKey.mediaPlay) {
      _controller?.play();
    } else if (k == LogicalKeyboardKey.mediaPause) {
      _controller?.pause();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _seek(-10);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _seek(10);
    } else if (k == LogicalKeyboardKey.mediaRewind) {
      _seek(-30);
    } else if (k == LogicalKeyboardKey.mediaFastForward) {
      _seek(30);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      if (e is KeyDownEvent) _pickServer();
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _showOverlay();
    } else if (k == LogicalKeyboardKey.channelUp || k == LogicalKeyboardKey.mediaTrackNext) {
      if (e is KeyDownEvent) _goNext();
    } else {
      return KeyEventResult.ignored; // Atrás lo gestiona el Navigator
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _overlay ? setState(() => _overlay = false) : _showOverlay(),
          onDoubleTapDown: (d) =>
              _seek(d.localPosition.dx < MediaQuery.sizeOf(context).width / 2 ? -10 : 10),
          onDoubleTap: () {},
          child: Stack(fit: StackFit.expand, children: [
            Center(
              child: ready
                  ? AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(color: kAccent),
                      const SizedBox(height: 16),
                      Text(_status, style: const TextStyle(color: kTextDim)),
                    ]),
            ),
            if (ready && c.value.isBuffering)
              const Center(child: CircularProgressIndicator(color: kAccent)),
            AnimatedOpacity(
              opacity: _overlay || !ready ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              // ExcludeFocus: en TV todo se maneja con teclas (_onKey); los botones son para táctil.
              child: IgnorePointer(
                ignoring: !_overlay,
                child: ExcludeFocus(child: _controls(ready ? c : null)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _controls(VideoPlayerController? c) {
    final v = c?.value;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent, Colors.transparent, Colors.black87],
          stops: [0, 0.25, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: _pickServer,
                icon: const Icon(Icons.dns_outlined),
                label: Text(_current?.name ?? 'Servidor'),
              ),
            ]),
            const Spacer(),
            if (v != null) ...[
              VideoProgressIndicator(
                c!,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                colors: const VideoProgressColors(
                  playedColor: kAccent,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white12,
                ),
              ),
              Row(children: [
                IconButton(
                  iconSize: 40,
                  onPressed: _togglePlay,
                  icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                Text('${_fmt(v.position)} / ${_fmt(v.duration)}'),
                const Spacer(),
                const Text('← → 10 s   ↑ servidor   OK pausa',
                    style: TextStyle(color: kTextDim, fontSize: 12)),
                if (_next != null) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _goNext,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Siguiente'),
                  ),
                ],
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
