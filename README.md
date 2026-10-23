<p align="center"><img src="icon.png" width="420" alt="nya"></p>

# nya

Cliente Flutter para **Android TV, Google TV y móviles** que explora y reproduce anime desde `jkanime.net`. Se maneja entero con el control remoto (D-pad).

## Descargar el APK

Los APK están en **[Releases](https://github.com/franfran01/nya/releases/latest)**. Elige el que corresponde a tu dispositivo:

| Archivo | Para |
|---|---|
| `nya-vX.Y.Z-armeabi-v7a.apk` | La mayoría de Android TV y TV boxes. Si no sabes cuál, empieza por este |
| `nya-vX.Y.Z-arm64-v8a.apk` | Teléfonos y Google TV modernos |
| `nya-vX.Y.Z-x86_64.apk` | Emuladores |

### Instalar en la TV

- **Sin cable**: en la TV, abre la app *Downloader* y escribe la URL del APK desde *Releases*. Necesitas activar "Orígenes desconocidos" para esa app.
- **Por ADB**: activa la *Depuración por red* en las opciones de desarrollador de la TV y ejecuta:

```bash
adb connect IP_DE_LA_TV:5555
```

```bash
adb install -r nya-vX.Y.Z-armeabi-v7a.apk
```

> Los APK van firmados con una clave de *debug* que cambia en cada compilación, así que para actualizar hay que **desinstalar la versión anterior** primero.

## Publicar una versión nueva

Cada tag `vX.Y.Z` dispara [GitHub Actions](.github/workflows/release.yml), que compila los APK, corre los tests y los publica en *Releases*:

```bash
git tag v1.0.1
```

```bash
git push origin v1.0.1
```

Acuérdate de subir también `version:` en `pubspec.yaml`.

## Cómo funciona

```
lib/
├── main.dart                      App + atajos del D-pad (select/OK → activar)
├── core/
│   ├── http.dart                  Cliente HTTP (User-Agent, Referer, UTF-8)
│   └── services.dart              Instancias únicas: scraper y extractor
├── data/
│   ├── models.dart                MediaCard, AnimeDetail, Episode, VideoServer, StreamSource
│   ├── jkanime_scraper.dart       Parseo HTML (inicio, directorio, búsqueda, ficha, servidores)
│   └── extractors/
│       ├── video_extractor.dart   Embed → m3u8/mp4 (por host → genérico → WebView)
│       ├── js_unpacker.dart       Desempaquetador eval(function(p,a,c,k,e,d))
│       └── webview_sniffer.dart   WebView headless que captura las peticiones .m3u8/.mp4
└── ui/
    ├── theme.dart                 Tema oscuro
    ├── navigation.dart            Episodio → reproductor, anime → ficha
    ├── widgets/                   Focusable (estados de foco), PosterCard, AsyncView
    └── screens/                   Inicio, Directorio, Buscar, Ficha, Reproductor
```

### De dónde sale el contenido

| Dato | Origen en el sitio |
|---|---|
| Últimos episodios | Portada, pestaña `#animes` → `.card > a` (img `alt` + `.badge-primary`) |
| Destacados | Carrusel `.hero__items` → `a.slider-show` |
| Directorio | `/directorio?p=N` → JSON embebido `{"current_page":…,"data":[…]}` |
| Búsqueda | `/buscar/<texto>/` → `.page_directorio .anime__item` |
| Ficha | `.anime_info h3`, `.anime_pic img`, `p.scroll`, `<li><span>Generos:</span>` |
| Episodios | URLs `/slug/N/`: N = último episodio (`#uep`) en emisión, o `Episodios:` en concluidos |
| Servidores | Propios: `video[i] = '<iframe src=…>'` · Externos: `var servers = [...]` (embed en Base64) |

### Extracción del video

1. **Desu / Magi** (propios de jkanime): el HTML del reproductor trae el `.m3u8` directo. Es **H.264 1080p + AAC**, que cualquier Android TV o Google TV decodifica por hardware. La playlist exige `Referer: https://jkanime.net/`.
2. **MP4Upload**: lee el `.mp4` del HTML del embed.
3. **Genérico**: busca `.m3u8`/`.mp4` en el HTML, también dentro de JS empaquetado.
4. **WebView headless** (Voe, Filemoon, Streamwish…): carga el embed, le da play y captura la primera petición de media.

Si un servidor falla, el reproductor prueba el siguiente de forma automática. Con **↑** eliges uno a mano.

## Compilar en local

1. Instala el **Flutter SDK** (estable, 3.47+) y **Android Studio**.
2. En Android Studio → SDK Manager → SDK Tools, marca *Android SDK Command-line Tools* y, con *Show Package Details*, **NDK 28.2.13676358**.
3. Verifica con `flutter doctor`.

Para probar en un dispositivo o emulador conectado:

```bash
flutter run
```

Para generar los APK de release, que quedan en `build/app/outputs/flutter-apk/`:

```bash
flutter build apk --release --split-per-abi
```

## Controles en TV

| Tecla | Acción |
|---|---|
| D-pad | Navegar (la tarjeta enfocada se agranda con un borde naranja) |
| OK | Abrir / reproducir / pausar |
| ← / → en el reproductor | −10 s / +10 s |
| ↑ en el reproductor | Elegir servidor |
| Canal+ / ⏭ | Siguiente episodio |
| Atrás | Volver |
