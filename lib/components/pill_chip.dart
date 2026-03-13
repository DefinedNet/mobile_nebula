import 'package:flutter/material.dart';

/// Theme data for [PillChip].
///
/// Apply globally via [ThemeData.extensions] or locally via
/// [PillChipTheme]. The theme resolves defaults from [ColorScheme]
/// via [resolve].
@immutable
class PillChipThemeData extends ThemeExtension<PillChipThemeData> {
  const PillChipThemeData({this.backgroundColor, this.textColor, this.textStyle, this.borderRadius, this.padding});

  /// Background color of the chip.
  final Color? backgroundColor;

  /// Foreground (text/icon) color of the chip.
  final Color? textColor;

  /// Text style for the chip label (color is overridden by [textColor]).
  final TextStyle? textStyle;

  /// Border radius of the pill shape.
  final BorderRadius? borderRadius;

  /// Padding inside the chip.
  final EdgeInsetsGeometry? padding;

  /// Returns a fully resolved copy with no null fields, using [colorScheme]
  /// to fill in any unset values.
  PillChipThemeData resolve(ColorScheme colorScheme) {
    return PillChipThemeData(
      backgroundColor: backgroundColor ?? colorScheme.tertiaryContainer,
      textColor: textColor ?? colorScheme.onTertiaryContainer,
      textStyle: textStyle,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    );
  }

  @override
  PillChipThemeData copyWith({
    Color? backgroundColor,
    Color? textColor,
    TextStyle? textStyle,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    return PillChipThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      textStyle: textStyle ?? this.textStyle,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
    );
  }

  @override
  PillChipThemeData lerp(PillChipThemeData? other, double t) {
    if (other is! PillChipThemeData) return this;
    return PillChipThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      textColor: Color.lerp(textColor, other.textColor, t),
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
    );
  }
}

/// An inherited widget that provides [PillChipThemeData] to descendant
/// [PillChip] widgets.
class PillChipTheme extends InheritedWidget {
  const PillChipTheme({super.key, required this.data, required super.child});

  final PillChipThemeData data;

  static PillChipThemeData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PillChipTheme>()?.data;
  }

  @override
  bool updateShouldNotify(PillChipTheme oldWidget) => data != oldWidget.data;
}

/// Border style for [PillChip].
enum PillChipBorder {
  /// Filled background, no border.
  none,

  /// Dashed border, no fill.
  dashed,

  /// Solid border, no fill.
  solid,
}

/// A pill-shaped chip with a label and optional trailing icon.
///
/// Themed via [PillChipThemeData] (as a [ThemeExtension] or via
/// [PillChipTheme] in the widget tree). Falls back to [ColorScheme] defaults.
class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, this.trailingIcon, this.onTap, this.border = PillChipBorder.none});

  /// The text label displayed inside the chip.
  final String label;

  /// Optional trailing icon (e.g. a close/remove icon).
  final IconData? trailingIcon;

  /// Called when the chip is tapped.
  final VoidCallback? onTap;

  /// Border style of the chip.
  final PillChipBorder border;

  @override
  Widget build(BuildContext context) {
    final inherited = PillChipTheme.of(context);
    final extension_ = Theme.of(context).extension<PillChipThemeData>();
    final theme = (inherited ?? extension_ ?? const PillChipThemeData()).resolve(Theme.of(context).colorScheme);
    final resolvedTextStyle = (theme.textStyle ?? Theme.of(context).textTheme.titleMedium!).copyWith(
      color: theme.textColor,
    );

    final isFilled = border == PillChipBorder.none;

    Widget chip = Container(
      padding: theme.padding,
      decoration: BoxDecoration(
        color: isFilled ? theme.backgroundColor : null,
        borderRadius: theme.borderRadius,
        border: border == PillChipBorder.solid ? Border.all(color: theme.backgroundColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: resolvedTextStyle),
          if (trailingIcon != null) ...[const SizedBox(width: 4), Icon(trailingIcon, color: theme.textColor, size: 16)],
        ],
      ),
    );

    if (border == PillChipBorder.dashed) {
      chip = CustomPaint(
        painter: _DashedBorderPainter(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: theme.borderRadius!,
          strokeWidth: 1.0,
        ),
        child: chip,
      );
    }

    if (onTap == null) return chip;

    return GestureDetector(onTap: onTap, child: chip);
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.borderRadius, this.strokeWidth = 1.0});

  final Color color;
  final BorderRadius borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = borderRadius.toRRect(Offset.zero & size);
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    const dashWidth = 4.0;
    const dashGap = 4.0;

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || borderRadius != oldDelegate.borderRadius || strokeWidth != oldDelegate.strokeWidth;
}
