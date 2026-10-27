import 'package:xml/xml.dart';

import 'elements.dart';
import 'ncl_document.dart';
import 'parser.dart';

abstract class NclRulePlugin {
  bool? evaluate(Element ruleElement, NclDocument document);
}

abstract class NclParserPlugin {
  String get targetTag;
  Element? parseTag(XmlElement node, NclParser parser) => null;
  (Head, Body)? parseDocument(XmlElement root, NclParser parser) => null;
}

abstract class NclTickPlugin {
  void onTick(Duration elapsed, NclDocument document);
}
