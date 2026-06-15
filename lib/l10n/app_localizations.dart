import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @accountActions.
  ///
  /// In en, this message translates to:
  /// **'Account Actions'**
  String get accountActions;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @settingsLoadError.
  ///
  /// In en, this message translates to:
  /// **'GymUnity could not load your settings right now.'**
  String get settingsLoadError;

  /// No description provided for @settingsSaveError.
  ///
  /// In en, this message translates to:
  /// **'GymUnity could not save that preference.'**
  String get settingsSaveError;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @coachProfile.
  ///
  /// In en, this message translates to:
  /// **'Coach Profile'**
  String get coachProfile;

  /// No description provided for @storeProfile.
  ///
  /// In en, this message translates to:
  /// **'Store Profile'**
  String get storeProfile;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send key updates outside the app when possible.'**
  String get pushNotificationsSubtitle;

  /// No description provided for @taiyoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'TAIYO Suggestions'**
  String get taiyoSuggestions;

  /// No description provided for @taiyoSuggestionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight new coaching or workout ideas from TAIYO.'**
  String get taiyoSuggestionsSubtitle;

  /// No description provided for @orderUpdates.
  ///
  /// In en, this message translates to:
  /// **'Order Updates'**
  String get orderUpdates;

  /// No description provided for @orderUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep store order and delivery status visible in notifications.'**
  String get orderUpdatesSubtitle;

  /// No description provided for @measurementUnits.
  ///
  /// In en, this message translates to:
  /// **'Measurement Units'**
  String get measurementUnits;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @notificationsCenter.
  ///
  /// In en, this message translates to:
  /// **'Notifications Center'**
  String get notificationsCenter;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @logOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logOutQuestion;

  /// No description provided for @logoutReturnMessage.
  ///
  /// In en, this message translates to:
  /// **'You will return to the login screen.'**
  String get logoutReturnMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'GymUnity v1.0.0'**
  String get appVersion;

  /// No description provided for @welcomeEyebrow.
  ///
  /// In en, this message translates to:
  /// **'WELCOME'**
  String get welcomeEyebrow;

  /// No description provided for @welcomeHeadlineYour.
  ///
  /// In en, this message translates to:
  /// **'Your'**
  String get welcomeHeadlineYour;

  /// No description provided for @welcomeHeadlineFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness,'**
  String get welcomeHeadlineFitness;

  /// No description provided for @welcomeHeadlineUnified.
  ///
  /// In en, this message translates to:
  /// **'Unified.'**
  String get welcomeHeadlineUnified;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The all-in-one ecosystem for members, coaches, and sellers powered by TAIYO.'**
  String get welcomeSubtitle;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get next;

  /// No description provided for @poweredByTaiyo.
  ///
  /// In en, this message translates to:
  /// **'POWERED BY TAIYO'**
  String get poweredByTaiyo;

  /// No description provided for @shopTrainLine1.
  ///
  /// In en, this message translates to:
  /// **'Shop &'**
  String get shopTrainLine1;

  /// No description provided for @shopTrainLine2.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get shopTrainLine2;

  /// No description provided for @shopTrainLine3.
  ///
  /// In en, this message translates to:
  /// **'Together.'**
  String get shopTrainLine3;

  /// No description provided for @shopTrainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse fitness products, find coaches, and track your progress in one place. A community built on mutual growth.'**
  String get shopTrainSubtitle;

  /// No description provided for @taiyoPowered.
  ///
  /// In en, this message translates to:
  /// **'TAIYO-Powered'**
  String get taiyoPowered;

  /// No description provided for @workouts.
  ///
  /// In en, this message translates to:
  /// **'Workouts.'**
  String get workouts;

  /// No description provided for @taiyoWorkoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get personalized workout plans generated by TAIYO. Designed to adapt to your body\'s rhythm and elevate your sanctuary.'**
  String get taiyoWorkoutSubtitle;

  /// No description provided for @buildYour.
  ///
  /// In en, this message translates to:
  /// **'Build Your'**
  String get buildYour;

  /// No description provided for @fitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get fitness;

  /// No description provided for @empire.
  ///
  /// In en, this message translates to:
  /// **'Empire.'**
  String get empire;

  /// No description provided for @fitnessEmpireSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sell products, coach others, and grow your fitness brand with ease. The tools that move with you.'**
  String get fitnessEmpireSubtitle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @completingGoogleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Completing Google sign-in...'**
  String get completingGoogleSignIn;

  /// No description provided for @googleOnlyAccess.
  ///
  /// In en, this message translates to:
  /// **'GOOGLE-ONLY ACCESS'**
  String get googleOnlyAccess;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Build Your Fitness Empire.'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sell products, coach others, and grow your fitness brand with ease. The tools that move with you.'**
  String get loginSubtitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account with Google'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manual sign-up with name, email, and password has been removed from GymUnity.'**
  String get registerSubtitle;

  /// No description provided for @registerHelper.
  ///
  /// In en, this message translates to:
  /// **'Your account is now created automatically after Google sign-in, then GymUnity will continue with role selection and onboarding.'**
  String get registerHelper;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password reset is no longer used'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GymUnity no longer signs users in with email codes or password reset links.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Continue with the Google account linked to your GymUnity profile instead.'**
  String get forgotPasswordHelper;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password login is disabled'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'GymUnity now uses Google sign-in only, so reset-password links are no longer part of the app flow.'**
  String get resetPasswordSubtitle;

  /// No description provided for @resetPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Go back to Google sign-in and continue with the Google account linked to GymUnity.'**
  String get resetPasswordHelper;

  /// No description provided for @completingPasswordRecovery.
  ///
  /// In en, this message translates to:
  /// **'Completing password recovery...'**
  String get completingPasswordRecovery;

  /// No description provided for @googleSignInDidNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in did not complete. Check Google provider / redirect configuration and try again.'**
  String get googleSignInDidNotComplete;

  /// No description provided for @passwordRecoveryDidNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Password recovery did not complete. Open the latest reset email and try the link again.'**
  String get passwordRecoveryDidNotComplete;

  /// No description provided for @passwordRecovery.
  ///
  /// In en, this message translates to:
  /// **'Password Recovery'**
  String get passwordRecovery;

  /// No description provided for @providerSignIn.
  ///
  /// In en, this message translates to:
  /// **'{provider} Sign-In'**
  String providerSignIn(String provider);

  /// No description provided for @passwordRecoveryVerifying.
  ///
  /// In en, this message translates to:
  /// **'Please wait while GymUnity verifies your password recovery request.'**
  String get passwordRecoveryVerifying;

  /// No description provided for @accountLinkingWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait while GymUnity links your account and restores your session.'**
  String get accountLinkingWait;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// No description provided for @roleHeadline.
  ///
  /// In en, this message translates to:
  /// **'Join the Movement as a...'**
  String get roleHeadline;

  /// No description provided for @roleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your role to start your fitness journey'**
  String get roleSubtitle;

  /// No description provided for @roleProductionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your member experience to continue into GymUnity.'**
  String get roleProductionSubtitle;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @memberDesc.
  ///
  /// In en, this message translates to:
  /// **'Access personalized workouts, shop the store, and connect with elite coaches.'**
  String get memberDesc;

  /// No description provided for @memberCta.
  ///
  /// In en, this message translates to:
  /// **'Get Started Today'**
  String get memberCta;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'POPULAR'**
  String get popular;

  /// No description provided for @seller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get seller;

  /// No description provided for @sellerDesc.
  ///
  /// In en, this message translates to:
  /// **'Sell your fitness products, manage inventory, and grow your brand globally.'**
  String get sellerDesc;

  /// No description provided for @sellerCta.
  ///
  /// In en, this message translates to:
  /// **'Grow Business'**
  String get sellerCta;

  /// No description provided for @coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coach;

  /// No description provided for @coachDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your clients, sell professional training plans, and track progress.'**
  String get coachDesc;

  /// No description provided for @coachCta.
  ///
  /// In en, this message translates to:
  /// **'Empower Others'**
  String get coachCta;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @unableSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Unable to save your role right now.'**
  String get unableSaveRole;

  /// No description provided for @goalSetup.
  ///
  /// In en, this message translates to:
  /// **'Goal setup'**
  String get goalSetup;

  /// No description provided for @memberGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'What result do you want first?'**
  String get memberGoalTitle;

  /// No description provided for @memberGoalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We tune coaches, offers, and check-ins toward the outcome you choose.'**
  String get memberGoalSubtitle;

  /// No description provided for @loseWeight.
  ///
  /// In en, this message translates to:
  /// **'Lose Weight'**
  String get loseWeight;

  /// No description provided for @loseWeightDesc.
  ///
  /// In en, this message translates to:
  /// **'Fat loss, simpler food habits, and weekly accountability.'**
  String get loseWeightDesc;

  /// No description provided for @buildMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build Muscle'**
  String get buildMuscle;

  /// No description provided for @buildMuscleDesc.
  ///
  /// In en, this message translates to:
  /// **'Lean mass, better training structure, and recovery.'**
  String get buildMuscleDesc;

  /// No description provided for @recompose.
  ///
  /// In en, this message translates to:
  /// **'Recompose'**
  String get recompose;

  /// No description provided for @recomposeDesc.
  ///
  /// In en, this message translates to:
  /// **'Lose fat while improving shape and consistency.'**
  String get recomposeDesc;

  /// No description provided for @generalFitness.
  ///
  /// In en, this message translates to:
  /// **'General Fitness'**
  String get generalFitness;

  /// No description provided for @generalFitnessDesc.
  ///
  /// In en, this message translates to:
  /// **'Energy, movement, and sustainable habits that stick.'**
  String get generalFitnessDesc;

  /// No description provided for @baseline.
  ///
  /// In en, this message translates to:
  /// **'Baseline'**
  String get baseline;

  /// No description provided for @memberBaselineTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us where you are now'**
  String get memberBaselineTitle;

  /// No description provided for @memberBaselineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This shapes progress tracking, coach recommendations, and your first check-in baseline.'**
  String get memberBaselineSubtitle;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @heightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 170'**
  String get heightHint;

  /// No description provided for @weightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 82'**
  String get weightHint;

  /// No description provided for @ageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 26'**
  String get ageHint;

  /// No description provided for @cityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Cairo'**
  String get cityHint;

  /// No description provided for @coachMatch.
  ///
  /// In en, this message translates to:
  /// **'Coach match'**
  String get coachMatch;

  /// No description provided for @memberCoachMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'What kind of coaching fits your life?'**
  String get memberCoachMatchTitle;

  /// No description provided for @memberCoachMatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These inputs tune pricing, language, and delivery filters in the marketplace.'**
  String get memberCoachMatchSubtitle;

  /// No description provided for @monthlyBudget.
  ///
  /// In en, this message translates to:
  /// **'Monthly budget'**
  String get monthlyBudget;

  /// No description provided for @budgetHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1500'**
  String get budgetHint;

  /// No description provided for @coachingMode.
  ///
  /// In en, this message translates to:
  /// **'Coaching mode'**
  String get coachingMode;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @inPerson.
  ///
  /// In en, this message translates to:
  /// **'In person'**
  String get inPerson;

  /// No description provided for @hybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get hybrid;

  /// No description provided for @trainingPlace.
  ///
  /// In en, this message translates to:
  /// **'Training place'**
  String get trainingPlace;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @gym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get gym;

  /// No description provided for @both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get both;

  /// No description provided for @preferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred language'**
  String get preferredLanguage;

  /// No description provided for @preferredCoachGender.
  ///
  /// In en, this message translates to:
  /// **'Preferred coach gender'**
  String get preferredCoachGender;

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @trainingRhythm.
  ///
  /// In en, this message translates to:
  /// **'Training rhythm'**
  String get trainingRhythm;

  /// No description provided for @memberTrainingTitle.
  ///
  /// In en, this message translates to:
  /// **'How ready are you to commit each week?'**
  String get memberTrainingTitle;

  /// No description provided for @memberTrainingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We use this to set realistic accountability and starter plan expectations.'**
  String get memberTrainingSubtitle;

  /// No description provided for @experienceLevel.
  ///
  /// In en, this message translates to:
  /// **'Experience level'**
  String get experienceLevel;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @athlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get athlete;

  /// No description provided for @weeklyFrequency.
  ///
  /// In en, this message translates to:
  /// **'Weekly frequency'**
  String get weeklyFrequency;

  /// No description provided for @oneTwoDays.
  ///
  /// In en, this message translates to:
  /// **'1-2 days/week'**
  String get oneTwoDays;

  /// No description provided for @threeFourDays.
  ///
  /// In en, this message translates to:
  /// **'3-4 days/week'**
  String get threeFourDays;

  /// No description provided for @fiveSixDays.
  ///
  /// In en, this message translates to:
  /// **'5-6 days/week'**
  String get fiveSixDays;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get continueAction;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'GET STARTED'**
  String get getStarted;

  /// No description provided for @stepOfTotal.
  ///
  /// In en, this message translates to:
  /// **'STEP {step} OF {totalSteps}'**
  String stepOfTotal(int step, int totalSteps);

  /// No description provided for @chooseGoalToContinue.
  ///
  /// In en, this message translates to:
  /// **'Choose a goal to continue.'**
  String get chooseGoalToContinue;

  /// No description provided for @chooseGenderToContinue.
  ///
  /// In en, this message translates to:
  /// **'Choose your gender to continue.'**
  String get chooseGenderToContinue;

  /// No description provided for @enterRealisticHeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a realistic height in centimeters.'**
  String get enterRealisticHeight;

  /// No description provided for @enterRealisticWeight.
  ///
  /// In en, this message translates to:
  /// **'Enter a realistic weight in kilograms.'**
  String get enterRealisticWeight;

  /// No description provided for @enterValidAge.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid age between 13 and 100.'**
  String get enterValidAge;

  /// No description provided for @addCity.
  ///
  /// In en, this message translates to:
  /// **'Add your city so we can match you with the right coaches.'**
  String get addCity;

  /// No description provided for @addBudget.
  ///
  /// In en, this message translates to:
  /// **'Add a realistic monthly budget in EGP.'**
  String get addBudget;

  /// No description provided for @chooseCoachingMode.
  ///
  /// In en, this message translates to:
  /// **'Choose the coaching mode that fits you best.'**
  String get chooseCoachingMode;

  /// No description provided for @chooseTrainingPlace.
  ///
  /// In en, this message translates to:
  /// **'Choose where you plan to train.'**
  String get chooseTrainingPlace;

  /// No description provided for @choosePreferredCoachingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred coaching language.'**
  String get choosePreferredCoachingLanguage;

  /// No description provided for @choosePreferredCoachGender.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred coach gender.'**
  String get choosePreferredCoachGender;

  /// No description provided for @chooseExperience.
  ///
  /// In en, this message translates to:
  /// **'Choose your current experience level.'**
  String get chooseExperience;

  /// No description provided for @chooseFrequency.
  ///
  /// In en, this message translates to:
  /// **'Choose your weekly training frequency.'**
  String get chooseFrequency;

  /// No description provided for @completeOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Complete each onboarding step before getting started.'**
  String get completeOnboarding;

  /// No description provided for @unableCompleteOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Unable to complete onboarding right now.'**
  String get unableCompleteOnboarding;

  /// No description provided for @goalFooter.
  ///
  /// In en, this message translates to:
  /// **'Choose the goal that best matches your current fitness priority. You can update it later.'**
  String get goalFooter;

  /// No description provided for @baselineFooter.
  ///
  /// In en, this message translates to:
  /// **'Your baseline drives weight, waist, and progress check-ins later.'**
  String get baselineFooter;

  /// No description provided for @matchFooter.
  ///
  /// In en, this message translates to:
  /// **'These preferences directly shape the coach marketplace filters and pricing shown first.'**
  String get matchFooter;

  /// No description provided for @trainingFooter.
  ///
  /// In en, this message translates to:
  /// **'You can update these choices later from your profile and settings.'**
  String get trainingFooter;

  /// No description provided for @beginnerHelper.
  ///
  /// In en, this message translates to:
  /// **'You need simple instructions and closer follow-up.'**
  String get beginnerHelper;

  /// No description provided for @intermediateHelper.
  ///
  /// In en, this message translates to:
  /// **'You train already, but want better structure and feedback.'**
  String get intermediateHelper;

  /// No description provided for @advancedHelper.
  ///
  /// In en, this message translates to:
  /// **'You can handle more load, volume, and tighter planning.'**
  String get advancedHelper;

  /// No description provided for @athleteHelper.
  ///
  /// In en, this message translates to:
  /// **'Performance-first training with serious consistency.'**
  String get athleteHelper;

  /// No description provided for @oneTwoDaysHelper.
  ///
  /// In en, this message translates to:
  /// **'Low-friction routine focused on momentum.'**
  String get oneTwoDaysHelper;

  /// No description provided for @threeFourDaysHelper.
  ///
  /// In en, this message translates to:
  /// **'Balanced pace for visible progress and recovery.'**
  String get threeFourDaysHelper;

  /// No description provided for @fiveSixDaysHelper.
  ///
  /// In en, this message translates to:
  /// **'High-consistency track with structured recovery.'**
  String get fiveSixDaysHelper;

  /// No description provided for @everyDayHelper.
  ///
  /// In en, this message translates to:
  /// **'Best for very committed routines with coach oversight.'**
  String get everyDayHelper;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get homeTab;

  /// No description provided for @coachesTab.
  ///
  /// In en, this message translates to:
  /// **'COACHES'**
  String get coachesTab;

  /// No description provided for @taiyoTab.
  ///
  /// In en, this message translates to:
  /// **'TAIYO'**
  String get taiyoTab;

  /// No description provided for @newsTab.
  ///
  /// In en, this message translates to:
  /// **'NEWS'**
  String get newsTab;

  /// No description provided for @profileTab.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileTab;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @gymunityMember.
  ///
  /// In en, this message translates to:
  /// **'GymUnity Member'**
  String get gymunityMember;

  /// No description provided for @wellnessCollective.
  ///
  /// In en, this message translates to:
  /// **'WELLNESS COLLECTIVE'**
  String get wellnessCollective;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @memberHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your journey toward optimal vitality is curated here. Today is a perfect day for progress.'**
  String get memberHeroSubtitle;

  /// No description provided for @whatMattersNow.
  ///
  /// In en, this message translates to:
  /// **'What Matters Now'**
  String get whatMattersNow;

  /// No description provided for @whatMattersNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your immediate status and pending tasks'**
  String get whatMattersNowSubtitle;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @dailyStreak.
  ///
  /// In en, this message translates to:
  /// **'DAILY STREAK'**
  String get dailyStreak;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @oneDayActive.
  ///
  /// In en, this message translates to:
  /// **'1 Day Active'**
  String get oneDayActive;

  /// No description provided for @daysActive.
  ///
  /// In en, this message translates to:
  /// **'{count} Days Active'**
  String daysActive(int count);

  /// No description provided for @activeCoaches.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE COACHES'**
  String get activeCoaches;

  /// No description provided for @latestWeight.
  ///
  /// In en, this message translates to:
  /// **'LATEST WEIGHT'**
  String get latestWeight;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PLAN'**
  String get currentPlan;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @checkingLiveCoachAssignments.
  ///
  /// In en, this message translates to:
  /// **'Checking live coach assignments.'**
  String get checkingLiveCoachAssignments;

  /// No description provided for @unableLoadCoachingStatus.
  ///
  /// In en, this message translates to:
  /// **'Unable to load coaching status.'**
  String get unableLoadCoachingStatus;

  /// No description provided for @coachCheckoutPending.
  ///
  /// In en, this message translates to:
  /// **'Checkout pending. This count updates as soon as your coach is active.'**
  String get coachCheckoutPending;

  /// No description provided for @noActiveCoachSubscription.
  ///
  /// In en, this message translates to:
  /// **'No active coach subscription. Tap to browse coaches.'**
  String get noActiveCoachSubscription;

  /// No description provided for @oneLiveCoachConnection.
  ///
  /// In en, this message translates to:
  /// **'1 live coach connection.'**
  String get oneLiveCoachConnection;

  /// No description provided for @liveCoachConnections.
  ///
  /// In en, this message translates to:
  /// **'{count} live coach connections.'**
  String liveCoachConnections(int count);

  /// No description provided for @syncingLatestWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Syncing your latest weigh-in.'**
  String get syncingLatestWeighIn;

  /// No description provided for @unableLoadWeightData.
  ///
  /// In en, this message translates to:
  /// **'Unable to load weight data right now.'**
  String get unableLoadWeightData;

  /// No description provided for @noWeightDataYet.
  ///
  /// In en, this message translates to:
  /// **'No weight data yet'**
  String get noWeightDataYet;

  /// No description provided for @noWeightDataYetSentence.
  ///
  /// In en, this message translates to:
  /// **'No weight data yet.'**
  String get noWeightDataYetSentence;

  /// No description provided for @trackFirstWeighIn.
  ///
  /// In en, this message translates to:
  /// **'Track your first weigh-in to unlock real trend changes.'**
  String get trackFirstWeighIn;

  /// No description provided for @firstRecordedWeighIn.
  ///
  /// In en, this message translates to:
  /// **'First recorded weigh-in. Updated {date}.'**
  String firstRecordedWeighIn(String date);

  /// No description provided for @stableVsPreviousEntry.
  ///
  /// In en, this message translates to:
  /// **'Stable vs previous entry. Updated {date}.'**
  String stableVsPreviousEntry(String date);

  /// No description provided for @weightDownVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'{amount} kg down vs previous entry. Updated {date}.'**
  String weightDownVsPrevious(String amount, String date);

  /// No description provided for @weightUpVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'{amount} kg up vs previous entry. Updated {date}.'**
  String weightUpVsPrevious(String amount, String date);

  /// No description provided for @checkingLiveTaiyoPlan.
  ///
  /// In en, this message translates to:
  /// **'Checking your live TAIYO plan.'**
  String get checkingLiveTaiyoPlan;

  /// No description provided for @unableLoadTaiyoPlanStatus.
  ///
  /// In en, this message translates to:
  /// **'Unable to load TAIYO plan status.'**
  String get unableLoadTaiyoPlanStatus;

  /// No description provided for @noActivePlan.
  ///
  /// In en, this message translates to:
  /// **'No active plan'**
  String get noActivePlan;

  /// No description provided for @tapToBuildTaiyoWorkoutPlan.
  ///
  /// In en, this message translates to:
  /// **'Tap to build and activate your TAIYO workout plan.'**
  String get tapToBuildTaiyoWorkoutPlan;

  /// No description provided for @planTitleTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'{title}. Tap to open your workout plan.'**
  String planTitleTapToOpen(String title);

  /// No description provided for @consistentWeeksInRow.
  ///
  /// In en, this message translates to:
  /// **'{count} consistent weeks in a row. Tap to open.'**
  String consistentWeeksInRow(int count);

  /// No description provided for @consistentWeeksLogged.
  ///
  /// In en, this message translates to:
  /// **'{count} consistent weeks logged so far. Tap to open.'**
  String consistentWeeksLogged(int count);

  /// No description provided for @planLiveTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Plan is live. Tap to open your workout plan.'**
  String get planLiveTapToOpen;

  /// No description provided for @openTaiyo.
  ///
  /// In en, this message translates to:
  /// **'Open TAIYO'**
  String get openTaiyo;

  /// No description provided for @preparingTodayCoachBrief.
  ///
  /// In en, this message translates to:
  /// **'Preparing today\'s coach brief...'**
  String get preparingTodayCoachBrief;

  /// No description provided for @dailyTaiyoCoachingGuidance.
  ///
  /// In en, this message translates to:
  /// **'Daily TAIYO coaching and workout guidance'**
  String get dailyTaiyoCoachingGuidance;

  /// No description provided for @openNewsFeed.
  ///
  /// In en, this message translates to:
  /// **'Open news\nfeed'**
  String get openNewsFeed;

  /// No description provided for @openMyCoaching.
  ///
  /// In en, this message translates to:
  /// **'Open my\ncoaching'**
  String get openMyCoaching;

  /// No description provided for @nutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get nutrition;

  /// No description provided for @mealsHydrationTargets.
  ///
  /// In en, this message translates to:
  /// **'Meals, hydration & targets'**
  String get mealsHydrationTargets;

  /// No description provided for @weeklyCheckins.
  ///
  /// In en, this message translates to:
  /// **'Weekly\ncheck-ins'**
  String get weeklyCheckins;

  /// No description provided for @submitProgress.
  ///
  /// In en, this message translates to:
  /// **'Submit\nprogress'**
  String get submitProgress;

  /// No description provided for @browseCoaches.
  ///
  /// In en, this message translates to:
  /// **'Browse\ncoaches'**
  String get browseCoaches;

  /// No description provided for @openMessages.
  ///
  /// In en, this message translates to:
  /// **'Open\nmessages'**
  String get openMessages;

  /// No description provided for @completeCheckout.
  ///
  /// In en, this message translates to:
  /// **'Complete Checkout'**
  String get completeCheckout;

  /// No description provided for @submitCheckin.
  ///
  /// In en, this message translates to:
  /// **'Submit Check-in'**
  String get submitCheckin;

  /// No description provided for @checkoutNow.
  ///
  /// In en, this message translates to:
  /// **'Checkout Now'**
  String get checkoutNow;

  /// No description provided for @openCheckin.
  ///
  /// In en, this message translates to:
  /// **'Open Check-in'**
  String get openCheckin;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'NEXT STEP'**
  String get nextStep;

  /// No description provided for @findCoach.
  ///
  /// In en, this message translates to:
  /// **'Find a Coach'**
  String get findCoach;

  /// No description provided for @browseStore.
  ///
  /// In en, this message translates to:
  /// **'Browse store'**
  String get browseStore;

  /// No description provided for @premiumEssentialsForTransformation.
  ///
  /// In en, this message translates to:
  /// **'Premium essentials for your transformation'**
  String get premiumEssentialsForTransformation;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @deleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deleting;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @progressTracking.
  ///
  /// In en, this message translates to:
  /// **'Progress Tracking'**
  String get progressTracking;

  /// No description provided for @unableLoadPreferences.
  ///
  /// In en, this message translates to:
  /// **'GymUnity could not load your preferences.'**
  String get unableLoadPreferences;

  /// No description provided for @weightHistory.
  ///
  /// In en, this message translates to:
  /// **'Weight History'**
  String get weightHistory;

  /// No description provided for @unableLoadWeightEntries.
  ///
  /// In en, this message translates to:
  /// **'Unable to load weight entries.'**
  String get unableLoadWeightEntries;

  /// No description provided for @noWeightEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No weight entries yet. Add your first entry.'**
  String get noWeightEntriesYet;

  /// No description provided for @addWeight.
  ///
  /// In en, this message translates to:
  /// **'Add weight'**
  String get addWeight;

  /// No description provided for @bodyMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Body Measurements'**
  String get bodyMeasurements;

  /// No description provided for @unableLoadBodyMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Unable to load body measurements.'**
  String get unableLoadBodyMeasurements;

  /// No description provided for @noBodyMeasurementsYet.
  ///
  /// In en, this message translates to:
  /// **'No body measurements yet. Add your first measurement snapshot.'**
  String get noBodyMeasurementsYet;

  /// No description provided for @addMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Add measurement'**
  String get addMeasurement;

  /// No description provided for @weightEntryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Weight entry deleted.'**
  String get weightEntryDeleted;

  /// No description provided for @weightEntryDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Weight entry could not be deleted: {error}'**
  String weightEntryDeleteFailed(String error);

  /// No description provided for @deleteWeightEntryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete weight entry?'**
  String get deleteWeightEntryQuestion;

  /// No description provided for @deleteWeightEntryBody.
  ///
  /// In en, this message translates to:
  /// **'This weight entry will be permanently removed from your progress history.'**
  String get deleteWeightEntryBody;

  /// No description provided for @measurementDeleted.
  ///
  /// In en, this message translates to:
  /// **'Measurement deleted.'**
  String get measurementDeleted;

  /// No description provided for @measurementDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Measurement could not be deleted: {error}'**
  String measurementDeleteFailed(String error);

  /// No description provided for @deleteMeasurementQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete measurement?'**
  String get deleteMeasurementQuestion;

  /// No description provided for @deleteMeasurementBody.
  ///
  /// In en, this message translates to:
  /// **'This measurement will be permanently removed from your progress history.'**
  String get deleteMeasurementBody;

  /// No description provided for @waistMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Waist {value} {unit}'**
  String waistMeasurement(String value, String unit);

  /// No description provided for @chestMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Chest {value} {unit}'**
  String chestMeasurement(String value, String unit);

  /// No description provided for @hipsMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Hips {value} {unit}'**
  String hipsMeasurement(String value, String unit);

  /// No description provided for @bodyFatMeasurement.
  ///
  /// In en, this message translates to:
  /// **'BF {value}%'**
  String bodyFatMeasurement(String value);

  /// No description provided for @addWeightEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Weight Entry'**
  String get addWeightEntry;

  /// No description provided for @editWeightEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit Weight Entry'**
  String get editWeightEntry;

  /// No description provided for @weightKgLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightKgLabel;

  /// No description provided for @recordedOn.
  ///
  /// In en, this message translates to:
  /// **'Recorded on {date}'**
  String recordedOn(String date);

  /// No description provided for @enterValidWeightValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid weight value.'**
  String get enterValidWeightValue;

  /// No description provided for @weightEntrySaved.
  ///
  /// In en, this message translates to:
  /// **'Weight entry saved.'**
  String get weightEntrySaved;

  /// No description provided for @weightEntrySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Weight entry could not be saved: {error}'**
  String weightEntrySaveFailed(String error);

  /// No description provided for @editMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Edit Measurement'**
  String get editMeasurement;

  /// No description provided for @waistCmLabel.
  ///
  /// In en, this message translates to:
  /// **'Waist (cm)'**
  String get waistCmLabel;

  /// No description provided for @chestCmLabel.
  ///
  /// In en, this message translates to:
  /// **'Chest (cm)'**
  String get chestCmLabel;

  /// No description provided for @hipsCmLabel.
  ///
  /// In en, this message translates to:
  /// **'Hips (cm)'**
  String get hipsCmLabel;

  /// No description provided for @bodyFatPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Body Fat %'**
  String get bodyFatPercentLabel;

  /// No description provided for @enterOneMeasurementBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one measurement before saving.'**
  String get enterOneMeasurementBeforeSaving;

  /// No description provided for @measurementsPositiveNumbers.
  ///
  /// In en, this message translates to:
  /// **'Measurements must be positive numbers.'**
  String get measurementsPositiveNumbers;

  /// No description provided for @measurementSaved.
  ///
  /// In en, this message translates to:
  /// **'Measurement saved.'**
  String get measurementSaved;

  /// No description provided for @measurementSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Measurement could not be saved: {error}'**
  String measurementSaveFailed(String error);

  /// No description provided for @noChartableMeasurementsYet.
  ///
  /// In en, this message translates to:
  /// **'No chartable measurements yet.'**
  String get noChartableMeasurementsYet;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get statusPartial;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get statusArchived;

  /// No description provided for @statusPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get statusPublished;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @riskLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get riskLow;

  /// No description provided for @riskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get riskMedium;

  /// No description provided for @riskHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get riskHigh;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
