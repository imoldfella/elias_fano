//import "dict.dart";
import 'dart:typed_data';
import 'package:bitcount/bitcount.dart';
export 'package:bitcount/bitcount.dart';

extension Bstr on String {
  int get b => int.parse(this, radix: 2);
}

// hValue returns the higher bit value (bucket value) of the i-th number.
extension tz on int {
  int get trailingZerosSlow =>
      toRadixString(2).split('').reversed.takeWhile((e) => e == '0').length;
  String get x => toRadixString(16);
  // https://stackoverflow.com/questions/45221914/number-of-trailing-zeroes
  int get trailingZeros {
    int bits = 0, x = this;

    if (x > 0) {
      /* assuming `x` has 32 bits: lets count the low order 0 bits in batches */
      /* mask the 16 low order bits, add 16 and shift them out if they are all 0 */
      if (0 == (x & 0x0000FFFF)) {
        bits += 16;
        x >>= 16;
      }
      /* mask the 8 low order bits, add 8 and shift them out if they are all 0 */
      if (0 == (x & 0x000000FF)) {
        bits += 8;
        x >>= 8;
      }
      /* mask the 4 low order bits, add 4 and shift them out if they are all 0 */
      if (0 == (x & 0x0000000F)) {
        bits += 4;
        x >>= 4;
      }
      /* mask the 2 low order bits, add 2 and shift them out if they are all 0 */
      if (0 == (x & 0x00000003)) {
        bits += 2;
        x >>= 2;
      }
      /* mask the low order bit and add 1 if it is 0 */
      bits += (x & 1) ^ 1;
    } else {
      return 32;
    }
    return bits;
  }
}

extension U32 on List<int> {
  Uint32List get u32 => Uint32List.fromList(this);
}

extension Bitops on Uint32List {
  List<String> get x => map((e) => e.x).toList() as List<String>;
  int hValue(int i) {
    int nOnes = i;

    for (var j = 0; j < length; j++) {
      int ones = this[j].bitCount();
      if ((i - ones) < 0) {
        return (select32(this[j], i) + (j << 6) - nOnes);
      }

      i -= ones;
    }
    return 0;
  }

  int bitCount() => map((a) => a.bitCount()).reduce((a, b) => a + b);

  // select determines the position of the jth 1.
  // this is a very slow way to do this.
  int select(int i) {
    for (var j = 0; j < length; j++) {
      int ones = this[j].bitCount();
      if ((i - ones) < 0) {
        return select32(this[j], i) + (j << 5);
      }
      i -= ones;
    }
    return 0;
  }

  select0(int i) {
    for (var j = 0; j < length; j++) {
      int xorOp = (-1 ^ this[j]) & 0xFFFFFFFF;
      int zeros = xorOp.bitCount();
      if ((i - zeros) < 0) {
        return (select32(xorOp, i) + (j << 5));
      }
      i -= zeros;
    }
    return 0;
  }
}

// count the 1 bits in the lowest k bits
int rank32(int x, int k) {
  return (x & ((1 << k) - 1)).bitCount();
}

// select is minimum postion where rank = k
// returns 31 if no position has rank = k, so that case has to be handled
int select32(int x0, int k) {
  // 01010101 = 53
  // 00110011 = 33
  // 11111111 = ff
  // 11110000 = f0
  // SWAR - fake simd https://www.playingwithpointers.com/blog/swar.html

  int x1 = (x0 & 0x5555555555555555) + ((x0 >> 1) & 0x5555555555555555);
  int x2 = (x1 & 0x3333333333333333) + ((x1 >> 2) & 0x3333333333333333);
  int x3 = (x2 & 0x0F0F0F0F0F0F0F0F) + ((x2 >> 4) & 0x0F0F0F0F0F0F0F0F);
  int x4 = (x3 & 0x00FF00FF00FF00FF) + ((x3 >> 8) & 0x00FF00FF00FF00FF);
  //int x5 = (x4 & 0x0000FFFF0000FFFF) + ((x4 >> 16) & 0x0000FFFF0000FFFF);

  int ret = 0;
  int t = 0;
  // int t = (x5 >> ret) & 0xFFFFFFFF;
  // if (t <= k) {
  //   k -= t;
  //   ret += 32;
  // }

  t = (x4 >> ret) & 0xFFFF;
  if (t <= k) {
    k -= t;
    ret += 16;
  }
  t = (x3 >> ret) & 0xFF;
  if (t <= k) {
    k -= t;
    ret += 8;
  }
  t = (x2 >> ret) & 0xF;
  if (t <= k) {
    k -= t;
    ret += 4;
  }
  t = (x1 >> ret) & 0x3;
  if (t <= k) {
    k -= t;
    ret += 2;
  }
  t = (x0 >> ret) & 0x1;
  if (t <= k) {
    k -= t;
    ret++;
  }
  return ret;
}
