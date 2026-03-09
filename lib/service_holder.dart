class ServiceHolder<T> {
  T? _target;

  T? get target => _target;

  void attach(T t) {
    if (_target != null) {
      throw StateError(
        'ServiceHolder is already bound. '
            'Each ServiceHolder can only be bound once. '
            'If you need to rebind, call detach() first.',
      );
    }
    _target = t;
  }

  void detach() {
    _target = null;
  }
}