import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/s03_overview_dashboard_screen.dart';
import 'package:mobile/screens/s04_incidents_screen.dart';
import 'package:mobile/screens/s21_postmortem_report_screen.dart';

void main() {
  testWidgets('DevOps Command Center App loads without error', (WidgetTester tester) async {
    await tester.pumpWidget(const DevOpsCommandCenterApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('S03OverviewDashboardScreen renders dashboard components', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: S03OverviewDashboardScreen(),
      ),
    );

    expect(find.text('Overview'), findsAtLeastNWidgets(1));
    expect(find.text('INCIDENTS'), findsOneWidget);
    expect(find.text('SERVICE HEALTH'), findsOneWidget);
    // Data comes from the backend only: no invented incident or metrics.
    expect(find.text('Elevated errors after deployment'), findsNothing);
    expect(find.textContaining('payments-api'), findsNothing);
  });

  testWidgets('S04IncidentsScreen renders incident list and tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: S04IncidentsScreen(),
      ),
    );

    expect(find.text('Incidents'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Active'), findsOneWidget);
    expect(find.textContaining('History'), findsOneWidget);
  });

  // S21 loads the real postmortem (GET /api/postmortems?incident_id=); without
  // an incident it shows guidance instead of invented content.
  testWidgets('S21PostmortemReportScreen without an incident shows guidance, no fake data', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: S21PostmortemReportScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Postmortem'), findsOneWidget);
    expect(find.text('Open this screen from an incident.'), findsOneWidget);
    expect(find.textContaining('payments-api'), findsNothing);
  });
}