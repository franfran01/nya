import 'package:animeflvtv/data/extractors/js_unpacker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JsUnpacker reconstruye el JS empaquetado', () {
    const src = "eval(function(p,a,c,k,e,d){...}('0 1(\\'2\\')',62,3,'var|x|https://cdn.example/v.m3u8'.split('|'),0,{}))";
    final matches = JsUnpacker.findAll(src).toList();
    expect(matches, hasLength(1));
    expect(JsUnpacker.unpack(matches.first), "var x('https://cdn.example/v.m3u8')");
  });
}
