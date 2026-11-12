import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';

class S23DeveloperAssistantScreen extends StatefulWidget {
  final String? initialContext;

  const S23DeveloperAssistantScreen({
    super.key,
    this.initialContext,
  });

  @override
  State<S23DeveloperAssistantScreen> createState() =>
      _S23DeveloperAssistantScreenState();
}

class _S23DeveloperAssistantScreenState
    extends State<S23DeveloperAssistantScreen> {
  String _selectedTopic = 'pr';
  final TextEditingController _inputController = TextEditingController();
  final List<PlatformFile> _attachments = [];
  final List<PlatformFile> _sentAttachments = [];

  static const _imageExt = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'];

  bool _isImage(PlatformFile f) =>
      _imageExt.contains((f.extension ?? '').toLowerCase());

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pick(FileType type) async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: type,
        allowMultiple: true,
        withData: true,
      );
      if (r == null) return;
      setState(() => _attachments.addAll(r.files));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file picker')),
      );
    }
  }

  void _showAttachSheet() {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.image_outlined, color: colors.accent),
                title: Text('Photo / screenshot',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: colors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(FileType.image);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.insert_drive_file_outlined, color: colors.accent),
                title: Text('File',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: colors.text)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(FileType.any);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentChip(PlatformFile f, {VoidCallback? onRemove}) {
    final colors = context.colors;
    final hasPreview = _isImage(f) && f.bytes != null;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 40,
              child: hasPreview
                  ? Image.memory(f.bytes!, fit: BoxFit.cover)
                  : Container(
                      color: colors.accentSoft,
                      child: Icon(Icons.insert_drive_file_outlined,
                          size: 20, color: colors.accent),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.text)),
                Text(_size(f.size),
                    style: TextStyle(fontSize: 11, color: colors.muted)),
              ],
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: colors.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  final Map<String, Map<String, dynamic>> _answers = const {
    'pr': {
      'q': 'Summarize PR #214',
      'title': 'PR #214 · Tune DB pool settings',
      'lines': [
        'Lowers DB_POOL_TIMEOUT from 1000 ms to 500 ms.',
        'Adds 3 connection retries and changes log format.',
        'Files: db/pool.ts, config/prod.yaml, logger.ts',
      ],
      'risk':
          'Risk: medium. Timeout change shipped without a load test. This matches INC-1042.',
    },
    'build': {
      'q': 'Why did pipeline #319 fail?',
      'title': 'Pipeline #319 · integration-tests',
      'lines': [
        'Postgres container was not ready after 30 s.',
        'All 14 integration tests got ECONNREFUSED.',
        'Unit tests and build passed.',
      ],
      'risk':
          'Likely a flaky CI setup, not PR #215. Add a health-check wait and re-run.',
    },
    'log': {
      'q': 'Explain “connection timeout after 500ms”',
      'title': 'Log error · payments-api',
      'lines': [
        'Requests wait for a free DB connection.',
        'After 500 ms they give up and return HTTP 500.',
        'Pool shows 20/20 busy at the same time.',
      ],
      'risk':
          'The wait limit is too short for current traffic. See INC-1042 root cause.',
    },
  };

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _cycleNextTopic() {
    const order = ['pr', 'build', 'log'];
    final idx = order.indexOf(_selectedTopic);
    setState(() {
      _selectedTopic = order[(idx + 1) % order.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final a = _answers[_selectedTopic]!;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Assistant · Context: INC-1042 · payments-api
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assistant',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.52,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Context: INC-1042 · payments-api',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                  _buildTopicMenu(context),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // User message bubble (aligned right)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a['q'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                color: colors.onAccent,
                              ),
                            ),
                            if (_sentAttachments.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 0,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: _sentAttachments
                                    .map((f) => _attachmentChip(f))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // AI Answer Card
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.auto_awesome,
                            size: 18, color: colors.accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['title'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: colors.text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...((a['lines'] as List<String>).map((line) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('• ',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: colors.muted)),
                                      Expanded(
                                        child: Text(
                                          line,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.45,
                                            color: colors.text,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: colors.warning.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  a['risk'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Based on GitHub, Loki and Prometheus data · may be wrong',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Input form
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: colors.bg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 58,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (int i = 0; i < _attachments.length; i++)
                              _attachmentChip(
                                _attachments[i],
                                onRemove: () =>
                                    setState(() => _attachments.removeAt(i)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      // Plus button (left): attach photo / screenshot / file
                      InkWell(
                        onTap: _showAttachSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          alignment: Alignment.center,
                          child:
                              Icon(Icons.add, size: 22, color: colors.accent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _inputController,
                            style: TextStyle(fontSize: 15, color: colors.text),
                            decoration: InputDecoration(
                              hintText: 'Ask about logs, builds or PRs…',
                              hintStyle: TextStyle(
                                fontSize: 15,
                                color: colors.muted,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _sentAttachments
                              ..clear()
                              ..addAll(_attachments);
                            _attachments.clear();
                            _inputController.clear();
                          });
                          _cycleNextTopic();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.send,
                              size: 20, color: colors.onAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Nav
            const AppBottomNav(currentIndex: 4),
          ],
        ),
      ),
    );
  }

  static const _topicLabels = {
    'pr': 'Summarize PR #214',
    'build': 'Explain build failure',
    'log': 'Explain log error',
  };

  static const _topicIcons = {
    'pr': Icons.merge_type,
    'build': Icons.build_circle_outlined,
    'log': Icons.receipt_long_outlined,
  };

  Widget _buildTopicMenu(BuildContext context) {
    final colors = context.colors;

    return PopupMenuButton<String>(
      tooltip: 'Quick prompts',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: colors.card,
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
      onSelected: (key) => setState(() => _selectedTopic = key),
      itemBuilder: (ctx) => _topicLabels.entries.map((e) {
        final selected = _selectedTopic == e.key;
        return PopupMenuItem<String>(
          value: e.key,
          height: 46,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _topicIcons[e.key],
                size: 18,
                color: selected ? colors.accent : colors.muted,
              ),
              const SizedBox(width: 10),
              Text(
                e.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? colors.accent : colors.text,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 12),
                Icon(Icons.check, size: 16, color: colors.accent),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.menu, size: 20, color: colors.text),
      ),
    );
  }
}