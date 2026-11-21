import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/flow_widgets.dart';

/// S38 – edit a playbook (admins; PATCH /api/admin/playbooks/:id).
/// The action type is fixed: the executor only runs allow-listed actions.
/// Pops with `true` when something was saved.
class S38PlaybookEditScreen extends StatefulWidget {
  final Map<String, dynamic>? playbook;

  const S38PlaybookEditScreen({super.key, this.playbook});

  @override
  State<S38PlaybookEditScreen> createState() => _S38PlaybookEditScreenState();
}

class _S38PlaybookEditScreenState extends State<S38PlaybookEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late bool _enabled;
  late bool _requiresApproval;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.playbook ?? const {};
    _name = TextEditingController(text: p['name']?.toString() ?? '');
    _description = TextEditingController(text: p['description']?.toString() ?? '');
    _enabled = p['enabled'] == true;
    _requiresApproval = p['requires_approval'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = widget.playbook?['id']?.toString();
    if (id == null) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService().updatePlaybook(id, {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'enabled': _enabled,
        'requires_approval': _requiresApproval,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playbook saved.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException && e.statusCode == 403
            ? 'Only admins can change playbooks.'
            : e is ApiException
                ? e.message
                : 'Could not save the playbook.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final p = widget.playbook;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(title: 'Edit playbook', subtitle: p?['action_type']?.toString() ?? ''),
            Expanded(
              child: p == null
                  ? const FlowMessage(icon: Icons.playlist_play, message: 'Open a playbook from the Playbooks screen.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _description,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(labelText: 'Description'),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Enabled', style: TextStyle(color: colors.text)),
                          subtitle: Text('Operators can request it', style: TextStyle(color: colors.muted)),
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Requires approval', style: TextStyle(color: colors.text)),
                          subtitle: Text('A second person must approve every run', style: TextStyle(color: colors.muted)),
                          value: _requiresApproval,
                          onChanged: (v) => setState(() => _requiresApproval = v),
                        ),
                        const SizedBox(height: 8),
                        FlowSection(
                          label: 'Action',
                          text: '${p['action_type']} – fixed. The executor only runs allow-listed actions on allow-listed services.',
                        ),
                        if (_error != null) Text(_error!, style: TextStyle(color: colors.critical)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: colors.onAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_saving ? 'Saving…' : 'Save', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
