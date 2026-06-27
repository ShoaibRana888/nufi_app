// lib/features/chat/screens/chat_context_debug_page.dart
//
// ⚠️ DEBUG / TESTING ONLY — remove before production release.
// Surfaced from the chat app bar only when `kDebugMode` is true (see
// chat_page.dart). Lets us inspect exactly what the AI coach sees (the daily
// and weekly chat context) and manage per-activity-type sharing defaults.
//
// To remove for deploy: delete this file and the guarded nav entry in
// chat_page.dart that pushes it.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';

class ChatContextDebugPage extends StatefulWidget {
  final UserProfile userProfile;

  const ChatContextDebugPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<ChatContextDebugPage> createState() => _ChatContextDebugPageState();
}

class _ChatContextDebugPageState extends State<ChatContextDebugPage> {
  final ChatApi _chatApi = ChatApi();
  final SharingApi _sharingApi = SharingApi();

  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _dailyContext;
  List<Map<String, dynamic>> _recentWeeks = [];
  Map<String, bool> _defaults = {};
  bool _loading = false;

  static const _activityTypes = [
    'meal', 'exercise', 'weight', 'sleep', 'water', 'steps', 'supplement', 'period',
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final userId = widget.userProfile.id!;

      // Force a rebuild from source data before fetching, so the debug view
      // reflects the latest logs. Past weekly contexts are otherwise served
      // from cache and won't pick up newly added/back-dated activity.
      await _chatApi.rebuildChatContext(userId, date: _selectedDate);
      for (var w = 0; w < 4; w++) {
        final weekDate = DateTime.now().subtract(Duration(days: 7 * w));
        await _chatApi.rebuildWeeklyContext(
          userId,
          date: DateFormat('yyyy-MM-dd').format(weekDate),
        );
      }

      final daily = await _chatApi.getChatContext(userId, date: _selectedDate);
      final weeks = await _chatApi.getRecentWeeks(userId, weeks: 4);
      final defaults = await _sharingApi.getDefaults(userId);
      if (!mounted) return;
      setState(() {
        _dailyContext = daily;
        _recentWeeks = weeks;
        _defaults = defaults;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load context: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadAll();
    }
  }

  Future<void> _toggleDefault(String type, bool shared) async {
    setState(() => _defaults[type] = !shared ? false : true);
    // setDefaults treats `true` as "reset to implicit shared default".
    final updated = await _sharingApi.setDefaults(
      widget.userProfile.id!,
      {type: shared},
    );
    if (!mounted) return;
    setState(() => _defaults = updated);
  }

  String _pretty(Object? data) =>
      const JsonEncoder.withIndent('  ').convert(data ?? {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Context (debug)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _loadAll),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date selector
                  Row(
                    children: [
                      const Text('Day: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('EEE, MMM d, yyyy').format(_selectedDate)),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                  const Divider(),

                  // Per-type sharing defaults
                  const Text('Sharing defaults for new entries',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text(
                    'Off = new entries of this type are hidden from the AI coach by default.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  ..._activityTypes.map((type) {
                    final shared = _defaults[type] != false;
                    return SwitchListTile(
                      dense: true,
                      title: Text(type[0].toUpperCase() + type.substring(1)),
                      value: shared,
                      onChanged: (v) => _toggleDefault(type, v),
                    );
                  }),
                  const Divider(),

                  // Daily context
                  const Text('Daily context (what the AI sees today)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _JsonBlock(text: _pretty(_dailyContext)),
                  const SizedBox(height: 16),

                  // Weekly context
                  Text('Recent weeks (${_recentWeeks.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _JsonBlock(text: _pretty(_recentWeeks)),
                ],
              ),
            ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  final String text;
  const _JsonBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: Colors.greenAccent,
          height: 1.4,
        ),
      ),
    );
  }
}
