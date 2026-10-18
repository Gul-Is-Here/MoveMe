abstract class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const otp = '/otp';
  static const commPreference = '/comm-preference';
  static const dashboard = '/dashboard';
  static const addVehicleScan = '/add-vehicle/scan';
  static const addVehicleReview = '/add-vehicle/review';
  static const vehicleDetails = '/vehicle-details';
  static const editVehicle = '/vehicle-details/edit';
  static const chatThread = '/chat-thread';
  static const qrScanner = '/qr-scanner';

  /// The admin side (ADMIN_PHONE only): Orders, Users and Profile tabs.
  static const admin = '/admin';

  /// One order on the admin side; takes the order number.
  static const adminOrder = '/admin/order';

  /// One customer on the admin side; takes [AdminUserArgs].
  static const adminUser = '/admin/user';

  /// Sticker ordering. [orderStickers] takes the starting vehicle id;
  /// [orderDetails] takes the order number.
  static const orderStickers = '/order-stickers';
  static const myOrders = '/my-orders';
  static const orderDetails = '/order-details';

  /// FR-04: the public page a QR sticker's scan URL opens — no sign-in
  /// required. `parktag.app/scan/{vehicleId}`.
  static const scanContact = '/scan/:vehicleId';
}
