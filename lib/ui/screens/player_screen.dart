import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/http.dart';
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
  int _attempt = 0; // cada intento invalida los anteriores (elegir otro servidor, salir)
  final _errors = <String>[]; // por qué falló cada servidor, visible en la TV
  DateTime _stageStart = DateTime.now(); // para mostrar cuánto lleva la etapa actual
  DateTime? _bufferingSince; // vigilante: stream que se queda cargando sin avanzar
  String? _streamHost; // host del m3u8/mp4 que está abriendo ExoPlayer
  Timer? _clock;
  bool _failed = false;

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
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _start();
  }

  /// Cada segundo: refresca el contador de la etapa y vigila el buffering.
  void _tick() {
    if (!mounted) return;
    final v = _controller?.value;
    if (v != null && v.isInitialized && v.isBuffering && !v.hasError) {
      _bufferingSince ??= DateTime.now();
    } else {
      _bufferingSince = null;
    }
    setState(() {});
  }

  /// Aviso del vigilante: el video abrió pero lleva rato sin recibir datos.
  String? get _stallMessage {
    final since = _bufferingSince;
    if (since == null) return null;
    final secs = DateTime.now().difference(since).inSeconds;
    if (secs < 15) return null;
    return 'Lleva $secs s cargando sin avanzar: ${_streamHost ?? 'el servidor'} no envía datos '
        '(lento, bloqueado o el enlace caducó). Pulsa ↑ para elegir otro servidor.';
  }

  void _setStage(String s) {
    debugPrint('… $s');
    _stageStart = DateTime.now();
    _setStatus(s);
  }

  Future<void> _start() async {
    _setStage('Cargando la página del episodio…');
    try {
      _servers = videoExtractor.sortByPreference(await scraper.servers(widget.episodeUrl));
    } catch (e) {
      return _fail('No se pudo cargar la página del episodio: ${_describe(e)}');
    }
    if (_servers.isEmpty) {
      return _fail('No se encontraron servidores en la página del episodio '
          '(puede que jkanime haya cambiado su HTML)');
    }

    // Prueba cada servidor hasta que uno reproduzca.
    for (final s in _servers) {
      if (!mounted) return;
      if (await _playServer(s)) return;
    }
    _fail('Ningún servidor funcionó. Pulsa ↑ para elegir otro.');
  }

  /// Estado final de error: se para el contador para que no parezca que sigue cargando.
  void _fail(String message) {
    debugPrint('✖ $message');
    _clock?.cancel();
    if (!mounted) return;
    setState(() {
      _status = message;
      _failed = true;
    });
  }

  /// Devuelve false si el servidor falló; true si reproduce o si otro intento lo reemplazó.
  Future<bool> _playServer(VideoServer server) async {
    final attempt = ++_attempt;
    bool stale() => !mounted || attempt != _attempt;

    final old = _controller;
    if (!mounted) return true;
    setState(() {
      _controller = null;
      _current = server;
      _streamHost = null;
      _failed = false;
    });
    if (!(_clock?.isActive ?? false)) _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    await old?.dispose();

    VideoPlayerController? c;
    var stage = 'buscar el enlace'; // en qué paso falló, para el mensaje de error
    try {
      _setStage('${server.name}: buscando el enlace del video…');
      // Tope global: sin él, un host lento (HTTP + WebView + ExoPlayer) deja la pantalla cargando minutos.
      final src = await videoExtractor.extract(server).timeout(const Duration(seconds: 60),
          onTimeout: () => throw const AppError('no se obtuvo el enlace en 60 s'));
      if (stale()) return true;
      debugPrint('▶ ${server.name}: $src');
      _streamHost = Uri.parse(src.url).host;
      stage = 'abrir el stream de $_streamHost';
      _setStage('${server.name}: abriendo stream ${src.isHls ? 'HLS' : 'MP4'} de $_streamHost…');
      c = VideoPlayerController.networkUrl(
        Uri.parse(src.url),
        httpHeaders: src.headers,
        formatHint: src.isHls ? VideoFormat.hls : null, // la URL de Zilla no termina en .m3u8
      );
      await c.initialize().timeout(const Duration(seconds: 30),
          onTimeout: () => throw AppError('$_streamHost no envió el video en 30 s'));
      if (stale()) {
        c.dispose();
        return true;
      }
      c.addListener(_onTick);
      setState(() => _controller = c);
      await c.play();
      _showOverlay();
      return true;
    } catch (e) {
      // Liberar siempre: las TV boxes tienen 1-2 decodificadores HW y un ExoPlayer colgado
      // hace que todos los servidores siguientes fallen al instante.
      await c?.dispose();
      debugPrint('✖ ${server.name}: $e');
      if (stale()) return true;
      _errors.add('${server.name} (al $stage): ${_describe(e)}');
      if (mounted) setState(() {});
      return false;
    }
  }

  String _describe(Object e) {
    if (e is TimeoutException) return 'tiempo de espera agotado';
    // ExoPlayer: "Source error" = HTTP/red (403, 404, TLS); "Decoder"/"MediaCodec" = la box
    // no puede decodificar el formato (p. ej. HEVC o 1080p de perfil alto).
    var s = e is PlatformException ? '${e.message ?? e.code}${e.details != null ? ' ${e.details}' : ''}' : '$e';
    if (RegExp('decoder|mediacodec', caseSensitive: false).hasMatch(s)) {
      s = 'la TV box no puede decodificar este video ($s)';
    } else if (s.contains('Source error') || s.contains('InvalidResponseCode')) {
      s = 'el servidor rechazó o cortó la descarga ($s)';
    }
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      _status = 'Error de reproducción en ${_current?.name} (${_streamHost ?? '?'}): '
          '${_describe(v.errorDescription ?? 'desconocido')}\nPulsa ↑ para elegir otro.';
    }
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
      _fail('${picked.name} no funcionó. Pulsa ↑ para elegir otro.');
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
    _attempt++; // corta el bucle de servidores en curso
    _clock?.cancel();
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
    final ready = c != null && c.value.isInitialized && !c.value.hasError;
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
                  : _loading(),
            ),
            if (ready && c.value.isBuffering)
              const Center(child: CircularProgressIndicator(color: kAccent)),
            if (ready && _stallMessage != null) _banner(_stallMessage!),
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

  /// Pantalla de carga: etapa actual con su contador y lo que falló en los servidores anteriores.
  Widget _loading() {
    final secs = DateTime.now().difference(_stageStart).inSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_failed)
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48)
        else
          const CircularProgressIndicator(color: kAccent),
        const SizedBox(height: 16),
        Text(_failed ? _status : '$_status ($secs s)',
            textAlign: TextAlign.center, style: const TextStyle(color: kTextDim)),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final e in _errors)
            Text('✖ $e', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _banner(String text) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 80, left: 48, right: 48),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amberAccent)),
        ),
      );

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
