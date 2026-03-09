import 'package:flutter/material.dart';

import '../core/widgets/feature_placeholder_screen.dart';
import '../features/ai_chat/presentation/screens/ai_chat_home_screen.dart';
import '../features/ai_chat/presentation/screens/ai_conversation_screen.dart';
import '../features/auth/domain/entities/otp_flow.dart';
import '../features/auth/presentation/screens/auth_callback_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/coach/presentation/screens/coach_dashboard_screen.dart';
import '../features/coaches/presentation/screens/coaches_screen.dart';
import '../features/member/presentation/screens/member_home_screen.dart';
import '../features/member/presentation/screens/member_profile_screen.dart';
import '../features/onboarding/presentation/screens/coach_onboarding_screen.dart';
import '../features/onboarding/presentation/screens/member_onboarding_screen.dart';
import '../features/onboarding/presentation/screens/seller_onboarding_screen.dart';
import '../features/seller/presentation/screens/seller_dashboard_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/store/presentation/screens/store_home_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String otp = '/otp';
  static const String authCallback = '/auth-callback';
  static const String roleSelection = '/role-selection';

  static const String memberOnboarding = '/member-onboarding';
  static const String sellerOnboarding = '/seller-onboarding';
  static const String coachOnboarding = '/coach-onboarding';

  static const String memberHome = '/member-home';
  static const String memberProfile = '/member-profile';
  static const String editProfile = '/edit-profile';
  static const String progress = '/progress';
  static const String workoutPlan = '/workout-plan';
  static const String workoutDetails = '/workout-details';

  static const String aiChatHome = '/ai-chat-home';
  static const String aiConversation = '/ai-conversation';
  static const String aiGeneratedPlan = '/ai-generated-plan';

  static const String storeHome = '/store-home';
  static const String productList = '/product-list';
  static const String productDetails = '/product-details';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';

  static const String coaches = '/coaches';
  static const String coachDetails = '/coach-details';
  static const String subscriptionPackages = '/subscription-packages';
  static const String mySubscriptions = '/my-subscriptions';

  static const String sellerDashboard = '/seller-dashboard';
  static const String productManagement = '/product-management';
  static const String addProduct = '/add-product';
  static const String editProduct = '/edit-product';
  static const String sellerOrders = '/seller-orders';
  static const String sellerProfile = '/seller-profile';

  static const String coachDashboard = '/coach-dashboard';
  static const String clients = '/clients';
  static const String packages = '/packages';
  static const String addPackage = '/add-package';
  static const String coachProfile = '/coach-profile';

  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String helpSupport = '/help-support';
  static const String privacyPolicy = '/privacy-policy';
  static const String terms = '/terms';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (_isOAuthCallbackRoute(settings.name)) {
      return _buildRoute(AuthCallbackScreen(routeName: settings.name));
    }

    switch (settings.name) {
      case splash:
        return _buildRoute(const SplashScreen());
      case welcome:
        return _buildRoute(const WelcomeScreen());
      case login:
        return _buildRoute(const LoginScreen());
      case register:
        return _buildRoute(const RegisterScreen());
      case forgotPassword:
        return _buildRoute(const ForgotPasswordScreen());
      case otp:
        final args = settings.arguments;
        if (args is OtpFlowArgs) {
          return _buildRoute(OtpScreen(email: args.email, mode: args.mode));
        }
        final email = args as String? ?? '';
        return _buildRoute(OtpScreen(email: email, mode: OtpFlowMode.signup));
      case authCallback:
        return _buildRoute(const AuthCallbackScreen());
      case roleSelection:
        return _buildRoute(const RoleSelectionScreen());

      case memberOnboarding:
        return _buildRoute(const MemberOnboardingScreen());
      case sellerOnboarding:
        return _buildRoute(const SellerOnboardingScreen());
      case coachOnboarding:
        return _buildRoute(const CoachOnboardingScreen());

      case memberHome:
        return _buildRoute(const MemberHomeScreen());
      case memberProfile:
        return _buildRoute(const MemberProfileScreen());
      case editProfile:
        return _featureRoute(
          title: 'Edit Profile',
          description:
              'Profile editing will connect to your Supabase profile data and avatar storage once that setup is finalized.',
          icon: Icons.person_outline,
        );
      case progress:
        return _featureRoute(
          title: 'Progress Tracking',
          description:
              'Progress analytics will summarize workouts, streaks, measurements, and milestones after tracking data is connected.',
          icon: Icons.trending_up,
        );
      case workoutPlan:
        return _featureRoute(
          title: 'Workout Plans',
          description:
              'Coach-authored plans and AI plans will live here together once workout persistence is fully wired.',
          icon: Icons.fitness_center,
        );
      case workoutDetails:
        return _featureRoute(
          title: 'Workout Details',
          description:
              'Detailed exercise steps, sets, reps, and notes will appear here when workout content is ready.',
          icon: Icons.list_alt,
        );

      case aiChatHome:
        return _buildRoute(const AiChatHomeScreen());
      case aiConversation:
        final sessionId = settings.arguments as String?;
        return _buildRoute(AiConversationScreen(sessionId: sessionId));
      case aiGeneratedPlan:
        return _featureRoute(
          title: 'AI Generated Plan',
          description:
              'AI plans will appear here after the chat flow is connected to workout plan persistence.',
          icon: Icons.auto_awesome,
        );

      case storeHome:
        return _buildRoute(const StoreHomeScreen());
      case productList:
        return _featureRoute(
          title: 'Product Catalog',
          description:
              'Expanded product browsing, search results, and filters will appear here when storefront flows are completed.',
          icon: Icons.storefront_outlined,
        );
      case productDetails:
        return _featureRoute(
          title: 'Product Details',
          description:
              'Product specs, reviews, and purchase details will appear here when the product page is fully wired.',
          icon: Icons.inventory_2_outlined,
        );
      case cart:
        return _featureRoute(
          title: 'Shopping Cart',
          description:
              'Selected items will be reviewed here before checkout once cart state is connected.',
          icon: Icons.shopping_cart_outlined,
        );
      case checkout:
        return _featureRoute(
          title: 'Checkout',
          description:
              'Payment, address, and confirmation steps will be enabled here after checkout integration is complete.',
          icon: Icons.credit_card_outlined,
        );
      case orders:
        return _featureRoute(
          title: 'My Orders',
          description:
              'Order history and fulfillment updates will appear here after member order queries are connected.',
          icon: Icons.shopping_bag_outlined,
        );

      case coaches:
        return _buildRoute(const CoachesScreen());
      case coachDetails:
        return _featureRoute(
          title: 'Coach Details',
          description:
              'Coach bios, availability, and trust signals will open here when coach profile flows are finished.',
          icon: Icons.groups_outlined,
        );
      case subscriptionPackages:
        return _featureRoute(
          title: 'Subscription Packages',
          description:
              'Coach pricing tiers and program packages will appear here when subscriptions are wired for members.',
          icon: Icons.card_membership,
        );
      case mySubscriptions:
        return _featureRoute(
          title: 'My Subscriptions',
          description:
              'Your active and past subscriptions will appear here after the member subscription experience is implemented.',
          icon: Icons.workspace_premium_outlined,
        );

      case sellerDashboard:
        return _buildRoute(const SellerDashboardScreen());
      case productManagement:
        return _featureRoute(
          title: 'Product Management',
          description:
              'Inventory controls, publishing state, and stock updates will be managed here for sellers.',
          icon: Icons.inventory_2_outlined,
        );
      case addProduct:
        return _featureRoute(
          title: 'Add Product',
          description:
              'Sellers will create new listings here with pricing, media, stock, and category details.',
          icon: Icons.add_box_outlined,
        );
      case editProduct:
        return _featureRoute(
          title: 'Edit Product',
          description:
              'Existing product listings will be updated here once product editing flows are completed.',
          icon: Icons.edit_outlined,
        );
      case sellerOrders:
        return _featureRoute(
          title: 'Seller Orders',
          description:
              'Incoming orders, status updates, and fulfillment actions will be managed here for the seller.',
          icon: Icons.receipt_long_outlined,
        );
      case sellerProfile:
        return _featureRoute(
          title: 'Seller Profile',
          description:
              'Store branding, business details, and seller settings will be managed here.',
          icon: Icons.store_mall_directory_outlined,
        );

      case coachDashboard:
        return _buildRoute(const CoachDashboardScreen());
      case clients:
        return _featureRoute(
          title: 'Client Management',
          description:
              'Client roster, progress visibility, and coaching actions will appear here after coach flows are connected.',
          icon: Icons.groups_outlined,
        );
      case packages:
        return _featureRoute(
          title: 'Coaching Packages',
          description:
              'Coach package pricing and plan bundles will be configured here once package persistence is connected.',
          icon: Icons.inventory_outlined,
        );
      case addPackage:
        return _featureRoute(
          title: 'Create Package',
          description:
              'Coaches will create new subscription packages here once package publishing is connected.',
          icon: Icons.add_circle_outline,
        );
      case coachProfile:
        return _featureRoute(
          title: 'Coach Profile',
          description:
              'Public coach profile details, specialties, and visibility settings will be managed here.',
          icon: Icons.person_outline,
        );

      case notifications:
        return _featureRoute(
          title: 'Notifications',
          description:
              'Alerts, order updates, and coaching notifications will be organized here once notification delivery is connected.',
          icon: Icons.notifications_outlined,
        );
      case AppRoutes.settings:
        return _buildRoute(const SettingsScreen());
      case helpSupport:
        return _featureRoute(
          title: 'Help & Support',
          description:
              'FAQs, support contact options, and issue reporting will appear here after support content is prepared.',
          icon: Icons.help_outline,
        );
      case privacyPolicy:
        return _featureRoute(
          title: 'Privacy Policy',
          description:
              'Your product privacy policy and data-handling commitments will be presented here.',
          icon: Icons.privacy_tip_outlined,
        );
      case terms:
        return _featureRoute(
          title: 'Terms of Service',
          description:
              'Platform usage terms for members, coaches, and sellers will be shown here.',
          icon: Icons.description_outlined,
        );

      default:
        return _featureRoute(
          title: 'Unknown Route',
          description:
              'The app tried to open "${settings.name}", but there is no configured screen for it yet.',
          icon: Icons.route_outlined,
        );
    }
  }

  static MaterialPageRoute _buildRoute(Widget page) {
    return MaterialPageRoute(builder: (_) => page);
  }

  static MaterialPageRoute _featureRoute({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return _buildRoute(
      FeaturePlaceholderScreen(
        title: title,
        description: description,
        icon: icon,
      ),
    );
  }

  static bool _isOAuthCallbackRoute(String? routeName) {
    if (routeName == null || routeName.isEmpty) {
      return false;
    }
    final isQueryOrFragmentRoute =
        routeName.startsWith('/?') || routeName.startsWith('/#');
    if (!isQueryOrFragmentRoute) {
      return false;
    }
    return routeName.contains('code=') ||
        routeName.contains('access_token=') ||
        routeName.contains('refresh_token=') ||
        routeName.contains('error=');
  }
}
