import 'package:get/get.dart';

import '../../modules/admin/bindings/admin_binding.dart';
import '../../modules/admin/admin_navigation.dart';
import '../../modules/admin/views/admin_order_view.dart';
import '../../modules/admin/views/admin_user_view.dart';
import '../../modules/admin/views/admin_view.dart';
import '../../modules/auth/bindings/auth_binding.dart';
import '../../modules/auth/views/login_view.dart';
import '../../modules/auth/views/signup_view.dart';
import '../../modules/chat/bindings/chat_thread_binding.dart';
import '../../modules/chat/views/chat_thread_view.dart';
import '../../modules/comm_preference/bindings/comm_preference_binding.dart';
import '../../modules/comm_preference/views/comm_preference_view.dart';
import '../../modules/dashboard/bindings/dashboard_binding.dart';
import '../../modules/dashboard/views/dashboard_view.dart';
import '../../modules/home/bindings/home_binding.dart';
import '../../modules/home/views/home_view.dart';
import '../../modules/onboarding/bindings/onboarding_binding.dart';
import '../../modules/onboarding/views/onboarding_view.dart';
import '../../modules/qr_scanner/bindings/qr_scanner_binding.dart';
import '../../modules/qr_scanner/views/qr_scanner_view.dart';
import '../../modules/orders/bindings/order_details_binding.dart';
import '../../modules/orders/bindings/order_form_binding.dart';
import '../../modules/orders/views/my_orders_view.dart';
import '../../modules/orders/views/order_details_view.dart';
import '../../modules/orders/views/order_form_view.dart';
import '../../modules/otp/bindings/otp_binding.dart';
import '../../modules/otp/views/otp_view.dart';
import '../../modules/scan/bindings/scan_contact_binding.dart';
import '../../modules/scan/views/scan_contact_view.dart';
import '../../modules/splash/bindings/splash_binding.dart';
import '../../modules/splash/views/splash_view.dart';
import '../../modules/vehicle/bindings/review_vehicle_binding.dart';
import '../../modules/vehicle/bindings/scan_binding.dart';
import '../../modules/vehicle/views/review_vehicle_view.dart';
import '../../modules/vehicle/views/scan_view.dart';
import '../../modules/vehicle_details/bindings/edit_vehicle_binding.dart';
import '../../modules/vehicle_details/bindings/vehicle_details_binding.dart';
import '../../modules/vehicle_details/views/edit_vehicle_view.dart';
import '../../modules/vehicle_details/views/vehicle_details_view.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = AppRoutes.splash;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.signUp,
      page: () => const SignUpView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.otp,
      page: () => const OtpView(),
      binding: OtpBinding(),
    ),
    GetPage(
      name: AppRoutes.commPreference,
      page: () => const CommPreferenceView(),
      binding: CommPreferenceBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardView(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.addVehicleScan,
      page: () => const ScanView(),
      binding: ScanBinding(),
    ),
    GetPage(
      name: AppRoutes.addVehicleReview,
      page: () => const ReviewVehicleView(),
      binding: ReviewVehicleBinding(),
    ),
    GetPage(
      name: AppRoutes.vehicleDetails,
      page: () => const VehicleDetailsView(),
      binding: VehicleDetailsBinding(),
    ),
    GetPage(
      name: AppRoutes.editVehicle,
      page: () => const EditVehicleView(),
      binding: EditVehicleBinding(),
    ),
    GetPage(
      name: AppRoutes.chatThread,
      page: () => const ChatThreadView(),
      binding: ChatThreadBinding(),
    ),
    GetPage(
      name: AppRoutes.qrScanner,
      page: () => const QrScannerView(),
      binding: QrScannerBinding(),
    ),
    GetPage(
      name: AppRoutes.admin,
      page: () => const AdminView(),
      binding: AdminBinding(),
    ),
    GetPage(
      name: AppRoutes.adminOrder,
      page: () => const AdminOrderView(),
      binding: AdminOrderBinding(),
    ),
    GetPage(
      name: AppRoutes.adminUser,
      page: () => AdminUserView(uid: (Get.arguments as AdminUserArgs).uid),
      binding: AdminUserBinding(),
    ),
    GetPage(
      name: AppRoutes.orderStickers,
      page: () => const OrderFormView(),
      binding: OrderFormBinding(),
    ),
    GetPage(
      name: AppRoutes.myOrders,
      page: () => const MyOrdersView(),
      binding: MyOrdersBinding(),
    ),
    GetPage(
      name: AppRoutes.orderDetails,
      page: () => const OrderDetailsView(),
      binding: OrderDetailsBinding(),
    ),
    GetPage(
      name: AppRoutes.scanContact,
      page: () => const ScanContactView(),
      binding: ScanContactBinding(),
    ),
  ];
}
