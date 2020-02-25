import 'package:flutter/material.dart';
import 'package:photo_view_example/screens/examples/controller_example.dart';
import 'package:photo_view_example/screens/examples/custom_child_examples.dart';
import 'package:photo_view_example/screens/examples/dialog_example.dart';
import 'package:photo_view_example/screens/examples/full_screen_examples.dart';
import 'package:photo_view_example/screens/examples/gallery/gallery_example.dart';
import 'package:photo_view_example/screens/examples/hero_example.dart';
import 'package:photo_view_example/screens/examples/inline_examples.dart';
import 'package:photo_view_example/screens/examples/ontap_callbacks.dart';
import 'package:photo_view_example/screens/examples/rotation_examples.dart';
import './app_bar.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ExampleAppBar(title: "Photo View"),
          Container(
            padding: const EdgeInsets.all(20.0),
            child: const Text(
              "See bellow examples of some of the most common photo view usage cases",
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
          Expanded(
            child: ListView(
              children: <Widget>[
                HomeScreenLink(text: "Full screen", routeBuilder: (_) => FullScreenExamples(),),
                HomeScreenLink(text: "Controller", routeBuilder: (_) => ControllerExample(),),
                HomeScreenLink(text: "Part of the screen", routeBuilder: (_) => InlineExample(),),
                HomeScreenLink(text: "Rotation gesture", routeBuilder: (_) => RotationExamples(),),
                HomeScreenLink(text: "Hero animation", routeBuilder: (_) => HeroExample(),),
                HomeScreenLink(text: "Gallery", routeBuilder: (_) => GalleryExample(),),
                HomeScreenLink(text: "Custom child", routeBuilder: (_) => CustomChildExample(),),
                HomeScreenLink(text: "Integrated to dialogs", routeBuilder: (_) => DialogExample(),),
                HomeScreenLink(text: "PnTap callbacks", routeBuilder: (_) => OnTapCallbacksExample(),),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class HomeScreenLink extends StatelessWidget {

  const HomeScreenLink({Key key, this.routeBuilder, this.text}) : super(key: key);

  final WidgetBuilder routeBuilder;
  final String text;

  VoidCallback onPressed(BuildContext context) => () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: routeBuilder,
      ),
    );
  };

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      padding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 20.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed(context),
    );
  }
}
