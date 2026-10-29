import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../authentication/application/web_login.dart';
import '../../settings/presentation/language_selector.dart';
import '../../../app/brand.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Center(child: BrandLogo()),
                const SizedBox(height: 24),
                Text(
                  Brand.name(l10n),
                  style: textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcomeTitle,
                  style: textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.welcomeBody,
                  style: textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lan_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.welcomeLocalFirst,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(l10n.chooseLanguage, style: textTheme.titleSmall),
                const SizedBox(height: 8),
                const LanguageSelector(),
                if (ref.watch(loginErrorProvider) != null) ...[
                  const SizedBox(height: 24),
                  InlineNotice.error(l10n.loginFailed),
                ],
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: () {
                    ref.read(loginErrorProvider.notifier).set(null);
                    context.push(AppRoutes.connectServer);
                  },
                  child: Text(l10n.getStarted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
