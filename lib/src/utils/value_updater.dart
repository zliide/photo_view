typedef _OnUpdate<T> = T Function(T oldValue, T newValue);

class ValueUpdater<T> {
  ValueUpdater({required this.onUpdate});

  final _OnUpdate<T> onUpdate;
  late T value;

  T update(T newValue) {
    final updated = onUpdate(value, newValue);
    value = newValue;
    return updated;
  }
}
