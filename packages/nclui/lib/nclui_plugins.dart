import 'package:flutter/widgets.dart';
import 'package:ncldoc/ncl_document.dart';

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
