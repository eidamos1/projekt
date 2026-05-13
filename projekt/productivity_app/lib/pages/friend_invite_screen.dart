import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/neo_theme.dart';
import '../constants/strings.dart';
import '../services/friend_service.dart';
import '../utils/context_extensions.dart';
import '../utils/ui_helpers.dart';

class FriendInviteScreen extends StatefulWidget {
  final String code;
  const FriendInviteScreen({super.key, required this.code});

  @override
  State<FriendInviteScreen> createState() => _FriendInviteScreenState();
}

class _FriendInviteScreenState extends State<FriendInviteScreen> {
  final _service = FriendService();
  Map<String, dynamic>? _profile;
  String? _errorMsg;
  bool _alreadyFriend = false;
  bool _selfInvite = false;
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final code = widget.code.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMsg = Strings.inviteNotFound;
        _loading = false;
      });
      return;
    }
    final p = await _service.resolveInvite(code);
    if (!mounted) return;
    if (p == null) {
      setState(() {
        _errorMsg = Strings.inviteNotFound;
        _loading = false;
      });
      return;
    }
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (p['uid'] == myUid) {
      setState(() {
        _profile = p;
        _selfInvite = true;
        _loading = false;
      });
      return;
    }
    if (myUid != null) {
      final edge = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .doc(p['uid'] as String)
          .get();
      if (!mounted) return;
      if (edge.exists) {
        setState(() {
          _profile = p;
          _alreadyFriend = true;
          _loading = false;
        });
        return;
      }
    }
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (_profile == null) return;
    setState(() => _adding = true);
    try {
      await _service.addFriend(_profile!['uid'] as String);
      if (mounted) {
        showSuccessSnack(context, Strings.friendAddedToast);
        Navigator.pushReplacementNamed(context, '/profile');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _adding = false);
        showErrorSnack(context, Strings.friendAddError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.inviteScreenTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(NeoTheme.spaceLg),
            child: _loading
                ? const CircularProgressIndicator()
                : _buildBody(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_errorMsg != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_errorMsg!, textAlign: TextAlign.center),
          const SizedBox(height: NeoTheme.spaceMd),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(Strings.goBack),
          ),
        ],
      );
    }
    final nick = (_profile?['nickname'] as String?) ?? '—';
    final letter = nick.isEmpty ? '?' : nick[0].toUpperCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: context.primaryColor,
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: NeoTheme.spaceMd),
        Text(
          nick,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: NeoTheme.spaceMd),
        if (_selfInvite)
          const Text(Strings.inviteOwnCode, textAlign: TextAlign.center)
        else if (_alreadyFriend)
          Text(
            '$nick ${Strings.inviteAlreadyFriendSuffix}',
            textAlign: TextAlign.center,
          )
        else
          Text(
            '${Strings.inviteAddPromptPrefix}$nick${Strings.inviteAddPromptSuffix}',
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: NeoTheme.spaceLg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(Strings.cancel),
              ),
            ),
            if (!_selfInvite && !_alreadyFriend) ...[
              const SizedBox(width: NeoTheme.spaceSm),
              Expanded(
                child: ElevatedButton(
                  onPressed: _adding ? null : _add,
                  child: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(Strings.inviteAddButton),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
