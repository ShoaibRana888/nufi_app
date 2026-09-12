import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/data/services/connectivity_service.dart';

/// The connectivity gate must not take the interface report as a verdict.
///
/// connectivity_plus reports `none` on the iOS Simulator while the host has
/// working network. ADR-0005 gates login and onboarding on this answer, so a
/// false "offline" hard-blocks sign-up. The rule: an interface means online;
/// no interface means ask the backend before saying offline.
void main() {
  ConnectivityService build({
    required List<ConnectivityResult> interfaces,
    required bool backendReachable,
    void Function()? onProbe,
  }) =>
      ConnectivityService.withChecks(
        checkInterface: () async => interfaces,
        probe: () async {
          onProbe?.call();
          if (!backendReachable) throw Exception('no route to host');
        },
      );

  test('an interface means online, without probing', () async {
    var probed = false;
    final svc = build(
      interfaces: [ConnectivityResult.wifi],
      backendReachable: false, // would fail if consulted
      onProbe: () => probed = true,
    );

    expect(await svc.isConnected(), true);
    expect(probed, false);
  });

  test('no interface but a reachable backend is online', () async {
    // The simulator case: connectivity_plus says none, the network works.
    final svc = build(
      interfaces: [ConnectivityResult.none],
      backendReachable: true,
    );

    expect(await svc.isConnected(), true);
  });

  test('no interface and an unreachable backend is offline', () async {
    final svc = build(
      interfaces: [ConnectivityResult.none],
      backendReachable: false,
    );

    expect(await svc.isConnected(), false);
  });

  test('a stale probe result cannot overwrite a newer state', () async {
    // A `none` event starts a probe; wifi comes back before it resolves; the
    // probe then fails. The onboarding banner assigns every callback straight
    // to its state, so the late false would have re-shown "Offline Mode"
    // after connectivity was already restored.
    final probeGate = Completer<void>();
    final svc = ConnectivityService.withChecks(
      checkInterface: () async => [ConnectivityResult.none],
      probe: () => probeGate.future,
    );
    final reported = <bool>[];

    final stale = svc.onInterfaceChangeForTest(
      [ConnectivityResult.none], reported.add);   // starts the probe
    await svc.onInterfaceChangeForTest(
      [ConnectivityResult.wifi], reported.add);   // newer: reports true now
    probeGate.completeError(Exception('timed out'));
    await stale;

    // The stale probe's false was discarded.
    expect(reported, [true]);
  });

  test('a failing interface check falls through to the probe', () async {
    final svc = ConnectivityService.withChecks(
      checkInterface: () async => throw Exception('plugin unavailable'),
      probe: () async {},
    );

    expect(await svc.isConnected(), true);
  });
}
