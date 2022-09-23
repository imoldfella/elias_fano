import 'dart:math';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:elias_fano/elias_fano.dart';

void main() {
  final n = 1000;
  final max = 100;
  final iterations = 1000;
  var a = List<int>.filled(n, 0);

  for (var k = 0; k < iterations; k++) {
    final inp = a.sublist(0, 1 + Random().nextInt(max));
    int prev = 0;

    // creates a random sorted vector
    for (var i = 0; i < inp.length; i++) {
      prev += Random().nextInt(max);
      inp[i] = prev;
    }

    EfList d = EfList(inp);
    var r = checkLowBits(inp, d) &&
        checkHighBits(inp, d) &&
        IterableEquality().equals(inp, d.valuesSlow);
    if (!r) {
      print("boo");
    }
  }
}

void test4() {
  final input = [234, 3458, 31000, 31009];
  //final input = [2, 3, 5, 7, 11, 13, 24];

  final v = EfList(input);
  checkLowBits(input, v);
  checkHighBits(input, v);
  var ok = IterableEquality().equals(input, v.values);
  print("$ok ${v.values}");
}

bool checkLowBits(List<int> input, EfList v) {
  for (int i = 0; i < input.length; i++) {
    final a = input[i] & v.lMask;
    final b = v.lValue(i);
    if (a != b) {
      print("bad $a $b");
      return false;
    }
  }
  return true;
}

bool checkHighBits(List<int> input, EfList v) {
  for (int i = 0; i < input.length; i++) {
    final a = input[i] >> v.sizeLValue;
    final b = v.hValue(i);
    if (a != b) {
      print("bad $a $b");
      return false;
    }
  }
  return true;
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
