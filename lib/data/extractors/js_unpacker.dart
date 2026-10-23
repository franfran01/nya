/// Desempaquetador del packer de Dean Edwards: `eval(function(p,a,c,k,e,d){...}('...',62,123,'a|b|c'.split('|')...))`.
/// Muy usado por hosts de video para esconder la URL del m3u8.
class JsUnpacker {
  static final _packed = RegExp(
    r"""\}\('(.*)',\s*(\d+),\s*(\d+),\s*'(.*?)'\.split\('\|'\)""",
    dotAll: true,
  );

  static Iterable<RegExpMatch> findAll(String source) =>
      source.contains('eval(function(p,a,c,k,e,') ? _packed.allMatches(source) : const [];

  static String unpack(RegExpMatch m) {
    final payload = m.group(1)!.replaceAll(r"\'", "'");
    final radix = int.parse(m.group(2)!);
    final words = m.group(4)!.split('|');

    return payload.replaceAllMapped(RegExp(r'\b\w+\b'), (w) {
      final index = _decode(w.group(0)!, radix);
      if (index == null || index >= words.length || words[index].isEmpty) return w.group(0)!;
      return words[index];
    });
  }

  static const _alphabet = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static int? _decode(String word, int radix) {
    var n = 0;
    for (final ch in word.split('')) {
      final v = _alphabet.indexOf(ch);
      if (v < 0 || v >= radix) return null;
      n = n * radix + v;
    }
    return n;
  }
}
