import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart' hide State;
import 'ncl_media_widget.dart';

class TextWidget extends MediaWidget {
  const TextWidget({super.key, required super.uri, super.media});

  @override
  State<TextWidget> createState() => TextWidgetState();
}

class TextWidgetState extends MediaState<TextWidget> {
  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    return const Center(
        child: Text("TextWidget: Not Implemented",
            style: TextStyle(color: Colors.red)));
  }
}
