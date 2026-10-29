import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/app_preferences.dart';
import 'kiosk_controller.dart';

/// What the wall panel knows about one household member (a Home Assistant
/// `person`): a personal PIN, which lets them do critical things (unlock,
/// disarm) — members without one (children) cannot — their own quick
/// controls, and their birthday (the panel celebrates).
@immutable
class KioskPerson {
  const KioskPerson({
    this.pinHash,
    this.pinSalt,
    this.quickControls,
    this.birthday,
  });

  factory KioskPerson.fromJson(Map<Object?, Object?> json) => KioskPerson(
    pinHash: json['pinHash'] as String?,
    pinSalt: json['pinSalt'] as String?,
    quickControls: switch (json['quickControls']) {
      final List<Object?> list => [
        for (final k in list.take(24))
          if (k is String) k,
      ],
      _ => null,
    },
    birthday: switch (RegExp(r'^(\d{2})-(\d{2})$')
        .firstMatch('${json['birthday']}')) {
      final m? => (int.parse(m[1]!), int.parse(m[2]!)),
      _ => null,
    },
  );

  final String? pinHash;
  final String? pinSalt;

  /// `null`: the panel's shared quick controls.
  final List<String>? quickControls;

  /// (month, day); the year is not kept.
  final (int, int)? birthday;

  bool get hasPin => pinHash != null && pinSalt != null;

  bool get isEmpty => !hasPin && quickControls == null && birthday == null;

  KioskPerson copyWith({
    String? pinHash,
    String? pinSalt,
    bool clearPin = false,
    List<String>? quickControls,
    bool clearQuickControls = false,
    (int, int)? birthday,
    bool clearBirthday = false,
  }) => KioskPerson(
    pinHash: clearPin ? null : pinHash ?? this.pinHash,
    pinSalt: clearPin ? null : pinSalt ?? this.pinSalt,
    quickControls: clearQuickControls
        ? null
        : quickControls ?? this.quickControls,
    birthday: clearBirthday ? null : birthday ?? this.birthday,
  );

  Map<String, Object?> toJson() => {
    if (hasPin) ...{'pinHash': pinHash, 'pinSalt': pinSalt},
    'quickControls': ?quickControls,
    if (birthday case (final m, final d))
      'birthday':
          '${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
  };
}

/// Per-member panel settings by person id. This device's own: never in a
/// settings backup (PIN hashes).
class KioskPeopleController extends Notifier<Map<String, KioskPerson>> {
  static const _key = 'kiosk.people';

  @override
  Map<String, KioskPerson> build() {
    final json = ref.watch(appPreferencesProvider).readJson(_key) ?? {};
    return {
      for (final e in json.entries)
        if (e.value case final Map<Object?, Object?> v)
          e.key: KioskPerson.fromJson(v),
    };
  }

  Future<void> _change(
    String personId,
    KioskPerson Function(KioskPerson) change,
  ) async {
    final person = change(state[personId] ?? const KioskPerson());
    state = {
      for (final e in state.entries)
        if (e.key != personId) e.key: e.value,
      if (!person.isEmpty) personId: person,
    };
    await ref.read(appPreferencesProvider).writeJson(_key, {
      for (final e in state.entries) e.key: e.value.toJson(),
    });
  }

  /// Returns `false` when [pin] is not 4–8 digits.
  Future<bool> setPin(String personId, String pin) async {
    if (!PinHasher.validPin.hasMatch(pin)) return false;
    final salt = PinHasher.newSalt();
    final hash = PinHasher.hash(pin, salt);
    await _change(personId, (p) => p.copyWith(pinHash: hash, pinSalt: salt));
    return true;
  }

  Future<void> removePin(String personId) =>
      _change(personId, (p) => p.copyWith(clearPin: true));

  /// `null` goes back to the shared quick controls.
  Future<void> setQuickControls(String personId, List<String>? keys) => _change(
    personId,
    (p) => p.copyWith(quickControls: keys, clearQuickControls: keys == null),
  );

  /// (month, day), or `null` to forget it.
  Future<void> setBirthday(String personId, (int, int)? birthday) => _change(
    personId,
    (p) => p.copyWith(birthday: birthday, clearBirthday: birthday == null),
  );

  /// The member whose PIN this is, if any.
  String? personWithPin(String pin) {
    for (final e in state.entries) {
      final p = e.value;
      if (p.hasPin && PinHasher.verify(pin, p.pinSalt!, p.pinHash!)) {
        return e.key;
      }
    }
    return null;
  }
}

final kioskPeopleProvider =
    NotifierProvider<KioskPeopleController, Map<String, KioskPerson>>(
      KioskPeopleController.new,
    );

/// Who is using the wall panel right now (a person id), chosen by tapping
/// their picture; `null` = everyone. Forgotten when the screen dims or the
/// panel returns to its start after a while, and when kiosk mode ends.
class KioskUserController extends Notifier<String?> {
  @override
  String? build() {
    ref
      ..listen(kioskDimmedProvider, (_, dimmed) {
        if (dimmed) state = null;
      })
      ..listen(kioskActiveProvider, (_, active) {
        if (!active) state = null;
      });
    return null;
  }

  /// Tapping the one already chosen goes back to everyone.
  void toggle(String personId) => state = state == personId ? null : personId;

  void select(String? personId) => state = personId;
}

final kioskUserProvider = NotifierProvider<KioskUserController, String?>(
  KioskUserController.new,
);

/// The quick controls for whoever is at the panel: their own, or shared.
final kioskQuickControlsProvider = Provider<List<String>>((ref) {
  final user = ref.watch(kioskUserProvider);
  final own = user == null
      ? null
      : ref.watch(kioskPeopleProvider.select((m) => m[user]?.quickControls));
  return own ?? ref.watch(kioskSettingsProvider.select((s) => s.quickControls));
});

/// Whether critical actions on the panel need a PIN: when the panel or any
/// member has one.
final kioskCriticalPinRequiredProvider = Provider<bool>(
  (ref) =>
      ref.watch(kioskSettingsProvider).hasPin ||
      ref.watch(kioskPeopleProvider).values.any((p) => p.hasPin),
);
