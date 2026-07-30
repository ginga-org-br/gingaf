import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart' hide State;
import 'ncl_media_widget.dart';

class TextWidget extends MediaWidget {
  TextWidget({
    super.key,
    required String src,
    super.media,
  }) : super(src: src);

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
