import 'ncl_document.dart';

typedef Head = List<Element>;
typedef Body = Context;

class Element {
  final Map<String, String> rawAttributes;
  String? get id => rawAttributes['id'];
  final List<Element> children = [];
  Element({this.rawAttributes = const {}});
}

class Port extends Element {
  String? get component => rawAttributes['component'];
  String? get interface => rawAttributes['interface'];
  Port({super.rawAttributes});
}

class Bind extends Element {
  String? get role => rawAttributes['role'];
  String? get component => rawAttributes['component'];
  String? get interface => rawAttributes['interface'];
  Bind({super.rawAttributes});
}

class Property extends Element {
  String? get name => rawAttributes['name'];
  String? get value => rawAttributes['value'];
  Property({super.rawAttributes});
}

class Area extends Element {
  String? get begin => rawAttributes['begin'];
  String? get end => rawAttributes['end'];
  Area({super.rawAttributes});
}

class Link extends Element {
  Link({super.rawAttributes});
}

class Descriptor extends Element {
  Descriptor({super.rawAttributes});
}

class Region extends Element {
  Region({super.rawAttributes});
}

class Connector extends Element {
  Connector({super.rawAttributes});
}

abstract class Node extends Element {
  Composition? parent;
  int time = 0;
  int? explicitDurMs;
  late final Event _mainEvt = Event(
    type: EventType.PRESENTATION,
    targetNode: this,
    isMain: true,
  );
  final Map<String, Event> _areaEvents = {};
  Event getMainEvent() => _mainEvt;
  State getMainState() => _mainEvt.state;
  Event getAreaEvent(String areaId) {
    return _areaEvents.putIfAbsent(
      areaId,
      () => Event(
        type: EventType.PRESENTATION,
        targetNode: this,
        interfaceId: areaId,
      ),
    );
  }

  State getAreaEventState(String areaId) => getAreaEvent(areaId).state;
  List<Property> getProperties() => children.whereType<Property>().toList();
  List<Area> getAreas() => children.whereType<Area>().toList();
  Node({super.rawAttributes});
}

abstract class Composition extends Node {
  int activeNodes = 0;
  List<Node> getNodes() => children.whereType<Node>().toList();
  Composition({super.rawAttributes});
}

class Context extends Composition {
  List<Port> getPorts() => children.whereType<Port>().toList();
  List<Link> getLinks() => children.whereType<Link>().toList();
  Context({super.rawAttributes});
}

class Switch extends Composition {
  Switch({super.rawAttributes});
}

class Media extends Node {
  final String mimeType;
  final String uri;
  String? get src => rawAttributes['src'];
  Media({
    super.rawAttributes,
    this.uri = '',
    this.mimeType = 'application/x-ginga-time',
  });
}

class AVMedia extends Media {
  AVMedia({
    super.rawAttributes,
    super.uri,
    super.mimeType,
  });
}

class Settings extends Media {
  Settings({
    super.rawAttributes,
    super.mimeType = 'application/x-ncl-settings',
  });
}
