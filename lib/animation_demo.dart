import 'package:flutter/material.dart';
import 'layoutablelist/animator/animation_widget.dart';

class AnimationDemoPage extends StatefulWidget {
  const AnimationDemoPage({super.key});

  @override
  State<AnimationDemoPage> createState() => _AnimationDemoPageState();
}

class _AnimationDemoPageState extends State<AnimationDemoPage> {
  // 动画模式
  bool _useSpring = false;

  // 曲线选项
  final _curveOptions = <String, Curve>{
    'easeInOut': Curves.easeInOut,
    'easeIn': Curves.easeIn,
    'easeOut': Curves.easeOut,
    'bounceOut': Curves.bounceOut,
    'elasticOut': Curves.elasticOut,
    'decelerate': Curves.decelerate,
    'linear': Curves.linear,
  };
  String _selectedCurve = 'easeInOut';
  int _durationMs = 600;

  // 弹簧参数
  double _stiffness = 100.0;
  double _damping = 10.0;

  // 动画目标状态（toggle）
  bool _toggled = false;

  // AnimParams
  late ValueNotifier<AnimationParams> _animParamsNotifier;

  @override
  void initState() {
    super.initState();
    _animParamsNotifier = ValueNotifier(_createAnimParams(toggled: false));
  }

  AnimationParams _createAnimParams({required bool toggled}) {
    final springConfig = _useSpring
        ? SpringConfig(stiffness: _stiffness, damping: _damping)
        : null;
    final curveConfig = _useSpring
        ? null
        : CurveConfig(
            curve: _curveOptions[_selectedCurve]!,
            durationMs: _durationMs,
          );

    return AnimationParams(
      springConfig: springConfig,
      curveConfig: curveConfig,
      offset: toggled ? const Offset(150, 0) : Offset.zero,
      toOffset: toggled ? const Offset(150, 0) : Offset.zero,
      scale: toggled ? 0.5 : 1.0,
      toScale: toggled ? 0.5 : 1.0,
      alpha: toggled ? 0.3 : 1.0,
      toAlpha: toggled ? 0.3 : 1.0,
    );
  }

  void _toggle() {
    setState(() {
      _toggled = !_toggled;
    });
    final oldParams = _animParamsNotifier.value;
    final springConfig = _useSpring
        ? SpringConfig(stiffness: _stiffness, damping: _damping)
        : null;
    final curveConfig = _useSpring
        ? null
        : CurveConfig(
            curve: _curveOptions[_selectedCurve]!,
            durationMs: _durationMs,
          );

    _animParamsNotifier.value = AnimationParams(
      springConfig: springConfig,
      curveConfig: curveConfig,
      offset: oldParams.offset,
      toOffset: _toggled ? const Offset(150, 0) : Offset.zero,
      scale: oldParams.scale,
      toScale: _toggled ? 0.5 : 1.0,
      alpha: oldParams.alpha,
      toAlpha: _toggled ? 0.3 : 1.0,
    );
  }

  void _reset() {
    _toggled = false;
    _animParamsNotifier.value = _createAnimParams(toggled: false);
  }

  void _rebuildAnimParams() {
    _animParamsNotifier.value = _createAnimParams(toggled: _toggled);
  }

  @override
  void dispose() {
    _animParamsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AnimatedWidgetX Demo')),
      body: Column(
        children: [
          // 动画预览区域
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey.shade100,
              child: Center(
                child: AnimationWidget(
                  animParams: _animParamsNotifier,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.star, color: Colors.white, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 控制面板
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 模式切换
                  Row(
                    children: [
                      const Text('弹簧模式'),
                      Switch(
                        value: _useSpring,
                        onChanged: (v) {
                          setState(() {
                            _useSpring = v;
                          });
                          _rebuildAnimParams();
                        },
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _toggle,
                        child: Text(_toggled ? '还原' : '播放'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _reset,
                        child: const Text('重置'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_useSpring) ...[
                    // 弹簧参数
                    _buildSlider(
                      label: 'Stiffness',
                      value: _stiffness,
                      min: 10,
                      max: 500,
                      onChanged: (v) {
                        _stiffness = v;
                        _rebuildAnimParams();
                      },
                    ),
                    _buildSlider(
                      label: 'Damping',
                      value: _damping,
                      min: 1,
                      max: 40,
                      onChanged: (v) {
                        _damping = v;
                        _rebuildAnimParams();
                      },
                    ),
                    Text(
                      'Critical damping: ${SpringConfig(stiffness: _stiffness, damping: _damping).criticalDamping.toStringAsFixed(1)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...[
                    // 曲线参数
                    DropdownButtonFormField<String>(
                      value: _selectedCurve,
                      decoration: const InputDecoration(
                        labelText: 'Curve',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _curveOptions.keys
                          .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          _selectedCurve = v;
                          _rebuildAnimParams();
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildSlider(
                      label: 'Duration (ms)',
                      value: _durationMs.toDouble(),
                      min: 100,
                      max: 2000,
                      divisions: 19,
                      onChanged: (v) {
                        _durationMs = v.round();
                        _rebuildAnimParams();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text('$label: ${value.toStringAsFixed(0)}'),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
