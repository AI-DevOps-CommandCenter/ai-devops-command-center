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
    expect(find.text('Elevated errors after deployment'), findsOneWidget);
    expect(find.text('INCIDENTS BY SEVERITY'), findsOneWidget);
    expect(find.text('SERVICE HEALTH'), findsOneWidget);
  });

  testWidgets('S04IncidentsScreen renders incident list and tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: S04IncidentsScreen(),
      ),
    );

    expect(find.text('Incidents'), findsAtLeastNWidgets(1));
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('S21PostmortemReportScreen renders postmortem sections', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: S21PostmortemReportScreen(),
      ),
    );

    expect(find.text('Postmortem'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Root cause'), findsOneWidget);
    expect(find.text('Evidence'), findsOneWidget);
  });
}