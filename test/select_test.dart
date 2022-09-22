import 'dart:math';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:elias_fano/elias_fano.dart';

void main() {
  final input = [234, 3458, 31000, 31009];

  final v = EfList(input).values;
  var ok = IterableEquality().equals(input, v);
  print("$ok $v");
}

void test3() {
  void show(Uint32List x, int j) {
    print("${x.x} ${x.select(j)}");
    final r = x.map((e) => e ^ 0xFFFFFFFF).toList().u32;
    print("${r.x} ${r.select0(j)}");
  }

  show([0, 2].u32, 0);
  show([0, 1 << 30].u32, 0);
  show([0, 1].u32, 0);
}

test2() {
  void show(int x, int j) {
    print("${x.x} ${select32(x, j)}, ${rank32(x, 20)}");
  }

  show(1, 0);
  show(2, 1);
  show((1 << 31) + 4, 1);
}

test1() {
  print("10101000".b.trailingZeros);

  print("${Uint32List.fromList([1, 1, 1, 3]).bitCount()}");

  final v = randomVector(10);
  final cnt = v.bitCount();

  print('$v, $cnt, ${v.select(cnt ~/ 2)}');
}

// Create a random vector with
Uint32List randomVector(int size) {
  final o = Uint32List(size);
  // for now just one's in each until
  final rnd = Random();
  for (int x = 0; x < size; x++) {
    o[x] = rnd.nextInt((1 << 32) - 1);
  }

  return o;
}

int slowSelect(Uint32List x) {
  return 0;
}
