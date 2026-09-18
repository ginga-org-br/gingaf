import 'ncl_document.dart';

typedef Head = List<Element>;
typedef Body = Context;

class Element {
  final Map<String, String> rawAttributes;
  String? get id => rawAttributes['id'];
  final List<Element> children = [];
  Element? parent;
  String? xmlTagName;
  Element({Map<String, String> rawAttributes = const {}, this.xmlTagName})
      : rawAttributes = Map<String, String>.from(rawAttributes);

  Iterable<Element> get descendants sync* {
    for (final child in children) {
      yield child;
      yield* child.descendants;
    }
  }
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

class BindParam extends Element {
  String? get name => rawAttributes['name'];
  String? get value => rawAttributes['value'];
  BindParam({super.rawAttributes});
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
  String? get xconnector => rawAttributes['xconnector'];
  List<Bind> get binds => children.whereType<Bind>().toList();
  Link({super.rawAttributes});
}

class DescriptorParam extends Element {
  String? get name => rawAttributes['name'];
  String? get value => rawAttributes['value'];
  DescriptorParam({super.rawAttributes});
}

class Descriptor extends Element {
  String? get region => rawAttributes['region'];
  String? get transIn => rawAttributes['transIn'];
  String? get transOut => rawAttributes['transOut'];
  String? get focusIndex => rawAttributes['focusIndex'];
  String? get moveUp => rawAttributes['moveUp'];
  String? get moveDown => rawAttributes['moveDown'];
  String? get moveLeft => rawAttributes['moveLeft'];
  String? get moveRight => rawAttributes['moveRight'];
  String? get explicitDur => rawAttributes['explicitDur'];
  int? get explicitDurMs => NclParser.parseDurStr(explicitDur);
  String? get focusBorderColor => rawAttributes['focusBorderColor'];
  String? get focusBorderWidth => rawAttributes['focusBorderWidth'];
  String? get focusBorderTransparency =>
      rawAttributes['focusBorderTransparency'];
  String? get focusSrc => rawAttributes['focusSrc'];
  String? get focusSelSrc => rawAttributes['focusSelSrc'];
  String? get selectIndex => rawAttributes['selectIndex'];
  List<DescriptorParam> get descriptorParams =>
      children.whereType<DescriptorParam>().toList();
  Descriptor({super.rawAttributes});
}

class Region extends Element {
  String? get title => rawAttributes['title'];
  String? get left => rawAttributes['left'];
  String? get right => rawAttributes['right'];
  String? get top => rawAttributes['top'];
  String? get bottom => rawAttributes['bottom'];
  String? get width => rawAttributes['width'];
  String? get height => rawAttributes['height'];
  String? get zIndex => rawAttributes['zIndex'];
  Region({super.rawAttributes});
}

class Connector extends Element {
  Connector({super.rawAttributes});
}

class Transition extends Element {
  String? get type => rawAttributes['type'];
  String? get subtype => rawAttributes['subtype'];
  String? get dur => rawAttributes['dur'];
  int? get durMs => NclParser.parseDurStr(dur);
  String? get startProgress => rawAttributes['startProgress'];
  String? get endProgress => rawAttributes['endProgress'];
  String? get direction => rawAttributes['direction'];
  Transition({super.rawAttributes});
}

class Rule extends Element {
  String? get varName => rawAttributes['var'];
  String? get comparator => rawAttributes['comparator'];
  String? get value => rawAttributes['value'];
  Rule({super.rawAttributes});
}

class AssessmentStatement extends Element {
  String? get comparator => rawAttributes['comparator'];
  List<AttributeAssessment> get attributeAssessments =>
      children.whereType<AttributeAssessment>().toList();
  List<ValueAssessment> get valueAssessments =>
      children.whereType<ValueAssessment>().toList();
  AssessmentStatement({super.rawAttributes});
}

class AttributeAssessment extends Element {
  String? get role => rawAttributes['role'];
  String? get eventType => rawAttributes['eventType'];
  String? get key => rawAttributes['key'];
  String? get attributeType => rawAttributes['attributeType'];
  AttributeAssessment({super.rawAttributes});
}

class ValueAssessment extends Element {
  String? get value => rawAttributes['value'];
  ValueAssessment({super.rawAttributes});
}

class SimpleCondition extends Element {
  String? get role => rawAttributes['role'];
  String? get eventType => rawAttributes['eventType'];
  String? get key => rawAttributes['key'];
  String? get transition => rawAttributes['transition'];
  String? get min => rawAttributes['min'];
  String? get max => rawAttributes['max'];
  String? get qualifier => rawAttributes['qualifier'];
  SimpleCondition({super.rawAttributes});
}

class CompoundCondition extends Element {
  String? get operator => rawAttributes['operator'];
  List<Element> get conditions => children
      .where(
        (c) =>
            c is SimpleCondition ||
            c is CompoundCondition ||
            c is AssessmentStatement,
      )
      .toList();
  CompoundCondition({super.rawAttributes});
}

abstract class Node extends Element {
  @override
  Composition? get parent => super.parent as Composition?;
  @override
  set parent(covariant Composition? value) => super.parent = value;
  int time = 0;
  int? explicitDurMs;
  late final NclEvent _mainEvt = NclEvent(
    type: NclEventType.presentation,
    targetNode: this,
    isMain: true,
  );
  final Map<String, NclEvent> _areaNclEvents = {};
  final Map<String, NclEvent> _propertyNclEvents = {};
  NclEvent getMainNclEvent() => _mainEvt;
  NclStateType getMainState() => _mainEvt.state;
  NclEvent getAreaNclEvent(String areaId) {
    return _areaNclEvents.putIfAbsent(
      areaId,
      () => NclEvent(
        type: NclEventType.presentation,
        targetNode: this,
        interfaceId: areaId,
      ),
    );
  }

  NclEvent getPropertyNclEvent(String propertyName) {
    return _propertyNclEvents.putIfAbsent(
      propertyName,
      () => NclEvent(
        type: NclEventType.attribution,
        targetNode: this,
        propertyName: propertyName,
      ),
    );
  }

  void setPropertyValue(String name, String value) {
    final existing = children.whereType<Property>().firstWhere(
      (p) => p.name == name,
      orElse: () {
        final newProp = Property(rawAttributes: {'name': name, 'value': value});
        children.add(newProp);
        newProp.parent = this;
        return newProp;
      },
    );
    existing.rawAttributes['value'] = value;
  }

  NclStateType getAreaNclEventState(String areaId) =>
      getAreaNclEvent(areaId).state;
  List<Property> getProperties() => children.whereType<Property>().toList();
  List<Area> getAreas() => children.whereType<Area>().toList();
  Node({super.rawAttributes});
}

abstract class Composition extends Node {
  int activeNodes = 0;
  List<Node> getNodes() => children.whereType<Node>().toList();
  List<Media> getMedias() => children.whereType<Media>().toList();
  List<Context> getContexts() => children.whereType<Context>().toList();
  List<Switch> getSwitches() => children.whereType<Switch>().toList();
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
  String? get descriptorId => rawAttributes['descriptor'];
  Media({
    super.rawAttributes,
    this.uri = '',
    this.mimeType = 'application/x-ginga-time',
  });
}

class AVMedia extends Media {
  AVMedia({super.rawAttributes, super.uri, super.mimeType});
}

class Settings extends Media {
  Settings({
    super.rawAttributes,
    super.mimeType = 'application/x-ncl-settings',
  });
}

class NCLua extends Media {
  late NCLuaRuntime runtime;
  NclDocument? document;

  NCLua({
    super.rawAttributes,
    super.uri,
    super.mimeType = 'application/x-ginga-NCLua',
    this.document,
    NCLuaRuntime? runtime,
  }) {
    if (runtime != null) {
      this.runtime = runtime;
    } else if (document != null) {
      this.runtime = NCLuaRuntime(
        document: document!,
        src: uri.isNotEmpty ? uri : src,
      );
    }
  }

  NCLuaRuntime get engine => runtime;
  set engine(NCLuaRuntime val) {
    runtime = val;
    val.media = this;
  }
}

class UserBase extends Element {
  List<UserProfile> get userProfiles =>
      children.whereType<UserProfile>().toList();
  UserBase({super.rawAttributes});
}

class UserProfile extends Element {
  String? get name => rawAttributes['name'];
  String? get age => rawAttributes['age'];
  String? get gender => rawAttributes['gender'];
  UserProfile({super.rawAttributes});

  UserData toUserData() {
    final idVal = id ?? '';
    final nameVal = name ?? idVal;
    return UserData(
      id: idVal,
      name: nameVal,
      initialProperties: Map<String, dynamic>.from(rawAttributes),
    );
  }
}
