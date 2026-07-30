import 'package:flutter/material.dart';
import 'package:ncldoc/ncl_document.dart' hide State;
import 'ncl_media_widget.dart';

class SsmlWidget extends MediaWidget {
  SsmlWidget({
    super.key,
    required String src,
    super.media,
  }) : super(src: src);

  @override
  State<SsmlWidget> createState() => SsmlWidgetState();
}

class SsmlWidgetState extends MediaState<SsmlWidget> {
  @override
  void initState() {
    super.initState();
    parseProperties(widget.media);
  }

  @override
  Widget buildWidgetContent(BuildContext context) {
    return const Center(
        child: Text("SsmlWidget: Not Implemented",
            style: TextStyle(color: Colors.red)));
  }
}
