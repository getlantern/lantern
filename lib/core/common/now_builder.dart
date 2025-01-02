import 'dart:async';

import 'package:flutter/material.dart';

/// callback that receives the current time
mixin _NowCallback {
  void onTime(DateTime now);
}

typedef NowCalculate<T> = T Function(DateTime);

typedef NowBuild<T> = Widget Function(BuildContext context, T);

/// Builds widgets using an up-to-date DateTime.now that changes at most every
/// second. It builds in two phases:
///
/// 1. Calculate a value using the current now
/// 2. If the value has changed, update the state and build with builder
///
/// This way, it minimizes rebuilds if values don't change very quickly over
/// time.
class NowBuilder<T> extends StatefulWidget {
  final NowCalculate<T> calculate;
  final NowBuild<T> builder;

  NowBuilder({required this.calculate, required this.builder});

  @override
  _NowState createState() => _NowState<T>();
}

class _NowState<T> extends State<NowBuilder<T>> with _NowCallback {
  static final _callbacks = <_NowCallback>{};

  /// Use a single global Timer for reduced CPU overhead.
  static final _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    final now = DateTime.now();
    _callbacks.forEach((callback) => callback.onTime(now));
  });

  late T value;

  @override
  void initState() {
    super.initState();
    value = widget.calculate(DateTime.now());
    // The below seems to be needed to keep the compiler from optimizing out the
    // static timer. If you remove the below reference to _timer.isActive, the
    // timer will not run.
    _timer.isActive; // DO NOT REMOVE!!!
    _callbacks.add(this);
  }

  @override
  void dispose() {
    _callbacks.remove(this);
    super.dispose();
  }

  @override
  void onTime(DateTime now) {
    final newValue = widget.calculate(now);
    if (newValue != value) {
      setState(() {
        value = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, value);
  }
}
