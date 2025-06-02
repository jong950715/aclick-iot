import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ListNotifier<T, K> extends Notifier<List<T>> {
  K getKey(T item);

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