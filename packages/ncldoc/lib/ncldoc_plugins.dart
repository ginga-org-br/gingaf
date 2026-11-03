import 'ncl_document.dart';

export 'package:xml/xml.dart' show XmlElement;
export 'schema.dart';

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

abstract class NclKeyPlugin {
  bool onKey(String keyCode, String keyType, NclDocument document);
}
