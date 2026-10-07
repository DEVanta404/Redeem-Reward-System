enum PaymentMethod {
  cash('cash', 'Cash'),
  gcash('gcash', 'GCash'),
  maya('maya', 'Maya'),
  card('card', 'Card');

  final String value;
  final String label;

  const PaymentMethod(this.value, this.label);

  static PaymentMethod fromValue(String? value) => values.firstWhere(
    (method) => method.value == value?.toLowerCase(),
    orElse: () => PaymentMethod.cash,
  );
}
