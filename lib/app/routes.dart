import 'package:flutter/material.dart';

import '../core/widgets/feature_placeholder_screen.dart';
import '../features/ai_chat/presentation/screens/ai_chat_home_screen.dart';
import '../features/ai_chat/presentation/screens/ai_conversation_screen.dart';
import '../features/auth/domain/entities/otp_flow.dart';
import '../features/auth/presentation/screens/auth_callback_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/otp_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/coach/presentation/screens/coach_dashboard_screen.dart';
import '../features/coach/presentation/screens/coach_clients_screen.dart';
import '../features/coach/presentation/screens/coach_package_editor_screen.dart';
import '../features/coach/presentation/screens/coach_packages_screen.dart';
import '../features/coaches/presentation/screens/coaches_screen.dart';
import '../features/coaches/presentation/screens/coach_details_screen.dart';
import '../features/coaches/presentation/screens/subscription_packages_screen.dart';
import '../features/member/presentation/screens/member_home_screen.dart';
import '../features/member/presentation/screens/edit_profile_screen.dart';
import '../features/member/presentation/screens/member_profile_screen.dart';
import '../features/member/presentation/screens/member_checkins_screen.dart';
import '../features/member/presentation/screens/member_messages_screen.dart';
import '../features/member/presentation/screens/my_subscriptions_screen.dart';
import '../features/member/presentation/screens/progress_screen.dart';
import '../features/monetization/presentation/screens/ai_premium_paywall_screen.dart';
import '../features/monetization/presentation/screens/subscription_management_screen.dart';
import '../features/news/domain/entities/news_article.dart';
import '../features/news/presentation/screens/news_article_details_screen.dart';
import '../features/news/presentation/screens/news_feed_screen.dart';
import '../features/nutrition/presentation/screens/meal_plan_screen.dart';
import '../features/nutrition/presentation/screens/nutrition_home_screen.dart';
import '../features/nutrition/presentation/screens/nutrition_insights_screen.dart';
import '../features/nutrition/presentation/screens/nutrition_preferences_screen.dart';
import '../features/nutrition/presentation/screens/nutrition_setup_screen.dart';
import '../features/onboarding/presentation/screens/coach_onboarding_screen.dart';
import '../features/onboarding/presentation/screens/member_onboarding_screen.dart';
import '../features/onboarding/presentation/screens/seller_onboarding_screen.dart';
import '../features/planner/presentation/route_args.dart';
import '../features/planner/presentation/screens/ai_generated_plan_screen.dart';
import '../features/planner/presentation/screens/planner_builder_screen.dart';
import '../features/planner/presentation/screens/workout_day_details_screen.dart';
import '../features/planner/presentation/screens/workout_plan_screen.dart';
import '../features/seller/presentation/screens/seller_dashboard_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/notifications_screen.dart';
import '../features/settings/presentation/screens/support_and_legal_screens.dart';
import '../features/settings/presentation/screens/delete_account_screen.dart';
import '../features/store/domain/entities/product_entity.dart';
import '../features/store/presentation/screens/cart_screen.dart';
import '../features/store/presentation/screens/checkout_preview_screen.dart';
import '../features/store/presentation/screens/favorites_screen.dart';
import '../features/store/presentation/screens/my_orders_screen.dart';
import '../features/store/presentation/screens/product_details_screen.dart';
import '../features/store/presentation/screens/store_catalog_screen.dart';
import '../features/store/presentation/screens/store_home_screen.dart';
import '../features/coach/domain/entities/coach_entity.dart';
import '../features/member/domain/entities/coaching_engagement_entity.dart';
import '../features/seller/presentation/screens/seller_orders_screen.dart';
import '../features/seller/presentation/screens/seller_product_editor_screen.dart';
import '../features/seller/presentation/screens/seller_product_management_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
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
  static const String aiPlannerBuilder = '/ai-planner-builder';
  static const String aiGeneratedPlan = '/ai-generated-plan';
  static const String aiPremiumPaywall = '/ai-premium';
  static const String subscriptionManagement = '/subscription-management';
  static const String nutrition = '/nutrition';
  static const String nutritionSetup = '/nutrition-setup';
  static const String nutritionMealPlan = '/nutrition-meal-plan';
  static const String nutritionPreferences = '/nutrition-preferences';
  static const String nutritionInsights = '/nutrition-insights';
  static const String newsFeed = '/news-feed';
  static const String newsArticleDetails = '/news-article-details';

  static const String storeHome = '/store-home';
  static const String productList = '/product-list';
  static const String productDetails = '/product-details';
  static const String favorites = '/favorites';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';

  static const String coaches = '/coaches';
  static const String coachDetails = '/coach-details';
  static const String subscriptionPackages = '/subscription-packages';
  static const String mySubscriptions = '/my-subscriptions';
  static const String memberCheckins = '/member-checkins';
  static const String memberMessages = '/member-messages';
  static const String memberThread = '/member-thread';

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
  static const String deleteAccount = '/delete-account';
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
      case resetPassword:
        return _buildRoute(const ResetPasswordScreen());
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
        return _buildRoute(const EditProfileScreen());
      case progress:
        return _buildRoute(const ProgressScreen());
      case workoutPlan:
        final args = settings.arguments;
        return _buildRoute(
          WorkoutPlanScreen(
            planId: args is WorkoutPlanArgs ? args.planId : null,
          ),
        );
      case workoutDetails:
        final args = settings.arguments;
        if (args is WorkoutDayArgs) {
          return _buildRoute(
            WorkoutDayDetailsScreen(planId: args.planId, dayId: args.dayId),
          );
        }
        return _featureRoute(
          title: 'Workout Details',
          description:
              'A plan day id is required to open task details from the active planner.',
          icon: Icons.list_alt,
        );

      case aiChatHome:
        return _buildRoute(const AiChatHomeScreen());
      case aiConversation:
        final sessionId = settings.arguments as String?;
        return _buildRoute(AiConversationScreen(sessionId: sessionId));
      case aiPlannerBuilder:
        final args = settings.arguments;
        return _buildRoute(
          PlannerBuilderScreen(
            seedPrompt: args is PlannerBuilderArgs ? args.seedPrompt : null,
            existingSessionId: args is PlannerBuilderArgs
                ? args.existingSessionId
                : null,
          ),
        );
      case aiGeneratedPlan:
        final args = settings.arguments;
        if (args is AiGeneratedPlanArgs) {
          return _buildRoute(
            AiGeneratedPlanScreen(
              sessionId: args.sessionId,
              draftId: args.draftId,
            ),
          );
        }
        return _featureRoute(
          title: 'AI Generated Plan',
          description:
              'A draft id is required to review and activate an AI-generated plan.',
          icon: Icons.auto_awesome,
        );
      case aiPremiumPaywall:
        return _buildRoute(const AiPremiumPaywallScreen());
      case subscriptionManagement:
        return _buildRoute(const SubscriptionManagementScreen());
      case nutrition:
        return _buildRoute(const NutritionHomeScreen());
      case nutritionSetup:
        return _buildRoute(const NutritionSetupScreen());
      case nutritionMealPlan:
        return _buildRoute(const MealPlanScreen());
      case nutritionPreferences:
        return _buildRoute(const NutritionPreferencesScreen());
      case nutritionInsights:
        return _buildRoute(const NutritionInsightsScreen());
      case newsFeed:
        return _buildRoute(const NewsFeedScreen());
      case newsArticleDetails:
        final args = settings.arguments;
        if (args is NewsArticleEntity) {
          return _buildRoute(NewsArticleDetailsScreen(initialArticle: args));
        }
        return _buildRoute(
          NewsArticleDetailsScreen(articleId: args as String?),
        );

      case storeHome:
        return _buildRoute(const StoreHomeScreen());
      case productList:
        return _buildRoute(const StoreCatalogScreen());
      case productDetails:
        final product = settings.arguments;
        return _buildRoute(
          ProductDetailsScreen(
            product: product is ProductEntity ? product : null,
          ),
        );
      case favorites:
        return _buildRoute(const FavoritesScreen());
      case cart:
        return _buildRoute(const CartScreen());
      case checkout:
        return _buildRoute(const CheckoutScreen());
      case orders:
        return _buildRoute(const MyOrdersScreen());

      case coaches:
        return _buildRoute(const CoachesScreen());
      case coachDetails:
        final coach = settings.arguments;
        return _buildRoute(
          CoachDetailsScreen(coach: coach is CoachEntity ? coach : null),
        );
      case subscriptionPackages:
        final coach = settings.arguments;
        return _buildRoute(
          SubscriptionPackagesScreen(
            coach: coach is CoachEntity ? coach : null,
          ),
        );
      case mySubscriptions:
        return _buildRoute(const MySubscriptionsScreen());
      case memberCheckins:
        return _buildRoute(const MemberCheckinsScreen());
      case memberMessages:
        return _buildRoute(const MemberMessagesScreen());
      case memberThread:
        final thread = settings.arguments;
        if (thread is CoachingThreadEntity) {
          return _buildRoute(MemberThreadScreen(thread: thread));
        }
        return _featureRoute(
          title: 'Messages',
          description: 'A coaching thread is required to open this screen.',
          icon: Icons.chat_bubble_outline,
        );

      case sellerDashboard:
        return _buildRoute(const SellerDashboardScreen());
      case productManagement:
        return _buildRoute(const SellerProductManagementScreen());
      case addProduct:
        return _buildRoute(const SellerProductEditorScreen());
      case editProduct:
        final product = settings.arguments;
        return _buildRoute(
          SellerProductEditorScreen(
            product: product is ProductEntity ? product : null,
          ),
        );
      case sellerOrders:
        return _buildRoute(const SellerOrdersScreen());
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
        return _buildRoute(const CoachClientsScreen());
      case packages:
        return _buildRoute(const CoachPackagesScreen());
      case addPackage:
        final package = settings.arguments;
        return _buildRoute(
          CoachPackageEditorScreen(
            initialPackage: package is CoachPackageEntity ? package : null,
          ),
        );
      case coachProfile:
        return _featureRoute(
          title: 'Coach Profile',
          description:
              'Public coach profile details, specialties, and visibility settings will be managed here.',
          icon: Icons.person_outline,
        );

      case notifications:
        return _buildRoute(const NotificationsScreen());
      case AppRoutes.settings:
        return _buildRoute(const SettingsScreen());
      case deleteAccount:
        return _buildRoute(const DeleteAccountScreen());
      case helpSupport:
        return _buildRoute(const HelpSupportScreen());
      case privacyPolicy:
        return _buildRoute(const PrivacyPolicyScreen());
      case terms:
        return _buildRoute(const TermsScreen());

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
