import 'package:elias_fano/elias_fano.dart';

main() {
  int x = 0x7fffffffffffffff;
  int y = 9223372036854775807;

  int xx = (63).trailingZeros;
  print(xx);
  print("$x, ${x == y}");
}
