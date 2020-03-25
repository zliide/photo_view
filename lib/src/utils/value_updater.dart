typedef _OnUpdate<T> = T Function(T oldValue, T newValue);

class ValueUpdater<T> {
  ValueUpdater({this.onUpdate});

  final _OnUpdate<T> onUpdate;
  T value;

  T update(T newValue) {
    final updated = onUpdate(value, newValue);
    value = newValue;
    return updated;
  }
}
