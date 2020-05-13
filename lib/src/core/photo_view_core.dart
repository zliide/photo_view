import 'package:flutter/widgets.dart';
import 'package:photo_view/src/utils/value_updater.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:photo_view/photo_view.dart'
    show
        PhotoViewHeroAttributes,
        PhotoViewImageTapDownCallback,
        PhotoViewImageTapUpCallback,
        ScaleStateCycle;
import 'package:photo_view/src/controller/photo_view_controller.dart';
import 'package:photo_view/src/controller/photo_view_controller_delegate.dart';
import 'package:photo_view/src/controller/photo_view_scalestate_controller.dart';
import 'package:photo_view/src/utils/photo_view_utils.dart';
import 'package:photo_view/src/core/photo_view_gesture_detector.dart';
import 'package:photo_view/src/core/photo_view_hit_corners.dart';

const _defaultDecoration = const BoxDecoration(
  color: const Color.fromRGBO(0, 0, 0, 1.0),
);

typedef MathF<T extends num> = T Function(T, T);
typedef VFn = Vector4 Function(double x, double y, double z, double w);

/// Internal widget in which controls all animations lifecycle, core responses
/// to user gestures, updates to  the controller state and mounts the entire PhotoView Layout
class PhotoViewCore extends StatefulWidget {
  const PhotoViewCore({
    Key key,
    @required this.imageProvider,
    @required this.backgroundDecoration,
    @required this.gaplessPlayback,
    @required this.heroAttributes,
    @required this.enableRotation,
    @required this.onTapUp,
    @required this.onTapDown,
    @required this.gestureDetectorBehavior,
    @required this.controller,
    @required this.scaleBoundaries,
    @required this.scaleStateCycle,
    @required this.scaleStateController,
    @required this.basePosition,
    @required this.tightMode,
    @required this.filterQuality,
  })  : customChild = null,
        super(key: key);

  const PhotoViewCore.customChild({
    Key key,
    @required this.customChild,
    @required this.backgroundDecoration,
    @required this.heroAttributes,
    @required this.enableRotation,
    @required this.onTapUp,
    @required this.onTapDown,
    @required this.gestureDetectorBehavior,
    @required this.controller,
    @required this.scaleBoundaries,
    @required this.scaleStateCycle,
    @required this.scaleStateController,
    @required this.basePosition,
    @required this.tightMode,
    @required this.filterQuality,
  })  : imageProvider = null,
        gaplessPlayback = false,
        super(key: key);

  final Decoration backgroundDecoration;
  final ImageProvider imageProvider;
  final bool gaplessPlayback;
  final PhotoViewHeroAttributes heroAttributes;
  final bool enableRotation;
  final Widget customChild;

  final PhotoViewControllerBase controller;
  final PhotoViewScaleStateController scaleStateController;
  final ScaleBoundaries scaleBoundaries;
  final ScaleStateCycle scaleStateCycle;
  final Alignment basePosition;

  final PhotoViewImageTapUpCallback onTapUp;
  final PhotoViewImageTapDownCallback onTapDown;

  final HitTestBehavior gestureDetectorBehavior;
  final bool tightMode;

  final FilterQuality filterQuality;

  @override
  State<StatefulWidget> createState() {
    return PhotoViewCoreState();
  }

  bool get hasCustomChild => customChild != null;
}

class PhotoViewCoreState extends State<PhotoViewCore>
    with
        TickerProviderStateMixin,
        PhotoViewControllerDelegate,
        HitCornersDetector {
  Matrix4 matrix = Matrix4.identity();

  double _scaleBefore = 0.0;

  @override
  double get scale => matrix.storage[0];

  @override
  Offset get position {
    final t = matrix.getTranslation();
    return Offset(t.x, t.y);
  }

  final ValueUpdater<Offset> _translationUpdater = ValueUpdater(
    onUpdate: (oldVal, newVal) => newVal - oldVal,
  );
  final ValueUpdater<double> _scaleUpdater = ValueUpdater(
    onUpdate: (oldVal, newVal) => newVal / oldVal,
  );

  AnimationController _scaleAnimationController;
  Animation<double> _scaleAnimation;

  AnimationController _positionAnimationController;
  Animation<Offset> _positionAnimation;

  PhotoViewHeroAttributes get heroAttributes => widget.heroAttributes;

  ScaleBoundaries cachedScaleBoundaries;

  void handleScaleAnimation() {
    setState(() {
      matrix..scale(1 / scale)..scale(_scaleAnimation.value);
      scale = _scaleAnimation.value;
    });
  }

  void handlePositionAnimate() {
    setState(() {
      matrix.setTranslation(Vector3(
          _positionAnimation.value.dx, _positionAnimation.value.dy, 0.0));
      controller.position = _positionAnimation.value;
    });
  }

  void onScaleStart(ScaleStartDetails details) {
    _scaleAnimationController.stop();
    _positionAnimationController.stop();

    _scaleBefore = scale;

    _translationUpdater.value = alignFocalPoint(details.focalPoint);
    _scaleUpdater.value = 1.0;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      var translationDeltaMatrix = Matrix4.identity();
      var scaleDeltaMatrix = Matrix4.identity();

      final alignedFocalPoint = alignFocalPoint(details.focalPoint);

      // handle matrix translating
      final translationDelta = _translationUpdater.update(alignedFocalPoint);
      translationDeltaMatrix = _translate(translationDelta);
      matrix = translationDeltaMatrix * matrix;

      final RenderBox renderBox = context.findRenderObject();
      final focalPoint = renderBox.globalToLocal(alignedFocalPoint);

      // handle matrix scaling
      if (details.scale != 1.0) {
        final _oldScale = scale;
        final maxScale = scaleBoundaries.maxScale;
        final minScale = scaleBoundaries.minScale;

        final scaleDelta = _scaleUpdater.update(details.scale);
        scaleDeltaMatrix = _scale(scaleDelta, focalPoint);

        if (_oldScale > (maxScale + 0.25)) {
          updateMultiple(
              scale: scale,
              position:
                  clampPosition(position: alignedFocalPoint * details.scale));

          return;
        }

        if (_oldScale < minScale) {
          updateMultiple(
            scale: scale,
          );

          return;
        }
      }
      matrix = scaleDeltaMatrix * matrix;

      updateScaleStateFromNewScale(scale);

      updateMultiple(
          scale: scale,
          position: clampPosition(position: alignedFocalPoint * details.scale));

      _clampMatrix();
    });
  }

  void onScaleEnd(ScaleEndDetails details) {
    final _scale = scale;
    final _position = controller.position;
    final maxScale = scaleBoundaries.maxScale;
    final minScale = scaleBoundaries.minScale;

    //animate back to maxScale if gesture exceeded the maxScale specified
    if (_scale > maxScale) {
      final scaleComebackRatio = maxScale / _scale;
      animateScale(_scale, maxScale);
      animatePosition(
        _position,
        clampPosition(
          position: _position * scaleComebackRatio,
          scale: maxScale,
        ),
      );
      return;
    }

    //animate back to minScale if gesture fell smaller than the minScale specified
    if (_scale < minScale) {
      final scaleComebackRatio = minScale / _scale;
      animateScale(_scale, minScale);
      animatePosition(
        _position,
        clampPosition(
          position: _position * scaleComebackRatio,
          scale: minScale,
        ),
      );
      return;
    }
    // get magnitude from gesture velocity
    final magnitude = details.velocity.pixelsPerSecond.distance;

    // animate velocity only if there is no scale change and a significant magnitude
    if (_scaleBefore / _scale == 1.0 && magnitude >= 400.0) {
      final direction = details.velocity.pixelsPerSecond / magnitude;
      animatePosition(
        _position,
        clampPosition(position: _position + direction * 100.0),
      );
    }
  }

  void onDoubleTap() {
    nextScaleState();
  }

  void animateScale(double from, double to) {
    _scaleAnimation = Tween<double>(
      begin: from,
      end: to,
    ).animate(_scaleAnimationController);
    _scaleAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animatePosition(Offset from, Offset to) {
    _positionAnimation = Tween<Offset>(begin: from, end: to)
        .animate(_positionAnimationController);
    _positionAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {}
  }

  @override
  void initState() {
    super.initState();
    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(handleScaleAnimation);

    _scaleAnimationController.addStatusListener(onAnimationStatus);

    _positionAnimationController = AnimationController(vsync: this)
      ..addListener(handlePositionAnimate);

    startListeners();
    addAnimateOnScaleStateUpdate(animateOnScaleStateUpdate);

    cachedScaleBoundaries = widget.scaleBoundaries;

    matrix.scale(cachedScaleBoundaries.initialScale);
  }

  void animateOnScaleStateUpdate(double prevScale, double nextScale) {
    animateScale(prevScale, nextScale);
    animatePosition(controller.position, Offset.zero);
  }

  @override
  void dispose() {
    _scaleAnimationController.removeStatusListener(onAnimationStatus);
    _scaleAnimationController.dispose();
    _positionAnimationController.dispose();
    super.dispose();
  }

  void onTapUp(TapUpDetails details) {
    widget.onTapUp?.call(context, details, controller.value);
  }

  void onTapDown(TapDownDetails details) {
    widget.onTapDown?.call(context, details, controller.value);
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need a recalc on the scale
    if (widget.scaleBoundaries != cachedScaleBoundaries) {
      markNeedsScaleRecalc = true;
      cachedScaleBoundaries = widget.scaleBoundaries;
    }

    return StreamBuilder(
        stream: controller.outputStateStream,
        initialData: controller.prevValue,
        builder: (
          BuildContext context,
          AsyncSnapshot<PhotoViewControllerValue> snapshot,
        ) {
          if (snapshot.hasData) {
            final useImageScale = widget.filterQuality != FilterQuality.none;

            final Widget customChildLayout = CustomSingleChildLayout(
              delegate: _CenterWithOriginalSizeDelegate(
                scaleBoundaries.childSize,
                basePosition,
                useImageScale,
              ),
              child: _buildHero(),
            );

            return PhotoViewGestureDetector(
              child: Container(
                constraints: widget.tightMode
                    ? BoxConstraints.tight(scaleBoundaries.childSize * scale)
                    : null,
                child: Center(
                  child: Transform(
                    child: customChildLayout,
                    transform: matrix,
                    alignment: basePosition,
                  ),
                ),
                decoration: widget.backgroundDecoration ?? _defaultDecoration,
              ),
              onDoubleTap: nextScaleState,
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              onScaleEnd: onScaleEnd,
              hitDetector: this,
              onTapUp: widget.onTapUp == null ? null : onTapUp,
              onTapDown: widget.onTapDown == null ? null : onTapDown,
            );
          } else {
            return Container();
          }
        });
  }

  Widget _buildHero() {
    return heroAttributes != null
        ? Hero(
            tag: heroAttributes.tag,
            createRectTween: heroAttributes.createRectTween,
            flightShuttleBuilder: heroAttributes.flightShuttleBuilder,
            placeholderBuilder: heroAttributes.placeholderBuilder,
            transitionOnUserGestures: heroAttributes.transitionOnUserGestures,
            child: _buildChild(),
          )
        : _buildChild();
  }

  Widget _buildChild() {
    return widget.hasCustomChild
        ? widget.customChild
        : Image(
            image: widget.imageProvider,
            gaplessPlayback: widget.gaplessPlayback ?? false,
            filterQuality: widget.filterQuality,
            width: scaleBoundaries.childSize.width * 1.00000000001,
            fit: BoxFit.contain,
          );
  }

  Offset alignFocalPoint(Offset focalPoint) {
    return focalPoint - basePosition.alongSize(scaleBoundaries.outerSize);
  }

  void _clampMatrix() {
    final _scale = scale;

    matrix.scale(1 / _scale);

    final pos = -position;

    final computedWidth = scaleBoundaries.childSize.width * _scale;
    final computedHeight = scaleBoundaries.childSize.height * _scale;

    final screenWidth = scaleBoundaries.outerSize.width;
    final screenHeight = scaleBoundaries.outerSize.height;

    final widthDiff = computedWidth - screenWidth;
    final heightDiff = computedHeight - screenHeight;

    final positionX = basePosition.x;
    final positionY = basePosition.y;

    final maxX = ((positionX + 1).abs() / 2) * widthDiff;
    final minX = -maxX;
    final maxY = ((positionY + 1).abs() / 2) * heightDiff;
    final minY = -maxY;

    if (screenWidth < computedWidth) {
      if (pos.dx < minX) {
        matrix.leftTranslate(pos.dx - minX, 0.0);
      }
      if (maxX < pos.dx) {
        matrix.leftTranslate(pos.dx - maxX, 0.0);
      }
    } else {
      matrix.leftTranslate(pos.dx, 0.0);
    }
    if (screenHeight < computedHeight) {
      if (pos.dy < minY) {
        matrix.leftTranslate(0.0, pos.dy - minY);
      }
      if (maxY < pos.dy) {
        matrix.leftTranslate(0.0, pos.dy - maxY);
      }
    } else {
      matrix.leftTranslate(0.0, pos.dy);
    }

    matrix.scale(_scale);
  }

  Matrix4 _translate(Offset translation) {
    final dx = translation.dx;
    final dy = translation.dy;

    //  ..[0]  = 1       # x scale
    //  ..[5]  = 1       # y scale
    //  ..[10] = 1       # diagonal "one"
    //  ..[12] = dx      # x translation
    //  ..[13] = dy      # y translation
    //  ..[15] = 1       # diagonal "one"
    return Matrix4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);
  }

  Matrix4 _scale(double scale, Offset focalPoint) {
    final dx = (1 - scale) * focalPoint.dx;
    final dy = (1 - scale) * focalPoint.dy;

    //  ..[0]  = scale   # x scale
    //  ..[5]  = scale   # y scale
    //  ..[10] = 1       # diagonal "one"
    //  ..[12] = dx      # x translation
    //  ..[13] = dy      # y translation
    //  ..[15] = 1       # diagonal "one"
    return Matrix4(scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, dx, dy, 0, 1);
  }
}

class _CenterWithOriginalSizeDelegate extends SingleChildLayoutDelegate {
  const _CenterWithOriginalSizeDelegate(
    this.subjectSize,
    this.basePosition,
    this.useImageScale,
  );

  final Size subjectSize;
  final Alignment basePosition;
  final bool useImageScale;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final offsetX =
        ((size.width - (useImageScale ? childSize.width : subjectSize.width)) /
                2) *
            (basePosition.x + 1);
    final offsetY = ((size.height -
                (useImageScale ? childSize.height : subjectSize.height)) /
            2) *
        (basePosition.y + 1);
    return Offset(offsetX, offsetY);
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return useImageScale
        ? const BoxConstraints()
        : BoxConstraints.tight(subjectSize);
  }

  @override
  bool shouldRelayout(_CenterWithOriginalSizeDelegate oldDelegate) {
    return oldDelegate != this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CenterWithOriginalSizeDelegate &&
          runtimeType == other.runtimeType &&
          subjectSize == other.subjectSize &&
          basePosition == other.basePosition &&
          useImageScale == other.useImageScale;

  @override
  int get hashCode =>
      subjectSize.hashCode ^ basePosition.hashCode ^ useImageScale.hashCode;
}
