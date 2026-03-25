import 'dart:ui';

import 'package:flutter/material.dart';

/// Theme data for [PillSegmentedButton].
///
/// Apply globally via [ThemeData.extensions] or locally via
/// [PillSegmentedButtonTheme]. The theme resolves defaults from
/// [ColorScheme] via [resolve].
@immutable
class PillSegmentedButtonThemeData extends ThemeExtension<PillSegmentedButtonThemeData> {
  const PillSegmentedButtonThemeData({
    this.selectedColor,
    this.selectedForegroundColor,
    this.unselectedColor,
    this.unselectedForegroundColor,
    this.borderRadius,
    this.spacing,
    this.padding,
    this.textStyle,
  });

  /// Background color of the selected segment.
  final Color? selectedColor;

  /// Foreground (text/icon) color of the selected segment.
  final Color? selectedForegroundColor;

  /// Background color of unselected segments.
  final Color? unselectedColor;

  /// Foreground (text/icon) color of unselected segments.
  final Color? unselectedForegroundColor;

  /// Border radius of each pill segment.
  final BorderRadius? borderRadius;

  /// Spacing between segments.
  final double? spacing;

  /// Padding inside each segment.
  final EdgeInsetsGeometry? padding;

  /// Text style for segment labels (color is overridden by foreground colors).
  final TextStyle? textStyle;

  /// Returns a fully resolved copy with no null fields, using [colorScheme]
  /// to fill in any unset values.
  PillSegmentedButtonThemeData resolve(ColorScheme colorScheme) {
    return PillSegmentedButtonThemeData(
      selectedColor: selectedColor ?? colorScheme.primary,
      selectedForegroundColor: selectedForegroundColor ?? colorScheme.onPrimary,
      unselectedColor: unselectedColor ?? colorScheme.surface,
      unselectedForegroundColor: unselectedForegroundColor ?? colorScheme.onSecondaryContainer,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      spacing: spacing ?? 6.0,
      padding: padding ?? const EdgeInsets.symmetric(vertical: 10),
      textStyle: textStyle ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    );
  }

  @override
  PillSegmentedButtonThemeData copyWith({
    Color? selectedColor,
    Color? selectedForegroundColor,
    Color? unselectedColor,
    Color? unselectedForegroundColor,
    BorderRadius? borderRadius,
    double? spacing,
    EdgeInsetsGeometry? padding,
    TextStyle? textStyle,
  }) {
    return PillSegmentedButtonThemeData(
      selectedColor: selectedColor ?? this.selectedColor,
      selectedForegroundColor: selectedForegroundColor ?? this.selectedForegroundColor,
      unselectedColor: unselectedColor ?? this.unselectedColor,
      unselectedForegroundColor: unselectedForegroundColor ?? this.unselectedForegroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      spacing: spacing ?? this.spacing,
      padding: padding ?? this.padding,
      textStyle: textStyle ?? this.textStyle,
    );
  }

  @override
  PillSegmentedButtonThemeData lerp(PillSegmentedButtonThemeData? other, double t) {
    if (other is! PillSegmentedButtonThemeData) return this;
    return PillSegmentedButtonThemeData(
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t),
      selectedForegroundColor: Color.lerp(selectedForegroundColor, other.selectedForegroundColor, t),
      unselectedColor: Color.lerp(unselectedColor, other.unselectedColor, t),
      unselectedForegroundColor: Color.lerp(unselectedForegroundColor, other.unselectedForegroundColor, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      spacing: lerpDouble(spacing, other.spacing, t),
      padding: EdgeInsetsGeometry.lerp(padding, other.padding, t),
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t),
    );
  }
}

/// An inherited widget that provides [PillSegmentedButtonThemeData] to
/// descendant [PillSegmentedButton] widgets.
class PillSegmentedButtonTheme extends InheritedWidget {
  const PillSegmentedButtonTheme({super.key, required this.data, required super.child});

  final PillSegmentedButtonThemeData data;

  static PillSegmentedButtonThemeData? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PillSegmentedButtonTheme>()?.data;
  }

  @override
  bool updateShouldNotify(PillSegmentedButtonTheme oldWidget) => data != oldWidget.data;
}

/// A segmented button where each segment is an independent pill shape
/// with rounded corners on all sides and gaps between segments.
///
/// Themed via [PillSegmentedButtonThemeData] (as a [ThemeExtension] or
/// via [PillSegmentedButtonTheme] in the widget tree). Falls back to
/// [ColorScheme] defaults.
class PillSegmentedButton<T> extends StatelessWidget {
  const PillSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<({T value, Widget label})> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final inherited = PillSegmentedButtonTheme.of(context);
    final extension_ = Theme.of(context).extension<PillSegmentedButtonThemeData>();
    final theme = (inherited ?? extension_ ?? const PillSegmentedButtonThemeData()).resolve(
      Theme.of(context).colorScheme,
    );

    return Container(
      decoration: BoxDecoration(color: theme.unselectedColor, borderRadius: theme.borderRadius),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) SizedBox(width: theme.spacing!),
            Expanded(child: _buildSegment(context, segments[i], theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildSegment(BuildContext context, ({T value, Widget label}) segment, PillSegmentedButtonThemeData theme) {
    final isSelected = selected.contains(segment.value);
    final fgColor = isSelected ? theme.selectedForegroundColor! : theme.unselectedForegroundColor!;

    return Material(
      color: isSelected ? theme.selectedColor! : theme.unselectedColor!,
      borderRadius: theme.borderRadius!,
      child: InkWell(
        borderRadius: theme.borderRadius!,
        onTap: () => onSelectionChanged({segment.value}),
        child: Container(
          padding: theme.padding!,
          alignment: Alignment.center,
          child: DefaultTextStyle.merge(
            style: theme.textStyle!.copyWith(color: fgColor),
            child: IconTheme.merge(
              data: IconThemeData(color: fgColor, size: 18),
              child: segment.label,
            ),
          ),
        ),
      ),
    );
  }
}
