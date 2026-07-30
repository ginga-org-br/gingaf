import 'package:flutter/material.dart';

import 'ncl_media_widget.dart';

class SsmlWidget extends MediaWidget {
  const SsmlWidget({
    super.key,
    required super.src,
    super.media,
  });

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
