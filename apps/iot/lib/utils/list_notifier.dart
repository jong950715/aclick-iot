import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ListNotifier<T, K> extends Notifier<List<T>> {
  K getKey(T item);

  void updateWith({
    required K key,
    required T Function(T existing) update,
  }) {
    final idx = state.indexWhere((e) => getKey(e) == key);
    if (idx == -1) return;

    final existing = state[idx];
    final newItem = update(existing);

    // 한 번만 순회하여 해당 인덱스 위치 값을 대체
    state = [
      for (int i = 0; i < state.length; i++)
        if (i == idx) newItem else state[i]
    ];
  }

  void upsert(T item) {
    state = [
      for (final e in state)
        if (getKey(e) == getKey(item)) item else e
    ];
  }

  void removeByKey(K key) {
    state = state.where((e) => getKey(e) != key).toList();
  }

  T? findByKey(K key) => state.where((e) => getKey(e) == key).firstOrNull;
}