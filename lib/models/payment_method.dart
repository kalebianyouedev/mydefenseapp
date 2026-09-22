enum PaymentMethod { orangeMoney, mtnMomo }

PaymentMethod paymentMethodFromString(String? raw) {
  return raw == 'momo' ? PaymentMethod.mtnMomo : PaymentMethod.orangeMoney;
}

String paymentMethodToString(PaymentMethod method) {
  return method == PaymentMethod.mtnMomo ? 'momo' : 'om';
}

String paymentMethodLabel(PaymentMethod method) {
  return method == PaymentMethod.mtnMomo ? 'MTN Mobile Money' : 'Orange Money';
}
