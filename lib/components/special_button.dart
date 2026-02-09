import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// This is a button that pushes the bare minimum onto you, it doesn't even respect button themes - unless you tell it to
class SpecialButton extends StatefulWidget {
  const SpecialButton({
    super.key,
    this.child,
    this.color,
    this.onPressed,
    this.useButtonTheme = false,
    this.decoration,
  });

  final Widget? child;
  final Color? color;
  final bool useButtonTheme;
  final BoxDecoration? decoration;

  final GestureTapCallback? onPressed;

  @override
  SpecialButtonState createState() => SpecialButtonState();
}

class SpecialButtonState extends State<SpecialButton> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Platform.isAndroid ? _buildAndroid() : _buildGeneric();
  }

  Widget _buildAndroid() {
    TextStyle? textStyle;
    if (widget.useButtonTheme) {
      textStyle = Theme.of(context).textTheme.labelLarge;
    }

    return Material(
      textStyle: textStyle,
      child: Ink(
        decoration: widget.decoration,
        color: widget.color,
        child: InkWell(onTap: widget.onPressed, child: widget.child),
      ),
    );
  }

  Widget _buildGeneric() {
    var textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    if (widget.useButtonTheme) {
      textStyle = CupertinoTheme.of(context).textTheme.actionTextStyle;
    }

    return Container(
      decoration: widget.decoration,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onPressed,
        child: Semantics(
          button: true,
          child: FadeTransition(
            opacity: _opacityAnimation!,
            child: DefaultTextStyle(style: textStyle, child: Container(color: widget.color, child: widget.child)),
          ),
        ),
      ),
    );
  }

  // Eyeballed values. Feel free to tweak.
  static const Duration kFadeOutDuration = Duration(milliseconds: 10);
  static const Duration kFadeInDuration = Duration(milliseconds: 100);
  final Tween<double> _opacityTween = Tween<double>(begin: 1.0);

  AnimationController? _animationController;
  Animation<double>? _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 200), value: 0.0, vsync: this);
    _opacityAnimation = _animationController!.drive(CurveTween(curve: Curves.decelerate)).drive(_opacityTween);
    _setTween();
  }

  @override
  void didUpdateWidget(SpecialButton old) {
    super.didUpdateWidget(old);
    _setTween();
  }

  void _setTween() {
    _opacityTween.end = 0.4;
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  bool _buttonHeldDown = false;

  void _handleTapDown(TapDownDetails event) {
    if (!_buttonHeldDown) {
      _buttonHeldDown = true;
      _animate();
    }
  }

  void _handleTapUp(TapUpDetails event) {
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
  }

  void _handleTapCancel() {
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
  }

  void _animate() {
    if (_animationController == null || _animationController!.isAnimating) {
      return;
    }

    final bool wasHeldDown = _buttonHeldDown;
    final TickerFuture ticker =
        _buttonHeldDown
            ? _animationController!.animateTo(1.0, duration: kFadeOutDuration)
            : _animationController!.animateTo(0.0, duration: kFadeInDuration);

    ticker.then<void>((void value) {
      if (mounted && wasHeldDown != _buttonHeldDown) {
        _animate();
      }
    });
  }
}
