import 'package:flutter/widgets.dart';
import 'package:ginga_app/ncl_document.dart';

abstract class NclMediaPlugin {
  bool canHandle(String src, String? mimeType);

  Widget buildWidget({
    Key? key,
    required String src,
    String? mimeType,
    Media? media,
    NclDocument? document,
    FocusNode? focusNode,
  });
}
