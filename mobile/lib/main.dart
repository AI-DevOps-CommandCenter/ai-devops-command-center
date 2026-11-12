import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
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
import 'models/playbook_model.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService().initialize();
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
            fontFamily: 'Segoe UI',
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.light.teal,
              primary: AppColors.light.teal,
              background: AppColors.light.bg,
              brightness: Brightness.light,
            ),
            useMaterial3: false,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.dark.bg,
            fontFamily: 'Segoe UI',
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.dark.teal,
              primary: AppColors.dark.teal,
              background: AppColors.dark.bg,
              brightness: Brightness.dark,
            ),
            useMaterial3: false,
          ),
          initialRoute: '/',
          onGenerateRoute: (settings) {
            if (settings.name == '/assistant') {
              final ctx = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (context) => S23DeveloperAssistantScreen(initialContext: ctx),
              );
            }
            if (settings.name == '/approve-action') {
              final approval = settings.arguments as ApprovalModel?;
              return MaterialPageRoute(
                builder: (context) => S18ApproveActionScreen(initialApproval: approval),
              );
            }
            if (settings.name == '/execution-progress') {
              final runId = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (context) => S19ExecutionProgressScreen(runId: runId),
              );
            }
            if (settings.name == '/recovery-verification') {
              final incidentId = (settings.arguments as String?) ?? 'INC-1042';
              return MaterialPageRoute(
                builder: (context) => S20RecoveryVerificationScreen(incidentId: incidentId),
              );
            }
            return null;
          },
          routes: {
            '/': (context) => const S01WelcomeScreen(),
            '/signin': (context) => const S02SignInScreen(),
            '/dashboard': (context) => const S03OverviewDashboardScreen(),
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
            '/execution-progress': (context) => const S19ExecutionProgressScreen(),
            '/recovery-verification': (context) => const S20RecoveryVerificationScreen(),
            '/postmortem': (context) => const S21PostmortemReportScreen(),
            '/incident-history': (context) => const S22IncidentHistoryScreen(),
            '/pull-request': (context) => const S24PullRequestSummaryScreen(),
            '/notifications': (context) => const S25NotificationsScreen(),
            '/integrations': (context) => const S26IntegrationsScreen(),
            '/preferences': (context) => const S27NotificationPreferencesScreen(),
            '/profile': (context) => const S28ProfileScreen(),
          },
        );
      },
    );
  }
}
