import 'package:flutter/material.dart';
import 'package:photo_view_example/screens/app_bar.dart';

class CustomChildExample extends StatefulWidget {
  @override
  _CustomChildExampleState createState() => _CustomChildExampleState();
}

class _CustomChildExampleState extends State<CustomChildExample> {
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
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ExampleAppBar(
            title: "Custom child Example",
            showGoBack: true,
          ),
          Expanded(
            child: Container(),
          ),
        ],
      ),
    );
  }
}
