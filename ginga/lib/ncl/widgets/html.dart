import 'package:flutter/material.dart';

import 'ncl_media_widget.dart';

class HtmlWidget extends MediaWidget {
  const HtmlWidget({
    super.key,
    required super.src,
    super.media,
  });

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
