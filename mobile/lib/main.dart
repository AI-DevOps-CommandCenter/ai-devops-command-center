import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'screens/s00_splash_screen.dart';
import 'screens/s01_welcome_screen.dart';
import 'screens/s02_signin_screen.dart';
import 'screens/s03_overview_dashboard_screen.dart';
import 'screens/s04_incidents_screen.dart';
import 'screens/s05_incident_details_screen.dart';
import 'screens/s06_ai_investigation_progress_screen.dart';
import 'screens/s07_root_cause_screen.dart';
import 'screens/s08_evidence_details_screen.dart';
import 'screens/s09_logs_explorer_screen.dart';
import 'screens/s10_metrics_screen.dart';
import 'screens/s11_services_screen.dart';
import 'screens/s12_service_details_screen.dart';
import 'screens/s13_repositories_screen.dart';
import 'screens/s14_deployment_details_screen.dart';
import 'screens/s15_failed_pipeline_job_screen.dart';
import 'screens/s16_remediation_playbooks_screen.dart';
import 'screens/s17_recommended_action_screen.dart';
import 'screens/s18_approve_action_screen.dart';
import 'screens/s19_execution_progress_screen.dart';
import 'screens/s20_recovery_verification_screen.dart';
import 'screens/s21_postmortem_report_screen.dart';
import 'screens/s22_incident_history_screen.dart';
import 'screens/s23_developer_assistant_screen.dart';
import 'screens/s24_pull_request_summary_screen.dart';
import 'screens/s25_notifications_screen.dart';
import 'screens/s26_integrations_screen.dart';
import 'screens/s27_notification_preferences_screen.dart';
import 'screens/s28_profile_screen.dart';
import 'screens/s29_forgot_password_screen.dart';
import 'screens/s30_search_screen.dart';
import 'screens/s31_reject_action_screen.dart';
import 'screens/s32_inc_1041_screen.dart';
import 'screens/s33_inc_1040_screen.dart';
import 'screens/s34_pm_1037_screen.dart';
import 'screens/s35_pm_1033_screen.dart';
import 'screens/s36_pm_1029_screen.dart';
import 'screens/s37_team_screen.dart';
import 'screens/s38_playbook_edit_screen.dart';
import 'screens/s39_audit_log_screen.dart';
import 'screens/s40_loading_screen.dart';
import 'screens/s41_all_clear_screen.dart';
import 'screens/s42_logs_error_screen.dart';
import 'screens/s43_offline_screen.dart';
import 'screens/s44_rollback_failed_screen.dart';
import 'screens/s45_brand_screen.dart';

void main() {
  runApp(const DevOpsCommandCenterApp());
}

class DevOpsCommandCenterApp extends StatelessWidget {
  const DevOpsCommandCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'DevOps Command Center',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.light.bg,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Segoe UI', '-apple-system', 'Roboto', 'sans-serif'],
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.light.accent,
              primary: AppColors.light.accent,
              surface: AppColors.light.card,
              brightness: Brightness.light,
            ),
            useMaterial3: false,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.dark.bg,
            fontFamily: 'Inter',
            fontFamilyFallback: const ['Segoe UI', '-apple-system', 'Roboto', 'sans-serif'],
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.dark.accent,
              primary: AppColors.dark.accent,
              surface: AppColors.dark.card,
              brightness: Brightness.dark,
            ),
            useMaterial3: false,
          ),
          builder: (context, child) {
            return Container(
              color: const Color(0xFFE5E7EB),
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeController.instance.isDark
                        ? AppColors.dark.bg
                        : AppColors.light.bg,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRect(child: child ?? const SizedBox.shrink()),
                ),
              ),
            );
          },
          initialRoute: '/',
          onGenerateRoute: (settings) {
            if (settings.name == '/assistant') {
              final ctx = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (context) => S23DeveloperAssistantScreen(initialContext: ctx),
              );
            }
            return null;
          },
          routes: {
            '/': (context) => const S00SplashScreen(),
            '/splash': (context) => const S00SplashScreen(),
            '/welcome': (context) => const S01WelcomeScreen(),
            '/signin': (context) => const S02SignInScreen(),
            '/forgot-password': (context) => const S29ForgotPasswordScreen(),
            '/dashboard': (context) => const S03OverviewDashboardScreen(),
            '/search': (context) => const S30SearchScreen(),
            '/incidents': (context) => const S04IncidentsScreen(),
            '/incident-details': (context) => const S05IncidentDetailsScreen(),
            '/investigation-progress': (context) => const S06AiInvestigationProgressScreen(),
            '/root-cause': (context) => const S07RootCauseScreen(),
            '/evidence-details': (context) => const S08EvidenceDetailsScreen(),
            '/logs': (context) => const S09LogsExplorerScreen(),
            '/metrics': (context) => const S10MetricsScreen(),
            '/services': (context) => const S11ServicesScreen(),
            '/service-details': (context) => const S12ServiceDetailsScreen(),
            '/repositories': (context) => const S13RepositoriesScreen(),
            '/deployment-details': (context) => const S14DeploymentDetailsScreen(),
            '/pipeline-job': (context) => const S15FailedPipelineJobScreen(),
            '/playbooks': (context) => const S16RemediationPlaybooksScreen(),
            '/recommended-action': (context) => const S17RecommendedActionScreen(),
            '/approve-action': (context) => const S18ApproveActionScreen(),
            '/reject-action': (context) => const S31RejectActionScreen(),
            '/execution-progress': (context) => const S19ExecutionProgressScreen(),
            '/recovery-verification': (context) => const S20RecoveryVerificationScreen(),
            '/postmortem': (context) => const S21PostmortemReportScreen(),
            '/incident-history': (context) => const S22IncidentHistoryScreen(),
            '/pull-request': (context) => const S24PullRequestSummaryScreen(),
            '/notifications': (context) => const S25NotificationsScreen(),
            '/integrations': (context) => const S26IntegrationsScreen(),
            '/preferences': (context) => const S27NotificationPreferencesScreen(),
            '/profile': (context) => const S28ProfileScreen(),
            '/team': (context) => const S37TeamScreen(),
            '/playbook-edit': (context) => const S38PlaybookEditScreen(),
            '/audit-log': (context) => const S39AuditLogScreen(),
            '/loading': (context) => const S40LoadingScreen(),
            '/all-clear': (context) => const S41AllClearScreen(),
            '/logs-error': (context) => const S42LogsErrorScreen(),
            '/offline': (context) => const S43OfflineScreen(),
            '/rollback-failed': (context) => const S44RollbackFailedScreen(),
            '/brand': (context) => const S45BrandScreen(),
            '/inc-1041': (context) => const S32Inc1041Screen(),
            '/inc-1040': (context) => const S33Inc1040Screen(),
            '/pm-1037': (context) => const S34Pm1037Screen(),
            '/pm-1033': (context) => const S35Pm1033Screen(),
            '/pm-1029': (context) => const S36Pm1029Screen(),
          },
        );
      },
    );
  }
}
