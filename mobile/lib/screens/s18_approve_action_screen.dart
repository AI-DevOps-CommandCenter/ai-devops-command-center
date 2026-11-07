import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class S18ApproveActionScreen extends StatefulWidget {
  const S18ApproveActionScreen({super.key});

  @override
  State<S18ApproveActionScreen> createState() => _S18ApproveActionScreenState();
}

class _S18ApproveActionScreenState extends State<S18ApproveActionScreen> {
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Approve Action',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: _isCancelled ? _buildCancelledView(colors) : _buildApprovalView(colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalView(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Approval Details Card
        _buildCard(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Roll back payments-api',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 10),
              _buildRow(colors, 'Environment', 'Production'),
              Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
              _buildRow(colors, 'From → To', 'v2.8.1 → v2.8.0'),
              Divider(height: 14, color: colors.cardBorder, thickness: 0.5),
              _buildRow(colors, 'Approver', 'Alex Morgan'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Warning Note
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.badgeAmberBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Impact: brief request failures during switchover (about 30 s). Nothing runs until you confirm.',
            style: TextStyle(
              fontSize: 12,
              color: colors.badgeAmberText,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Destructive Primary Button: Approve and Execute
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/execution-progress');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.red,
              foregroundColor: colors.isDark ? const Color(0xFF0B1226) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Approve and Execute',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Cancel Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                _isCancelled = true;
              });
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.cardAccent,
              foregroundColor: colors.text,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCancelledView(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCard(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Approval cancelled',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Nothing was executed. Incident remains open.',
                style: TextStyle(fontSize: 13, color: colors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: colors.cardAccent,
              foregroundColor: colors.text,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Back to recommendation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required AppColorScheme colors, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: colors.isDark ? Colors.black.withOpacity(0.3) : const Color.fromRGBO(15, 27, 51, 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildRow(AppColorScheme colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.muted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
