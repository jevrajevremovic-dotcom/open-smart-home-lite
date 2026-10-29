import '../../../integrations/home_assistant/websocket/ha_websocket_manager.dart';

/// Z-Wave security classes as Z-Wave JS numbers them.
enum ZwaveSecurityClass {
  s2Unauthenticated(0),
  s2Authenticated(1),
  s2AccessControl(2),
  s0Legacy(7);

  const ZwaveSecurityClass(this.value);
  final int value;

  static ZwaveSecurityClass? of(Object? v) {
    for (final c in values) {
      if (c.value == v) return c;
    }
    return null;
  }
}

/// What happens during inclusion (events of `zwave_js/add_node`).
sealed class ZwaveInclusionEvent {
  const ZwaveInclusionEvent();

  static ZwaveInclusionEvent parse(Map<String, Object?> e) =>
      switch (e['event']) {
        'inclusion started' => const ZwaveInclusionStarted(),
        'node found' => const ZwaveNodeFound(),
        'grant security classes' => ZwaveGrantRequested(
          classes: [
            if (e['requested_grant'] case {
              'securityClasses': final List<Object?> list,
            })
              for (final v in list) ?ZwaveSecurityClass.of(v),
          ],
          clientSideAuth: switch (e['requested_grant']) {
            {'clientSideAuth': final bool b} => b,
            _ => false,
          },
        ),
        'validate dsk and enter pin' => ZwaveDskRequested(
          dsk: e['dsk'] is String ? e['dsk']! as String : '',
        ),
        'interview started' => const ZwaveInterviewStarted(),
        'device registered' => ZwaveDeviceRegistered(
          name: switch (e['device']) {
            {'name': final String n} => n,
            _ => null,
          },
        ),
        'interview completed' => const ZwaveInterviewCompleted(),
        'interview failed' => const ZwaveFailed(),
        'inclusion failed' => const ZwaveFailed(),
        'inclusion stopped' => const ZwaveStopped(),
        _ => const ZwaveOther(),
      };
}

class ZwaveInclusionStarted extends ZwaveInclusionEvent {
  const ZwaveInclusionStarted();
}

class ZwaveNodeFound extends ZwaveInclusionEvent {
  const ZwaveNodeFound();
}

class ZwaveGrantRequested extends ZwaveInclusionEvent {
  const ZwaveGrantRequested({
    required this.classes,
    required this.clientSideAuth,
  });

  final List<ZwaveSecurityClass> classes;
  final bool clientSideAuth;
}

/// The device's DSK; the user enters its first five digits (the PIN from
/// the device label) to prove they have the device in hand.
class ZwaveDskRequested extends ZwaveInclusionEvent {
  const ZwaveDskRequested({required this.dsk});

  final String dsk;
}

class ZwaveInterviewStarted extends ZwaveInclusionEvent {
  const ZwaveInterviewStarted();
}

class ZwaveDeviceRegistered extends ZwaveInclusionEvent {
  const ZwaveDeviceRegistered({this.name});

  final String? name;
}

class ZwaveInterviewCompleted extends ZwaveInclusionEvent {
  const ZwaveInterviewCompleted();
}

class ZwaveFailed extends ZwaveInclusionEvent {
  const ZwaveFailed();
}

class ZwaveStopped extends ZwaveInclusionEvent {
  const ZwaveStopped();
}

class ZwaveOther extends ZwaveInclusionEvent {
  const ZwaveOther();
}

/// Z-Wave JS integration commands used by the HA frontend (not in the
/// developer docs; admin only).
class ZwaveInclusion {
  ZwaveInclusion(this._ws);

  final HaWebSocketManager _ws;

  /// Entry id of a loaded Z-Wave JS integration, `null` if there is none.
  Future<String?> entryId() async {
    final entries = await _ws.sendCommand({
      'type': 'config_entries/get',
      'domain': 'zwave_js',
    });
    if (entries is! List) return null;
    for (final e in entries) {
      if (e is Map && e['entry_id'] is String && e['state'] == 'loaded') {
        return e['entry_id']! as String;
      }
    }
    return null;
  }

  /// Starts inclusion (default strategy: S2 when the device supports it).
  /// Cancelling the stream stops inclusion.
  Stream<ZwaveInclusionEvent> include(String entryId) => _ws
      .subscribeCommand({
        'type': 'zwave_js/add_node',
        'entry_id': entryId,
        'inclusion_strategy': 0,
      })
      .map(ZwaveInclusionEvent.parse);

  Future<void> grant(
    String entryId,
    List<ZwaveSecurityClass> classes, {
    required bool clientSideAuth,
  }) => _ws.sendCommand({
    'type': 'zwave_js/grant_security_classes',
    'entry_id': entryId,
    'security_classes': [for (final c in classes) c.value],
    'client_side_auth': clientSideAuth,
  });

  Future<void> enterPin(String entryId, String pin) => _ws.sendCommand({
    'type': 'zwave_js/validate_dsk_and_enter_pin',
    'entry_id': entryId,
    'pin': pin,
  });

  /// SmartStart: the device joins by itself once powered on.
  Future<void> provisionSmartStart(String entryId, String qrCode) =>
      _ws.sendCommand({
        'type': 'zwave_js/provision_smart_start_node',
        'entry_id': entryId,
        'qr_code_string': qrCode,
      });

  /// Z-Wave QR codes are digits only and start with "90".
  static bool isZwaveQr(String s) => RegExp(r'^90\d{50,}$').hasMatch(s.trim());
}
