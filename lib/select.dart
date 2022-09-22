//import "dict.dart";
import 'dart:typed_data';
import 'package:bitcount/bitcount.dart';

// hValue returns the higher bit value (bucket value) of the i-th number.
extension tz on int {
  int get trailingZeros =>
      toRadixString(2).split('').reversed.takeWhile((e) => e == '0').length;
}

extension Bitops on Uint64List {
  int hValue(int i) {
    int nOnes = i;

    for (var j = 0; j < length; j++) {
      int ones = this[j].bitCount();
      if ((i - ones) < 0) {
        return (select64(this[j], i) + (j << 6) - nOnes);
      }

      i -= ones;
    }
    return 0;
  }

  int select1(int i) {
    for (var j = 0; j < length; j++) {
      int ones = this[j].bitCount();
      if ((i - ones) < 0) {
        return (select64(this[j], i) + j << 6);
      }
      i -= ones;
    }
    return 0;
  }

  select0(int i) {
    for (var j = 0; j < length; j++) {
      int xorOp = -1 ^ this[j];
      int zeros = xorOp.bitCount();
      if ((i - zeros) < 0) {
        return (select64(xorOp, i) + j << 6);
      }
      i -= zeros;
    }
    return 0;
  }
}

int select64(int x0, int k) {
  int x1 = (x0 & 0x5555555555555555) + (x0 >> 1 & 0x5555555555555555);
  int x2 = (x1 & 0x3333333333333333) + (x1 >> 2 & 0x3333333333333333);
  int x3 = (x2 & 0x0F0F0F0F0F0F0F0F) + (x2 >> 4 & 0x0F0F0F0F0F0F0F0F);
  int x4 = (x3 & 0x00FF00FF00FF00FF) + (x3 >> 8 & 0x00FF00FF00FF00FF);
  int x5 = (x4 & 0x0000FFFF0000FFFF) + (x4 >> 16 & 0x0000FFFF0000FFFF);

  int ret = 0;
  int t = x5 >> ret & 0xFFFFFFFF;
  if (t <= k) {
    k -= t;
    ret += 32;
  }
  t = x4 >> ret & 0xFFFF;
  if (t <= k) {
    k -= t;
    ret += 16;
  }
  t = x3 >> ret & 0xFF;
  if (t <= k) {
    k -= t;
    ret += 8;
  }
  t = x2 >> ret & 0xF;
  if (t <= k) {
    k -= t;
    ret += 4;
  }
  t = x1 >> ret & 0x3;
  if (t <= k) {
    k -= t;
    ret += 2;
  }
  t = x0 >> ret & 0x1;
  if (t <= k) {
    k -= t;
    ret++;
  }
  return ret;
}
