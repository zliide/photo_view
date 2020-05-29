import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../app_bar.dart';

class OnTapCallbacksExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: const <Widget>[
          const ExampleAppBar(
            title: "OnTapUp example",
            showGoBack: true,
          ),
          Expanded(
            child: const PhotoViewContainer(),
          )
        ],
      ),
    );
  }
}

class PhotoViewContainer extends StatefulWidget {
  const PhotoViewContainer();

  @override
  _PhotoViewContainerState createState() => _PhotoViewContainerState();
}

class _PhotoViewContainerState extends State<PhotoViewContainer> {
  List<Offset> points = [];

  void onTapUp(TapUpDetails details) {
    print(details.localPosition);
    points.add(details.localPosition);
    setState(() {});
  }

  List<Widget> buildTouchPoints() => points.map(pointToWidget).toList();

  Widget pointToWidget(Offset point) {
    return Positioned(
      top: point.dy,
      left: point.dx,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Color(0xFF00FF00)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: PhotoView.customChild(
        enableRotation: false,
        child: Center(
          child: GestureDetector(
            onTapUp: onTapUp,
            child: Stack(
              children: <Widget>[
                Container(
                  height: 500,
                  width: 1000,
                  color: Colors.amber,
                ),
                ...buildTouchPoints(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
