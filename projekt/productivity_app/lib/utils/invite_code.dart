import 'dart:math';

/// Charset for invite codes. 31 chars total (23 letters + 8 digits).
/// Ambiguous chars excluded: no 0/O, no 1/I/L. Easier to read aloud and
/// to type from a screenshot.
const _kInviteCharset = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const _kInviteCodeLength = 8;

final _rng = Random.secure();

/// Returns an 8-character random invite code from [_kInviteCharset].
///
/// Uses [Random.secure] so codes are cryptographically unguessable.
String generateInviteCode() => String.fromCharCodes(List.generate(
      _kInviteCodeLength,
      (_) => _kInviteCharset.codeUnitAt(_rng.nextInt(_kInviteCharset.length)),
    ));
