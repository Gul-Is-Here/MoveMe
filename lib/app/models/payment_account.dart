/// An account customers pay sticker orders into (EasyPaisa, JazzCash or a
/// bank), managed by the admin. Only [active] ones are shown to customers.
class PaymentAccount {
  const PaymentAccount({
    this.id = '',
    required this.method,
    required this.accountNumber,
    required this.accountTitle,
    this.active = true,
  });

  static const methods = ['EasyPaisa', 'JazzCash', 'Bank account'];

  final String id;
  final String method;
  final String accountNumber;
  final String accountTitle;
  final bool active;

  factory PaymentAccount.fromMap(String id, Map<String, dynamic> data) => PaymentAccount(
        id: id,
        method: data['method'] as String? ?? '',
        accountNumber: data['accountNumber'] as String? ?? '',
        accountTitle: data['accountTitle'] as String? ?? '',
        active: data['active'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'method': method,
        'accountNumber': accountNumber,
        'accountTitle': accountTitle,
        'active': active,
      };

  PaymentAccount copyWith({bool? active}) => PaymentAccount(
        id: id,
        method: method,
        accountNumber: accountNumber,
        accountTitle: accountTitle,
        active: active ?? this.active,
      );
}
