// Helpers for the case-insensitive nickname prefix search (`/find-friends`).
//
// The Firestore range query and every write of `nicknameLower` MUST agree on
// the exact normalization — otherwise a user becomes either unsearchable or
// unfindable. Centralizing both transforms here keeps them in lockstep.

/// High code point (U+F8FF, Unicode Private Use Area). Appended to a prefix it
/// forms an *exclusive* upper bound for a range query: every string starting
/// with the prefix sorts before `prefix + kHighCodeUnit`. Built from its code
/// unit (not a literal char) so the bound can't be silently dropped by an
/// editor that hides the glyph.
final String kHighCodeUnit = String.fromCharCode(0xF8FF);

/// Normalizes a nickname into its searchable form: trimmed + lowercased.
/// Stored as `nicknameLower` on the user doc and applied to the query term so
/// both sides of the comparison line up.
String nicknameSearchKey(String nickname) => nickname.trim().toLowerCase();

/// Exclusive upper bound for a prefix range query on [key]. Returns
/// `key + kHighCodeUnit` so `nicknameLower >= key && nicknameLower < bound`
/// matches every nickname beginning with [key].
///
/// Invariant: the bound must be strictly greater than [key]. Returning [key]
/// itself would make the range empty and every search would match nothing.
String nicknamePrefixUpperBound(String key) => '$key$kHighCodeUnit';
