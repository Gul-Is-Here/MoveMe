/// "Rs 1,500" — rupee amounts as customers read them.
String formatRupees(int amount) {
  final digits = amount.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return 'Rs ${amount < 0 ? '-' : ''}$grouped';
}
