import 'dart:math';
import 'dart:typed_data';
import 'package:tuple/tuple.dart';
import 'select.dart';

class EfList {
  int length = 0; // number of entries that can be stored in the dictionary
  Uint32List b = Uint32List(0);
  int sizeLValue = 0; // bit length of a lValue
  int sizeH = 0; // bit length of the higher bits array H
  int lMask = 0; // mask to isolate lValue
  int maxValue = 0; // universe of the Elias-Fano algorithm
  int pValue = 0; // previously added value: helper value to check monotonicity
  // From constructs a dictionary from a list of values.
  EfList(List<int> values) {
    if (values.isEmpty) {
      return;
    }
    values.sort();
    if (values[0] < 0) {
      throw "numbers must be positive";
    }
    length = values.length;
    maxValue = values.last;
    sizeLValue = (maxValue ~/ length).bitLength;
    // https://www.antoniomallia.it/sorted-integers-compression-with-elias-fano-encoding.html says sizeH = 2n
    //sizeH = length + (maxValue >> sizeLValue);
    sizeH = 2 * length;
    b = Uint32List((sizeH + length * sizeLValue + 31) >> 5);
    lMask = (1 << sizeLValue) - 1;
    int offset = sizeH;

    for (var i = 0; i < values.length; i++) {
      //higher bits processing
      int hValue = (values[i] >> sizeLValue) + i;
      b[hValue >> 5] |= (1 << (hValue & 31));
      final checkh = this.hValue(i);
      if (checkh != (hValue - i)) {
        print("bad high bits $checkh ${hValue - i}");
      }
      if (sizeLValue == 0) {
        continue;
      }

      //lower bits processing. higher bits start at sizeH bits (after high bits)
      int lValue = values[i] & lMask; // get the low bits.
      int bytePos = offset >> 5;
      b[bytePos] |= lValue << (offset & 31); // or the bits into place

      // handle the overflow bits, if any. 32 - (offset&31) is how many bits we placed, so we shift those off. why can't lower bits be 0 though? this is a bug? no, if its zero we don't have to do anything anyway, the vector is already 0.
      int msb = lValue >> (32 - (offset & 31));
      if (msb != 0) {
        b[bytePos + 1] = msb;
      }
      final check = this.lValue(i);
      if (check != lValue) {
        print("bad $check $lValue");
      }
      offset += sizeLValue;
    }
  }

  // Value returns the  k-th value in the dictionary.
  int operator [](int k) => (b.hValue(k) << sizeLValue) | lValue(k);

  // hValue returns the higher bits (bucket value) of the k-th value.
  int hValue(int k) => b.select(k) - k;
  int lValue(int k) {
    if (0 == sizeLValue) {
      return 0;
    }
    int offset = sizeH + k * sizeLValue;
    int bytePos = offset >> 5;
    int off31 = offset & 31;
    int val = (b[bytePos] >> off31) & lMask;

    if (off31 + sizeLValue > 32) {
      val = (val | (b[bytePos + 1] << (32 - off31))) & lMask;
    }
    return val;
  }

// NextGEQ returns the first value in the dictionary equal to or larger than
// the given value. NextGEQ fails when there exists no value larger than or
// equal to value. If so, it returns -1 as index.
  Tuple2<int, int> nextGEQ(int value) {
    if (maxValue < value) {
      return Tuple2(-1, maxValue);
    }

    int hValue = (value >> sizeLValue).toInt();
    // pos denotes the end of bucket hValue-1
    int pos = b.select0(hValue);
    // k is the number of integers whose high bits are less than hValue.
    // So, k is the key of the first value we need to compare to.
    int k = pos - hValue;
    int pos31 = pos & 31;
    int pos32 = pos & ~31;

    int buf = b[pos32 >> 5] & ~(1 << pos31 - 1);
    // This does not mean that the p+1-th value is larger than or equal to value!
    // The p+1-th value has either the same hValue or a larger one. In case of a
    // larger hValue, this value is the result we are seeking for. In case the
    // hValue is identical, we need to scan the bucket to be sure that our value
    // is larger. We can do this with select1, combined with search or scanning.
    // We can also do this with scanning without select1. Most probably the
    // fastest way for regular cases.

    // scan potential solutions
    int templValue = value & lMask;

    while (true) {
      while (buf == 0) {
        pos32 += 32;
        buf = b[pos32 >> 5];
      }

      pos31 = buf.trailingZeros;

      // check potential solution
      int hVal = pos32 + pos31 - k;

      if (hValue < hVal || templValue <= lValue(k)) {
        break;
      }

      buf &= buf - 1;
      k++;
    }
    return Tuple2(k, (pos32 + pos31 - k) << sizeLValue | lValue(k));
  }

  List<int> get valuesSlow {
    List<int> values = List<int>.filled(length, 0);
    int k = 0;

    for (int i = 0; i < values.length; i++) {
      values[i] = this[i];
    }
    return values;
  }

  List<int> get values {
    List<int> values = List<int>.filled(length, 0);
    int k = 0;

    // we are iterating over high bits, each 1 that we find produces a new value
    int e = (sizeH + 31) >> 5;
    for (var j = 0; j < e; j++) {
      int bx = b[j];
      int p32 = j << 5; // counts all the bits we have passed
      while (bx != 0 && k < values.length) {
        final hv = p32 + bx.trailingZeros - k;
        if (hv != hValue(k)) {
          print("bad $hv ${hValue(k)}");
        }
        final v = (hv << sizeLValue) | lValue(k);
        if (k >= length || v != this[k]) {
          print("bad $k $length $v ${this[k]}");
        }
        values[k] = v;

        // we are removing the lowest bit that we just counted, might be clearer to use trailing zeros?
        bx = bx & (bx - 1);
        k++;
      }
    }
    return values;

    // int lValFilter = sizeH;
    // // this finds the first byte past the end of the high bits.
    // int e = (sizeH + 31) >> 5;
    // for (var j = 0; j < e; j++) {
    //   // gets a byte of the unary high bits
    //   int bx = b[j];
    //   bx = bx & ((1 << lValFilter) - 1);
    //   int p32 = j << 5;
    //   while (bx != 0) {
    //     int hValue = p32 + bx.trailingZeros - k;
    //     values[k] = (hValue << sizeLValue) | lValue(k);
    //     bx = bx & (bx - 1);
    //     k++;
    //   }
    //   lValFilter -= 32;
    // }
    // return values;
  }

  List<int> get valuesbad {
    List<int> values = List<int>.filled(length, 0);
    int k = 0;

    if (sizeLValue == 0) {
      for (var j = 0; j < b.length; j++) {
        int bx = b[j];
        int p32 = j << 5;
        while (bx != 0) {
          values[k] = p32 + b[j].trailingZeros - k;
          bx = bx & (bx - 1);
          k++;
        }
      }
      return values;
    }

    int lValFilter = sizeH;
    // this finds the first byte past the end of the high bits.
    int e = (sizeH + 31) >> 5;
    for (var j = 0; j < e; j++) {
      // gets a byte of the unary high bits
      int bx = b[j];
      bx = bx & ((1 << lValFilter) - 1);
      int p32 = j << 5;
      while (bx != 0) {
        int hValue = p32 + bx.trailingZeros - k;
        values[k] = (hValue << sizeLValue) | lValue(k);
        bx = bx & (bx - 1);
        k++;
      }
      lValFilter -= 32;
    }
    return values;
  }
}
