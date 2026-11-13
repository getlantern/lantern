import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A column whose child at [globeIndex], the globe, gets the height
/// [viewportHeight] leaves after the others, and never less than
/// [minGlobeHeight]: in a scroll view, the content fills the window when it
/// fits, and scrolls when it does not. A plain Column cannot do this in a
/// scroll view, and measuring the other children first is not possible
/// either, as the globe sizes itself from its constraints alone.
class GlobeColumn extends MultiChildRenderObjectWidget {
  const GlobeColumn({
    super.key,
    required this.viewportHeight,
    required this.minGlobeHeight,
    this.globeIndex = 0,
    required super.children,
  });

  final double viewportHeight;
  final double minGlobeHeight;
  final int globeIndex;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderGlobeColumn(viewportHeight, minGlobeHeight, globeIndex);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlobeColumn renderObject,
  ) {
    renderObject
      ..viewportHeight = viewportHeight
      ..minGlobeHeight = minGlobeHeight
      ..globeIndex = globeIndex;
  }
}

/// Parent data of [GlobeColumn]'s children.
class GlobeColumnParentData extends ContainerBoxParentData<RenderBox> {}

/// The render object behind [GlobeColumn].
class RenderGlobeColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, GlobeColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, GlobeColumnParentData> {
  RenderGlobeColumn(
    this._viewportHeight,
    this._minGlobeHeight,
    this._globeIndex,
  );

  double _viewportHeight;
  set viewportHeight(double value) {
    if (value == _viewportHeight) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  double _minGlobeHeight;
  set minGlobeHeight(double value) {
    if (value == _minGlobeHeight) return;
    _minGlobeHeight = value;
    markNeedsLayout();
  }

  int _globeIndex;
  set globeIndex(int value) {
    if (value == _globeIndex) return;
    _globeIndex = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! GlobeColumnParentData) {
      child.parentData = GlobeColumnParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    RenderBox? globe = firstChild;
    for (var i = 0; i < _globeIndex && globe != null; i++) {
      globe = childAfter(globe);
    }
    if (globe == null) {
      size = constraints.smallest;
      return;
    }
    // The others size themselves, as wide as the column.
    final column = BoxConstraints(minWidth: width, maxWidth: width);
    var rest = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      if (identical(child, globe)) continue;
      child.layout(column, parentUsesSize: true);
      rest += child.size.height;
    }
    final globeHeight = math.max(_minGlobeHeight, _viewportHeight - rest);
    globe.layout(
      BoxConstraints.tightFor(width: width, height: globeHeight),
      parentUsesSize: true,
    );
    var top = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      (child.parentData! as GlobeColumnParentData).offset = Offset(0, top);
      top += child.size.height;
    }
    size = constraints.constrain(Size(width, top));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
