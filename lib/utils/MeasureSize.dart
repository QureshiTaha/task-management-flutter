import 'package:flutter/material.dart';

typedef SizeChanged = void Function(Size? size);

class MeasureSize extends StatefulWidget {
  final Widget child;
  final SizeChanged onChange;

  const MeasureSize({Key? key, required this.onChange, required this.child})
    : super(key: key);

  @override
  _MeasureSizeState createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = context.size;
      if (oldSize != size) {
        oldSize = size;
        widget.onChange(size);
      }
    });

    return widget.child;
  }
}
