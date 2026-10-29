import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Unmodifiable list with value equality.
///
/// Riverpod skips notifying listeners when a provider's new value `==` the
/// previous one. Plain lists compare by identity, so derived id lists would
/// rebuild their screens on every state event; this type prevents that.
@immutable
class ValueList<E> extends UnmodifiableListView<E> {
  ValueList(Iterable<E> source) : super(List<E>.unmodifiable(source));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValueList<E> && listEquals(this, other));

  @override
  int get hashCode => Object.hashAll(this);
}
