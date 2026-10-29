import '../../app/localization/l10n.dart';
import 'app_failure.dart';

/// User-facing text for a failure. Never includes technical details.
String failureMessage(AppLocalizations l10n, AppFailure failure) =>
    switch (failure.kind) {
      FailureKind.network => l10n.failureNetwork,
      FailureKind.timeout => l10n.failureTimeout,
      FailureKind.authentication => l10n.failureAuthentication,
      FailureKind.authorization => l10n.failureAuthorization,
      FailureKind.validation => l10n.failureValidation,
      FailureKind.parsing => l10n.failureParsing,
      FailureKind.server => l10n.failureServer,
      FailureKind.certificate => l10n.failureCertificate,
      FailureKind.unavailableEntity => l10n.failureUnavailableEntity,
      FailureKind.unsupportedFeature => l10n.failureUnsupportedFeature,
      FailureKind.webSocket => l10n.failureWebSocket,
      FailureKind.storage => l10n.failureStorage,
      FailureKind.confirmationRequired => l10n.failureConfirmationRequired,
      FailureKind.unknown => l10n.failureUnknown,
    };
