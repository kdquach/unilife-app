import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  static String vnd(int amount) => '${_formatter.format(amount)}đ';
}
