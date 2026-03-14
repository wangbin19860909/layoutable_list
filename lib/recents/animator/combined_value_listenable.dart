import 'package:flutter/foundation.dart';

/// 组合两个 ValueListenable 为一个
/// 
/// 当任何一个输入的 ValueListenable 变化时，都会触发通知
/// 类似于 RxJava 的 combineLatest
class CombinedValueListenable<A, B> extends ValueNotifier<(A, B)> {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  
  CombinedValueListenable(this.first, this.second) 
      : super((first.value, second.value)) {
    first.addListener(_update);
    second.addListener(_update);
  }
  
  void _update() {
    value = (first.value, second.value);
  }
  
  @override
  void dispose() {
    first.removeListener(_update);
    second.removeListener(_update);
    super.dispose();
  }
}
