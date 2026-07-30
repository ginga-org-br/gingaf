import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart' hide State;
import 'ncl_media_widget.dart';

class HtmlWidget extends MediaWidget {
  HtmlWidget({
    super.key,
    required String src,
    super.media,
  }) : super(src: src);

  @override
  State<HtmlWidget> createState() => HtmlWidgetState();
}

class HtmlWidgetState extends MediaState<HtmlWidget> {
  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    return const Center(
      child: Text(
        "HtmlWidget: Not Implemented",
        style: TextStyle(color: Colors.red),
      ),
    );
  }
}
