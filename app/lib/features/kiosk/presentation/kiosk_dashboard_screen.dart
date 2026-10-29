import 'package:flutter/material.dart';

import '../../../core/widgets/status_widgets.dart';
import '../../clap/clap_listener.dart';
import 'kiosk_columns.dart';

/// Text is enlarged on the wall panel so it is readable from a distance.
const double kioskTextScale = 1.2;

/// Wraps kiosk pages with larger text.
class KioskScale extends StatelessWidget {
  const KioskScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = MediaQuery.textScalerOf(context).scale(1);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(base * kioskTextScale)),
      child: child,
    );
  }
}

/// The wall panel: rooms on the left, the home or a room in the middle,
/// details on the right (see [KioskColumnsLayout]).
class KioskDashboardScreen extends StatelessWidget {
  const KioskDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: KioskClapListener(child: MockModeBanner(child: KioskColumnsLayout())),
  );
}
