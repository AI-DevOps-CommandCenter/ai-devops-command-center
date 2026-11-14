import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/proto_icon.dart';

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
  bool _menuOpen = false;
  final List<_Chat> _chats = [
    _Chat('Summarize PR #214', 'pr', const []),
    _Chat('Is PR #215 safe to merge?', 'pr215', const []),
    _Chat('What did the rollback change?', 'rollback', const []),
    _Chat('Why is the orders queue growing?', 'backlog', const []),
    _Chat('Which alerts fired today?', 'alerts', const []),
    _Chat('Which pipelines failed recently?', 'pipeline', const []),
  ];
  int _activeChat = 0;

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

  final GlobalKey _plusKey = GlobalKey();

  Future<void> _showAttachMenu() async {
    final colors = context.colors;
    final box = _plusKey.currentContext!.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);

    const itemHeight = 50.0;
    const menuHeight = itemHeight * 2 + 16; // two items + vertical padding
    final top = topLeft.dy - menuHeight - 10;

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        top,
        overlay.size.width - topLeft.dx - 230,
        overlay.size.height - top - menuHeight,
      ),
      color: colors.card,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.28),
      constraints: const BoxConstraints(minWidth: 230),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.border),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'image',
          height: itemHeight,
          child: Row(
            children: [
              Icon(Icons.image_outlined, size: 20, color: colors.text),
              const SizedBox(width: 12),
              Text('Add photo or screenshot',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.text)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'file',
          height: itemHeight,
          child: Row(
            children: [
              Icon(Icons.attach_file, size: 20, color: colors.text),
              const SizedBox(width: 12),
              Text('Add file',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.text)),
            ],
          ),
        ),
      ],
    );

    if (choice == 'image') {
      _pick(FileType.image);
    } else if (choice == 'file') {
      _pick(FileType.any);
    }
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
    'pr215': {
      'q': 'Is PR #215 safe to merge?',
      'title': 'PR #215 · Restore pool timeout to 1000 ms',
      'lines': [
        'Restores DB_POOL_TIMEOUT to 1000 ms.',
        'Pipeline #319 failed on integration-tests.',
        'The failure looks like a CI setup issue, not this change.',
      ],
      'risk': 'Risk: low. Re-run the checks before you merge.',
    },
    'rollback': {
      'q': 'What did the rollback change?',
      'title': 'Rollback · pipeline #320',
      'lines': [
        'Redeployed v2.8.0 to Production at 14:25.',
        'v2.8.0 was stable for 22 h before PR #214.',
        'PR #214 is no longer live.',
      ],
      'risk':
          'Risk: low. Keep the rollback until PR #215 has been checked.',
    },
    'backlog': {
      'q': 'Why is the orders queue growing?',
      'title': 'INC-1041 · orders-worker',
      'lines': [
        'Backlog is 4,210 jobs and growing +18%/h.',
        'No recent deploy. Traffic is up 35%.',
        'Likely cause: more orders than usual.',
      ],
      'risk':
          'Risk: medium. Add workers if the backlog keeps growing.',
    },
    'alerts': {
      'q': 'Which alerts fired today?',
      'title': 'Alerts · today',
      'lines': [
        'Backlog above 3,000 on orders-worker at 13:40.',
        'Error rate above 5% on payments-api at 14:12.',
        'Prometheus raised both alerts.',
      ],
      'risk':
          'Risk: medium. INC-1042 is critical and still being investigated.',
    },
    'pipeline': {
      'q': 'Which pipelines failed recently?',
      'title': 'Pipelines · recent runs',
      'lines': [
        '#319 integration-tests failed 12 min ago (PR #215).',
        '#320 rollback deploy passed at 14:25.',
        '#318 build and deploy passed at 14:03.',
      ],
      'risk': 'Risk: low. Only #319 needs a re-run.',
    },
  };

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String _nextTopic() {
    const order = ['pr', 'build', 'log'];
    final idx = order.indexOf(_selectedTopic);
    return order[(idx + 1) % order.length];
  }

  // Start a chat from one of the 3 quick options (or reopen it if it exists)
  void _startChat(String topic) {
    final title = _answers[topic]!['q'] as String;
    final existing = _chats.indexWhere((c) => c.title == title);
    setState(() {
      if (existing >= 0) {
        _activeChat = existing;
      } else {
        _chats.insert(0, _Chat(title, topic, const []));
        _activeChat = 0;
      }
      _selectedTopic = topic;
      _menuOpen = false;
    });
  }

  void _openChat(int index) {
    setState(() {
      _activeChat = index;
      _selectedTopic = _chats[index].topic;
      _menuOpen = false;
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    final topic = _nextTopic();
    setState(() {
      _chats.insert(
        0,
        _Chat(text.isEmpty ? 'Attachment' : text, topic,
            List<PlatformFile>.from(_attachments)),
      );
      _activeChat = 0;
      _selectedTopic = topic;
      _attachments.clear();
      _inputController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final a = _answers[_selectedTopic]!;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
        Column(
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
                              _chats[_activeChat].title,
                              style: TextStyle(
                                fontSize: 15,
                                color: colors.onAccent,
                              ),
                            ),
                            if (_chats[_activeChat].files.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 0,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: _chats[_activeChat]
                                    .files
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

                  // AI Answer Card (no avatar)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
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

            // Input form (Claude-style composer)
            Container(
              color: colors.bg,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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
                    TextField(
                      controller: _inputController,
                      onChanged: (_) => setState(() {}),
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                          fontSize: 15, height: 1.4, color: colors.text),
                      cursorColor: colors.accent,
                      decoration: InputDecoration(
                        hintText: 'Ask about logs, builds or PRs…',
                        hintStyle:
                            TextStyle(fontSize: 15, color: colors.muted),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.only(right: 4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // + button
                        InkWell(
                          key: _plusKey,
                          onTap: _showAttachMenu,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.border),
                            ),
                            alignment: Alignment.center,
                            child:
                                Icon(Icons.add, size: 20, color: colors.text),
                          ),
                        ),
                        const Spacer(),
                        // Send button (round, accent when there is something to send)
                        InkWell(
                          onTap: (_inputController.text.trim().isNotEmpty ||
                                  _attachments.isNotEmpty)
                              ? _sendMessage
                              : null,
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_inputController.text.trim().isNotEmpty ||
                                      _attachments.isNotEmpty)
                                  ? colors.accent
                                  : colors.accent.withOpacity(0.35),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.arrow_upward_rounded,
                                size: 20, color: colors.onAccent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Nav
            const AppBottomNav(currentIndex: 4),
          ],
        ),
            if (_menuOpen) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _menuOpen = false),
                  child: Container(color: Colors.black.withOpacity(0.28)),
                ),
              ),
              Positioned(
                top: 76,
                left: 16,
                right: 16,
                child: _buildMenuPanel(context),
              ),
            ],
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

  Widget _topicIcon(String key, Color color) {
    switch (key) {
      case 'pr':
        return ProtoIcon(ProtoIcons.pullRequest, size: 20, color: color);
      case 'build':
        return Icon(Icons.build_circle_outlined, size: 20, color: color);
      default:
        return Icon(Icons.receipt_long_outlined, size: 20, color: color);
    }
  }

  Widget _buildTopicMenu(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => setState(() => _menuOpen = !_menuOpen),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        alignment: Alignment.center,
        child: Icon(_menuOpen ? Icons.close : Icons.menu,
            size: 20, color: colors.text),
      ),
    );
  }

  Widget _buildMenuPanel(BuildContext context) {
    final colors = context.colors;
    final maxH = MediaQuery.of(context).size.height * 0.62;
    final activeTopic = _chats[_activeChat].topic;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3 quick options
              for (final e in _topicLabels.entries)
                InkWell(
                  onTap: () => _startChat(e.key),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        _topicIcon(
                            e.key,
                            activeTopic == e.key
                                ? colors.accent
                                : colors.muted),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: activeTopic == e.key
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: activeTopic == e.key
                                  ? colors.accent
                                  : colors.text,
                            ),
                          ),
                        ),
                        if (activeTopic == e.key)
                          Icon(Icons.check, size: 18, color: colors.accent),
                      ],
                    ),
                  ),
                ),

              Divider(height: 17, color: colors.border),

              // Recent chats
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                child: Text(
                  'Recent chats',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.muted,
                  ),
                ),
              ),
              for (int i = 0; i < _chats.length; i++)
                InkWell(
                  onTap: () => _openChat(i),
                  child: Container(
                    height: 46,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: i == _activeChat
                          ? colors.accent.withOpacity(0.12)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        ProtoIcon(
                    '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
                          size: 18,
                          color: colors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _chats[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: i == _activeChat
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: colors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chat {
  final String title;
  final String topic;
  final List<PlatformFile> files;
  const _Chat(this.title, this.topic, this.files);
}