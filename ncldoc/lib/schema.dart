import 'package:xml/xml.dart';

const int ATTR_OPTIONAL = 0;
const int ATTR_ID = 1;
const int ATTR_OPT_ID = 2;
const int ATTR_REQUIRED = 3;
const int ATTR_REQUIRED_NONEMPTY_NAME = 4;
const int ATTR_OPT_IDREF = 5;
const int ATTR_IDREF = 6;
const int ATTR_NONEMPTY_NAME = 7;

class ElementSyntax {
  final List<String> possibleParents;
  final Map<String, int> attributes;

  const ElementSyntax({
    this.possibleParents = const [],
    this.attributes = const {},
  });
}

class Schema {
  final Map<String, ElementSyntax> _rules = {};

  void addElementSyntax(String name, ElementSyntax elt) {
    _rules[name] = elt;
  }

  Schema() {
    /* from NCL30Structure.xsd
       <complexType name="nclPrototype">
           <sequence>
             <element ref="structure:head" minOccurs="0" maxOccurs="1"/>
             <element ref="structure:body" minOccurs="0" maxOccurs="1"/>
           </sequence>
           <attribute name="id" type="ID" use="required"/>
           <attribute name="title" type="string" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "ncl",
      const ElementSyntax(
        possibleParents: [],
        attributes: {
          "id": ATTR_OPT_ID,
          "title": ATTR_OPTIONAL,
          "schemaLocation": ATTR_OPTIONAL,
          "xmlns": ATTR_OPTIONAL,
        },
      ),
    );
    addElementSyntax("head", const ElementSyntax(possibleParents: ["ncl"]));
    /* from NCL30Layout.xsd
       <complexType name="regionBasePrototype">
           <attribute name="id" type="ID" use="optional"/>
           <attribute name="device" type="string" use="optional"/>
       	<attribute name="region" type="string" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "regionBase",
      const ElementSyntax(
        possibleParents: ["head"],
        attributes: {
          "id": ATTR_OPT_ID,
          "device": ATTR_OPTIONAL,
          "region": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30Layout.xsd
       <complexType name="regionPrototype">
           <sequence minOccurs="0" maxOccurs="unbounded">
             <element ref="layout:region" />
           </sequence>
           <attribute name="id" type="ID" use="required"/>
           <attribute name="title" type="string" use="optional"/>    
           <attribute name="height" type="string" use="optional"/>    
           <attribute name="left" type="string" use="optional"/>    
           <attribute name="right" type="string" use="optional"/>    
           <attribute name="top" type="string" use="optional"/>    
           <attribute name="bottom" type="string" use="optional"/>    
           <attribute name="width" type="string" use="optional"/>    
           <attribute name="zIndex" type="integer" use="optional"/> 
         </complexType>
    */
    addElementSyntax(
      "region",
      const ElementSyntax(
        possibleParents: ["region", "regionBase"],
        attributes: {
          "id": ATTR_ID,
          "title": ATTR_OPTIONAL,
          "left": ATTR_OPTIONAL,
          "right": ATTR_OPTIONAL,
          "top": ATTR_OPTIONAL,
          "bottom": ATTR_OPTIONAL,
          "height": ATTR_OPTIONAL,
          "width": ATTR_OPTIONAL,
          "zIndex": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30Descriptor.xsd
       <complexType name="descriptorBasePrototype">
           <attribute name="id" type="ID" use="optional"/>                      
         </complexType>
    */
    addElementSyntax(
      "descriptorBase",
      const ElementSyntax(
        possibleParents: ["head"],
        attributes: {"id": ATTR_OPT_ID},
      ),
    );
    /* from NCL30Descriptor.xsd
       <complexType name="descriptorPrototype">
           <sequence minOccurs="0" maxOccurs="unbounded">
             <element ref="descriptor:descriptorParam"/>
           </sequence>
           <attribute name="id" type="ID" use="required"/>
           <attribute name="player" type="string" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "descriptor",
      const ElementSyntax(
        possibleParents: ["descriptorBase"],
        attributes: {
          "id": ATTR_ID,
          "player": ATTR_OPTIONAL,
          "explicitDur": ATTR_OPTIONAL,
          "region": ATTR_OPT_IDREF,
          "freeze": ATTR_OPTIONAL,
          "moveLeft": ATTR_OPTIONAL,
          "moveRight": ATTR_OPTIONAL,
          "moveUp": ATTR_OPTIONAL,
          "moveDown": ATTR_OPTIONAL,
          "focusIndex": ATTR_OPTIONAL,
          "focusBorderColor": ATTR_OPTIONAL,
          "focusBorderWidth": ATTR_OPTIONAL,
          "focusBorderTransparency": ATTR_OPTIONAL,
          "focusSrc": ATTR_OPTIONAL,
          "focusSelSrc": ATTR_OPTIONAL,
          "selBorderColor": ATTR_OPTIONAL,
          "transIn": ATTR_OPTIONAL,
          "transOut": ATTR_OPTIONAL,
          "left": ATTR_OPTIONAL,
          "right": ATTR_OPTIONAL,
          "top": ATTR_OPTIONAL,
          "bottom": ATTR_OPTIONAL,
          "height": ATTR_OPTIONAL,
          "width": ATTR_OPTIONAL,
          "zIndex": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30Descriptor.xsd
       <complexType name="descriptorParamPrototype">
           <attribute name="name" type="string" use="required" />
           <attribute name="value" type="string" use="required"/>
         </complexType>
    */
    addElementSyntax(
      "descriptorParam",
      const ElementSyntax(
        possibleParents: ["descriptor"],
        attributes: {
          "name": ATTR_REQUIRED_NONEMPTY_NAME,
          "value": ATTR_REQUIRED,
        },
      ),
    );
    /* from NCL30ConnectorBase.xsd
       <complexType name="connectorBasePrototype">
         <attribute name="id" type="ID" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "connectorBase",
      const ElementSyntax(
        possibleParents: ["head"],
        attributes: {"id": ATTR_OPT_ID},
      ),
    );
    /* from NCL30CausalConnector.xsd
       <complexType name="causalConnectorPrototype">
         <attribute name="id" type="ID" use="required"/>
       </complexType>
    */
    addElementSyntax(
      "causalConnector",
      const ElementSyntax(
        possibleParents: ["connectorBase"],
        attributes: {"id": ATTR_ID},
      ),
    );
    /* from NCL30ConnectorCommonPart.xsd
       <complexType name="parameterPrototype">
         <attribute name="name" type="string" use="required"/>
         <attribute name="type" type="string" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "connectorParam",
      const ElementSyntax(
        possibleParents: ["causalConnector"],
        attributes: {"name": ATTR_NONEMPTY_NAME, "type": ATTR_OPTIONAL},
      ),
    );
    /* from NCL30ConnectorCausalExpression.xsd
       <complexType name="compoundConditionPrototype">
         <attribute name="operator" type="connectorCommonPart:logicalOperatorPrototype" use="required"/>
         <attribute name="delay" type="string" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "compoundCondition",
      const ElementSyntax(
        possibleParents: ["causalConnector", "compoundCondition"],
        attributes: {"operator": ATTR_OPTIONAL, "delay": ATTR_OPTIONAL},
      ),
    );
    /* from NCL30ConnectorCausalExpression.xsd
       <complexType name="simpleConditionPrototype">
         <attribute name="role" type="connectorCausalExpression:conditionRoleUnion" use="required"/>
         <attribute name="eventType" type="connectorCommonPart:eventPrototype" use="optional"/>
         <attribute name="key" type="string" use="optional"/>
         <attribute name="transition" type="connectorCommonPart:transitionPrototype" use="optional"/>
         <attribute name="delay" type="string" use="optional"/>
         <attribute name="min" type="positiveInteger" use="optional"/>
         <attribute name="max" type="connectorCausalExpression:maxUnion" use="optional"/>
         <attribute name="qualifier" type="connectorCommonPart:logicalOperatorPrototype" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "simpleCondition",
      const ElementSyntax(
        possibleParents: ["causalConnector", "compoundCondition"],
        attributes: {
          "role": ATTR_REQUIRED_NONEMPTY_NAME,
          "eventType": ATTR_OPTIONAL,
          "key": ATTR_OPTIONAL,
          "transition": ATTR_OPTIONAL,
          "delay": ATTR_OPTIONAL,
          "min": ATTR_OPTIONAL,
          "max": ATTR_OPTIONAL,
          "qualifier": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30ConnectorCausalExpression.xsd
       <complexType name="compoundActionPrototype">
         <choice minOccurs="2" maxOccurs="unbounded">
           <element ref="connectorCausalExpression:simpleAction" />
           <element ref="connectorCausalExpression:compoundAction" />
         </choice>
         <attribute name="operator" type="connectorCausalExpression:actionOperatorPrototype" use="required"/>
         <attribute name="delay" type="string" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "compoundAction",
      const ElementSyntax(
        possibleParents: ["causalConnector", "compoundAction"],
        attributes: {"operator": ATTR_OPTIONAL, "delay": ATTR_OPTIONAL},
      ),
    );
    /* from NCL30ConnectorCausalExpression.xsd
       <complexType name="simpleActionPrototype">
         <attribute name="role" type="connectorCausalExpression:actionRoleUnion" use="required"/>
         <attribute name="eventType" type="connectorCommonPart:eventPrototype" use="optional"/>
         <attribute name="actionType" type="connectorCausalExpression:actionNamePrototype" use="optional"/>
         <attribute name="delay" type="string" use="optional"/>
         <attribute name="value" type="string" use="optional"/>
         <attribute name="repeat" type="positiveInteger" use="optional"/>
         <attribute name="repeatDelay" type="string" use="optional"/>
         <attribute name="min" type="positiveInteger" use="optional"/>
         <attribute name="max" type="connectorCausalExpression:maxUnion" use="optional"/>
         <attribute name="qualifier" type="connectorCausalExpression:actionOperatorPrototype" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "simpleAction",
      const ElementSyntax(
        possibleParents: ["causalConnector", "compoundAction"],
        attributes: {
          "role": ATTR_REQUIRED_NONEMPTY_NAME,
          "eventType": ATTR_OPTIONAL,
          "actionType": ATTR_OPTIONAL,
          "duration": ATTR_OPTIONAL,
          "value": ATTR_OPTIONAL,
          "delay": ATTR_OPTIONAL,
          "min": ATTR_OPTIONAL,
          "max": ATTR_OPTIONAL,
          "qualifier": ATTR_OPTIONAL,
          "repeat": ATTR_OPTIONAL,
          "repeatDelay": ATTR_OPTIONAL,
          "by": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30ConnectorAssessmentExpression.xsd
       <complexType name="compoundStatementPrototype">
         <choice minOccurs="1" maxOccurs="unbounded">
           <element ref="connectorAssessmentExpression:assessmentStatement" />
           <element ref="connectorAssessmentExpression:compoundStatement" />
         </choice>
         <attribute name="operator" type="connectorCommonPart:logicalOperatorPrototype" use="required"/>
         <attribute name="isNegated" type="boolean" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "compoundStatement",
      const ElementSyntax(
        possibleParents: ["compoundCondition", "compoundStatement"],
        attributes: {"operator": ATTR_REQUIRED, "isNegated": ATTR_OPTIONAL},
      ),
    );
    /* from NCL30ConnectorAssessmentExpression.xsd
       <complexType name="assessmentStatementPrototype" >
         <sequence>
           <element ref="connectorAssessmentExpression:attributeAssessment"/>
           <choice>
             <element ref="connectorAssessmentExpression:attributeAssessment"/>
             <element ref="connectorAssessmentExpression:valueAssessment"/>
           </choice>
         </sequence>
         <attribute name="comparator" type="connectorAssessmentExpression:comparatorPrototype" use="required"/>
       </complexType>
    */
    addElementSyntax(
      "assessmentStatement",
      const ElementSyntax(
        possibleParents: ["compoundCondition", "compoundStatement"],
        attributes: {"comparator": ATTR_REQUIRED},
      ),
    );
    /* from NCL30ConnectorAssessmentExpression.xsd
       <complexType name="attributeAssessmentPrototype">
         <attribute name="role" type="string" use="required"/>
         <attribute name="eventType" type="connectorCommonPart:eventPrototype" use="required"/>
         <attribute name="key" type="string" use="optional"/>
         <attribute name="attributeType" type="connectorAssessmentExpression:attributePrototype" use="optional"/>
         <attribute name="offset" type="string" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "attributeAssessment",
      const ElementSyntax(
        possibleParents: ["assessmentStatement"],
        attributes: {
          "role": ATTR_REQUIRED_NONEMPTY_NAME,
          "eventType": ATTR_OPTIONAL,
          "key": ATTR_OPTIONAL,
          "attributeType": ATTR_OPTIONAL,
          "offset": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30ConnectorAssessmentExpression.xsd
       <complexType name="valueAssessmentPrototype">
         <attribute name="value" type="connectorAssessmentExpression:valueUnion" use="required"/>
       </complexType>
    */
    addElementSyntax(
      "valueAssessment",
      const ElementSyntax(
        possibleParents: ["assessmentStatement"],
        attributes: {"value": ATTR_REQUIRED},
      ),
    );
    /* from NCL30TestRule.xsd
       <complexType name="ruleBasePrototype">
           <attribute name="id" type="ID" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "ruleBase",
      const ElementSyntax(
        possibleParents: ["head"],
        attributes: {"id": ATTR_OPT_ID},
      ),
    );
    /* from NCL30TestRule.xsd
       <complexType name="compositeRulePrototype">
           <choice minOccurs="2" maxOccurs="unbounded">
             <element ref="testRule:rule"/> 
             <element ref="testRule:compositeRule"/>   
           </choice>
           <attribute name="id" type="ID" use="required"/>
           <attribute name="operator" use="required">
             <simpleType>
               <restriction base="string">
                 <enumeration value="and"/>
                 <enumeration value="or"/>
               </restriction>
             </simpleType>
           </attribute>
         </complexType>
    */
    addElementSyntax(
      "compositeRule",
      const ElementSyntax(
        possibleParents: ["ruleBase", "compositeRule"],
        attributes: {"id": ATTR_ID, "operator": ATTR_REQUIRED},
      ),
    );
    /* from NCL30TestRule.xsd
       <complexType name="rulePrototype">
           <attribute name="id" type="ID" use="optional"/>
           <attribute name="var" type="string" use="required"/>
           <attribute name="value" type="string" use="required"/>
           <attribute name="comparator" use="required">
             <simpleType>
               <restriction base="string">
                 <enumeration value="eq"/>
                 <enumeration value="ne"/>
                 <enumeration value="gt"/>
                 <enumeration value="gte"/>
                 <enumeration value="lt"/>
                 <enumeration value="lte"/>
               </restriction>
             </simpleType>
           </attribute>
         </complexType>
    */
    addElementSyntax(
      "rule",
      const ElementSyntax(
        possibleParents: ["ruleBase", "compositeRule"],
        attributes: {
          "id": ATTR_ID,
          "var": ATTR_REQUIRED_NONEMPTY_NAME,
          "comparator": ATTR_REQUIRED,
          "value": ATTR_REQUIRED,
        },
      ),
    );
    /* from NCL30TransitionBase.xsd
       <complexType name="transitionBasePrototype">
         <attribute name="id" type="ID" use="optional"/>
       </complexType>
    */
    addElementSyntax(
      "transitionBase",
      const ElementSyntax(
        possibleParents: ["head"],
        attributes: {"id": ATTR_OPT_ID},
      ),
    );
    /* from NCL30Transition.xsd
       <complexType name="transitionPrototype">
            <attributeGroup ref="transition:transitionAttrs"/>
            <attributeGroup ref="transition:transitionModifierAttrs"/>
         </complexType>
    */
    addElementSyntax(
      "transition",
      const ElementSyntax(
        possibleParents: ["transitionBase"],
        attributes: {
          "id": ATTR_ID,
          "type": ATTR_REQUIRED_NONEMPTY_NAME,
          "subtype": ATTR_NONEMPTY_NAME,
          "dur": ATTR_OPTIONAL,
          "startProgress": ATTR_OPTIONAL,
          "endProgress": ATTR_OPTIONAL,
          "direction": ATTR_OPTIONAL,
          "fadeColor": ATTR_OPTIONAL,
          "horzRepeat": ATTR_OPTIONAL,
          "vertRepeat": ATTR_OPTIONAL,
          "borderWidth": ATTR_OPTIONAL,
          "borderColor": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30Import.xsd
       <complexType name="importBasePrototype">
             <attribute name="alias" type="ID" use="required"/>
             <attribute name="region" type="IDREF" use="optional"/>
             <attribute name="documentURI" type="anyURI" use="required"/>
             <attribute name="baseId" type="IDREF" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "importBase",
      const ElementSyntax(
        possibleParents: [
          "connectorBase",
          "descriptorBase",
          "regionBase",
          "ruleBase",
          "transitionBase",
          "fontBase",
        ],
        attributes: {
          "alias": ATTR_REQUIRED_NONEMPTY_NAME,
          "documentURI": ATTR_REQUIRED,
          "region": ATTR_OPTIONAL,
          "baseId": ATTR_OPTIONAL,
        },
      ),
    );
    addElementSyntax(
      "fontBase",
      const ElementSyntax(possibleParents: ["head"]),
    );
    addElementSyntax(
      "font",
      const ElementSyntax(
        possibleParents: ["fontBase"],
        attributes: {
          "fontFamily": ATTR_REQUIRED,
          "src": ATTR_REQUIRED,
          "fontStyle": ATTR_OPTIONAL,
          "fontWeight": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30Structure.xsd
       <complexType name="bodyPrototype">
           <attribute name="id" type="ID" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "body",
      const ElementSyntax(
        possibleParents: ["ncl"],
        attributes: {"id": ATTR_OPT_ID},
      ),
    );
    /* from NCL30Context.xsd
       <complexType name="contextPrototype">
           <attribute name="id" type="ID" use="required"/>
         </complexType>
    */
    addElementSyntax(
      "context",
      const ElementSyntax(
        possibleParents: ["body", "context", "switch"],
        attributes: {"id": ATTR_ID, "refer": ATTR_OPT_IDREF},
      ),
    );
    /* from NCL30CompositeNodeInterface.xsd
       <complexType name="compositeNodePortPrototype">
           <attribute name="id" type="ID" use="required" />
           <attribute name="component" type="IDREF" use="required"/>
           <attribute name="interface" type="string" use="optional" />
         </complexType>
    */
    addElementSyntax(
      "port",
      const ElementSyntax(
        possibleParents: ["body", "context"],
        attributes: {
          "id": ATTR_ID,
          "component": ATTR_IDREF,
          "interface": ATTR_OPT_IDREF,
        },
      ),
    );
    /* from NCL30ContentControl.xsd
       <complexType name="switchPrototype">
           <choice>
           <element ref="contentControl:defaultComponent" minOccurs="0" maxOccurs="1"/>
           </choice>
           <attribute name="id" type="ID" use="required"/>
         </complexType>
    */
    addElementSyntax(
      "switch",
      const ElementSyntax(
        possibleParents: ["body", "context", "switch"],
        attributes: {"id": ATTR_ID, "refer": ATTR_OPT_IDREF},
      ),
    );
    /* from NCL30SwitchInterface.xsd
       <complexType name="switchPortPrototype">
           <sequence>
             <element ref="switchInterface:mapping" minOccurs="1" maxOccurs="unbounded"/>
           </sequence>
           <attribute name="id" type="ID" use="required"/>
         </complexType>
    */
    addElementSyntax(
      "switchPort",
      const ElementSyntax(
        possibleParents: ["switch"],
        attributes: {"id": ATTR_ID},
      ),
    );
    /* from NCL30SwitchInterface.xsd
       <complexType name="mappingPrototype">
           <attribute name="component" type="IDREF" use="required"/>
           <attribute name="interface" type="string" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "mapping",
      const ElementSyntax(
        possibleParents: ["switchPort"],
        attributes: {"component": ATTR_IDREF, "interface": ATTR_OPT_IDREF},
      ),
    );
    /* from NCL30TestRuleUse.xsd
       <complexType name="bindRulePrototype">
           <attribute name="constituent" type="IDREF" use="required" />
           <attribute name="rule" type="string" use="required" />
         </complexType>
    */
    addElementSyntax(
      "bindRule",
      const ElementSyntax(
        possibleParents: ["switch"],
        attributes: {"constituent": ATTR_IDREF, "rule": ATTR_IDREF},
      ),
    );
    /* from NCL30ContentControl.xsd
       <complexType name="defaultComponentPrototype">
           <attribute name="component" type="IDREF" use="required" />
         </complexType>
    */
    addElementSyntax(
      "defaultComponent",
      const ElementSyntax(
        possibleParents: ["switch"],
        attributes: {"component": ATTR_IDREF},
      ),
    );
    /* from NCL30Media.xsd
       <complexType name="mediaPrototype">
           <attribute name="id" type="ID" use="required"/>
           <attribute name="type" type="string" use="optional"/>          
           <attribute name="src" type="anyURI" use="optional"/>   
         </complexType>
    */
    addElementSyntax(
      "media",
      const ElementSyntax(
        possibleParents: ["body", "context", "switch"],
        attributes: {
          "id": ATTR_ID,
          "src": ATTR_OPTIONAL,
          "type": ATTR_OPTIONAL,
          "descriptor": ATTR_OPT_IDREF,
          "refer": ATTR_OPT_IDREF,
          "instance": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30MediaContentAnchor.xsd
       <complexType name="componentAnchorPrototype">
           <attribute name="id" type="ID" use="required"/>
           <attributeGroup ref="mediaAnchor:coordsAnchorAttrs" />
           <attributeGroup ref="mediaAnchor:temporalAnchorAttrs" />
           <attributeGroup ref="mediaAnchor:textAnchorAttrs" />
           <attributeGroup ref="mediaAnchor:sampleAnchorAttrs" />
           <attributeGroup ref="mediaAnchor:labelAttrs" />
           <attributeGroup ref="mediaAnchor:clipAttrs" />
         </complexType>
    */
    addElementSyntax(
      "area",
      const ElementSyntax(
        possibleParents: ["media"],
        attributes: {
          "id": ATTR_ID,
          "begin": ATTR_OPTIONAL,
          "end": ATTR_OPTIONAL,
          "label": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30PropertyAnchor.xsd
       <complexType name="propertyAnchorPrototype">
           <attribute name="name" type="string" use="required" />
           <attribute name="value" type="string" use="optional" />
           <attribute name="externable" type="boolean" use="optional" />
         </complexType>
    */
    addElementSyntax(
      "property",
      const ElementSyntax(
        possibleParents: ["body", "context", "media"],
        attributes: {
          "name": ATTR_REQUIRED_NONEMPTY_NAME,
          "value": ATTR_OPTIONAL,
        },
      ),
    );
    /* from NCL30Linking.xsd
       <complexType name="linkPrototype">
           <sequence>
             <element ref="linking:linkParam" minOccurs="0" maxOccurs="unbounded"/>
             <element ref="linking:bind" minOccurs="2" maxOccurs="unbounded"/>
           </sequence>
           <attribute name="id" type="ID" use="optional"/>
           <attribute name="xconnector" type="string" use="required"/>
         </complexType>
    */
    addElementSyntax(
      "link",
      const ElementSyntax(
        possibleParents: ["body", "context"],
        attributes: {"id": ATTR_OPT_ID, "xconnector": ATTR_IDREF},
      ),
    );
    /* from NCL30Linking.xsd
       <complexType name="paramPrototype">
           <attribute name="name" type="string" use="required"/>
           <attribute name="value" type="anySimpleType" use="required"/>
         </complexType>
    */
    addElementSyntax(
      "linkParam",
      const ElementSyntax(
        possibleParents: ["link"],
        attributes: {
          "name": ATTR_REQUIRED_NONEMPTY_NAME,
          "value": ATTR_REQUIRED,
        },
      ),
    );
    /* from NCL30Linking.xsd
       <complexType name="bindPrototype">
           <sequence minOccurs="0" maxOccurs="unbounded">
             <element ref="linking:bindParam"/>
           </sequence>
           <attribute name="role" type="string" use="required"/>
           <attribute name="component" type="IDREF" use="required"/>
           <attribute name="interface" type="string" use="optional"/>
         </complexType>
    */
    addElementSyntax(
      "bind",
      const ElementSyntax(
        possibleParents: ["link"],
        attributes: {
          "role": ATTR_REQUIRED_NONEMPTY_NAME,
          "component": ATTR_IDREF,
          "interface": ATTR_OPT_IDREF,
        },
      ),
    );
    /* from NCL30Linking.xsd
       <complexType name="paramPrototype">
           <attribute name="name" type="string" use="required"/>
           <attribute name="value" type="anySimpleType" use="required"/>
         </complexType>
    */
    addElementSyntax(
      "bindParam",
      const ElementSyntax(
        possibleParents: ["bind"],
        attributes: {
          "name": ATTR_REQUIRED_NONEMPTY_NAME,
          "value": ATTR_REQUIRED,
        },
      ),
    );
    addElementSyntax(
      "userBase",
      const ElementSyntax(
        possibleParents: ["head"],
        attributes: {
          "id": ATTR_OPT_ID,
        },
      ),
    );
    addElementSyntax(
      "userProfile",
      const ElementSyntax(
        possibleParents: ["userBase"],
        attributes: {
          "id": ATTR_ID,
          "name": ATTR_OPTIONAL,
          "age": ATTR_OPTIONAL,
          "gender": ATTR_OPTIONAL,
        },
      ),
    );
  }

  List<String> validateElement(dynamic node) {
    List<String> errors = [];
    if (node is! XmlElement) return errors;

    final tagName = node.name.local;
    final syntax = _rules[tagName];

    if (syntax == null) return errors;

    final parentNode = node.parent;
    if (parentNode is XmlElement && syntax.possibleParents.isNotEmpty) {
      if (!syntax.possibleParents.contains(parentNode.name.local)) {
        errors.add(
          'Element <$tagName> has invalid parent <${parentNode.name.local}>.',
        );
      }
    }

    final attributes = {for (var a in node.attributes) a.name.local: a.value};

    syntax.attributes.forEach((attrName, flag) {
      final isRequired =
          flag == ATTR_ID ||
          flag == ATTR_REQUIRED ||
          flag == ATTR_REQUIRED_NONEMPTY_NAME ||
          flag == ATTR_IDREF;
      if (isRequired && !attributes.containsKey(attrName)) {
        errors.add(
          'Missing required attribute "$attrName" for element <$tagName>.',
        );
      }
    });

    for (var attrName in attributes.keys) {
      if (!syntax.attributes.containsKey(attrName)) {
        if (tagName == 'ncl' && attrName.startsWith('xmlns')) continue;
        errors.add('Unknown attribute "$attrName" for element <$tagName>.');
      }
    }

    return errors;
  }
}
