import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../models/nickname_search_result.dart';
import '../services/friend_service.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive_layout.dart';

/// Nickname-based discovery screen. Renders only opt-in [discoverable] users
/// (filter is server-side). Self + already-friends are filtered out by the
/// service so the UI doesn't list rows the user can't act on.
class FindFriendsPage extends StatefulWidget {
  const FindFriendsPage({super.key});

  @override
  State<FindFriendsPage> createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  final _service = FriendService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<NicknameSearchResult>? _results;
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results = null;
        _lastQuery = trimmed;
      });
      return;
    }
    setState(() {
      _loading = true;
      _lastQuery = trimmed;
    });
    try {
      final res = await _service.searchByNickname(trimmed);
      // Don't render stale results if user kept typing.
      if (!mounted || trimmed != _lastQuery) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<void> _add(NicknameSearchResult r) async {
    try {
      await _service.addFriend(r.uid);
      if (!mounted) return;
      showSuccessSnack(context, '${r.nickname} přidán/a jako kamarád.');
      // Re-run the current search so the just-added person drops off the list.
      _search(_lastQuery);
    } catch (_) {
      if (mounted) showErrorSnack(context, 'Chyba při přidávání.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.findFriendsTitle)),
      body: ResponsiveLayout(
        child: Padding(
          padding: const EdgeInsets.all(NeoTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: const InputDecoration(
                  hintText: Strings.findFriendsHint,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: NeoTheme.spaceMd),
              Expanded(child: _buildBody(isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final q = _lastQuery;
    if (q.length < 2) {
      return EmptyState(
        icon: Icons.search_rounded,
        title: Strings.findFriendsTooShort,
        subtitle: q.isEmpty ? null : '"$q"',
      );
    }
    final results = _results;
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off_rounded,
        title: Strings.findFriendsNoResults,
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => _SearchResultRow(
        result: results[i],
        isDark: isDark,
        onAdd: () => _add(results[i]),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final NicknameSearchResult result;
  final bool isDark;
  final VoidCallback onAdd;

  const _SearchResultRow({
    required this.result,
    required this.isDark,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final letter = result.nickname.isEmpty
        ? '?'
        : result.nickname[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: NeoTheme.spaceSm),
      padding: const EdgeInsets.symmetric(
        horizontal: NeoTheme.spaceMd,
        vertical: NeoTheme.spaceSm + 2,
      ),
      decoration: NeoTheme.cardDecoration(isDark: isDark),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.primaryColor,
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: NeoTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.nickname,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${Strings.findFriendsLevel} ${result.level}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text(Strings.findFriendsAdd),
          ),
        ],
      ),
    );
  }
}
