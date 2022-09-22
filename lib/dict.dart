import 'dart:math';
import 'dart:typed_data';
import 'package:tuple/tuple.dart';
import 'select.dart';

class EfList {
  Uint64List b = Uint64List(0);
  int sizeLValue = 0; // bit length of a lValue
  int sizeH = 0; // bit length of the higher bits array H
  int n = 0; // number of entries in the dictionary
  int lMask = 0; // mask to isolate lValue
  int maxValue = 0; // universe of the Elias-Fano algorithm
  int pValue = 0; // previously added value: helper value to check monotonicity
  int length = 0; // number of entries that can be stored in the dictionary
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
    sizeLValue = max(0, (maxValue ~/ length).bitLength - 1);
    //Returns the minimum number of bits required to store this integer.
    sizeH = length + (maxValue >> sizeLValue).toInt();
    b = Uint64List((sizeH + length * sizeLValue + 63) >> 6);
    lMask = (1 << sizeLValue) - 1;
    int offset = sizeH;

    for (var i = 0; i < values.length; i++) {
      //higher bits processing
      int hValue = (values[i] >> sizeLValue) + i.toInt();
      b[hValue >> 6] |= 1 << (hValue & 63);
      if (sizeLValue == 0) {
        continue;
      }

      //lower bits processing
      int lValue = values[i] & lMask;
      b[offset >> 6] |= lValue << (offset & 63);
      int msb = lValue >> (64 - offset & 63);
      if (msb != 0) {
        b[offset >> 6 + 1] = msb;
      }
      offset += sizeLValue;
    }
  }

  // Value returns the k-th value in the dictionary.
  int operator [](int k) => b.hValue(k) << sizeLValue | lValue(k);

// Value2 returns the k-th value in the dictionary.
  int value(int k) => (b.select1(k) - k) << sizeLValue | lValue(k);

  int hValue2(int k) => b.select1(k) - k;

// hValue2 returns the higher bits (bucket value) of the k-th value.
  int lValue(int k) {
    int offset = sizeH + k * sizeLValue;
    int off63 = offset & 63;
    int val = b[offset >> 6] >> off63 & lMask;

    if (off63 + sizeLValue > 64) {
      val |= b[offset >> 6 + 1] << (64 - off63) & lMask;
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
    int pos63 = pos & 63;
    int pos64 = pos & ~63;

    int buf = b[pos64 >> 6] & ~(1 << pos63 - 1);
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
        pos64 += 64;
        buf = b[pos64 >> 6];
      }

      pos63 = buf.trailingZeros;

      // check potential solution
      int hVal = pos64 + pos63 - k;

      if (hValue < hVal || templValue <= lValue(k)) {
        break;
      }

      buf &= buf - 1;
      k++;
    }
    return Tuple2(k, (pos64 + pos63 - k) << sizeLValue | lValue(k));
  }

  List<int> get values {
    List<int> values = List<int>.filled(n, 0);
    int k = 0;

    if (sizeLValue == 0) {
      for (var j = 0; j < b.length; j++) {
        int p64 = j << 6;
        while (b[j] != 0) {
          values[k] = p64 + b[j].trailingZeros - k;
          b[j] &= b[j] - 1;
          k++;
        }
      }
      return values;
    }

    final hValue = Uint64List(1);
    int lValFilter = sizeH;
    Uint64List a = b.sublist(0, (sizeH + 63) >> 6);
    for (var j = 0; j < a.length; j++) {
      a[j] &= (1 << lValFilter) - 1;
      int p64 = j << 6;
      while (a[j] != 0) {
        hValue[0] = p64 + a[j].trailingZeros - k;
        values[k] = hValue[0] << sizeLValue | lValue(k);
        a[j] &= a[j] - 1;
        k++;
      }
      lValFilter -= 64;
    }
    return values;
  }
}
