import 'package:xml/xml.dart';

const int attrOptional = 0;
const int attrId = 1;
const int attrOptId = 2;
const int attrRequired = 3;
const int attrRequiredNonemptyName = 4;
const int attrOptIdref = 5;
const int attrIdref = 6;
const int attrNonemptyName = 7;

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
          "id": attrOptId,
          "title": attrOptional,
          "schemaLocation": attrOptional,
          "xmlns": attrOptional,
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
          "id": attrOptId,
          "device": attrOptional,
          "region": attrOptional,
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
          "id": attrId,
          "title": attrOptional,
          "left": attrOptional,
          "right": attrOptional,
          "top": attrOptional,
          "bottom": attrOptional,
          "height": attrOptional,
          "width": attrOptional,
          "zIndex": attrOptional,
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
        attributes: {"id": attrOptId},
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
          "id": attrId,
          "player": attrOptional,
          "explicitDur": attrOptional,
          "region": attrOptIdref,
          "freeze": attrOptional,
          "moveLeft": attrOptional,
          "moveRight": attrOptional,
          "moveUp": attrOptional,
          "moveDown": attrOptional,
          "focusIndex": attrOptional,
          "focusBorderColor": attrOptional,
          "focusBorderWidth": attrOptional,
          "focusBorderTransparency": attrOptional,
          "focusSrc": attrOptional,
          "focusSelSrc": attrOptional,
          "selBorderColor": attrOptional,
          "transIn": attrOptional,
          "transOut": attrOptional,
          "left": attrOptional,
          "right": attrOptional,
          "top": attrOptional,
          "bottom": attrOptional,
          "height": attrOptional,
          "width": attrOptional,
          "zIndex": attrOptional,
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
          "name": attrRequiredNonemptyName,
          "value": attrRequired,
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
        attributes: {"id": attrOptId},
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
        attributes: {"id": attrId},
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
        attributes: {"name": attrNonemptyName, "type": attrOptional},
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
        attributes: {"operator": attrOptional, "delay": attrOptional},
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
          "role": attrRequiredNonemptyName,
          "eventType": attrOptional,
          "key": attrOptional,
          "transition": attrOptional,
          "delay": attrOptional,
          "min": attrOptional,
          "max": attrOptional,
          "qualifier": attrOptional,
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
        attributes: {"operator": attrOptional, "delay": attrOptional},
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
          "role": attrRequiredNonemptyName,
          "eventType": attrOptional,
          "actionType": attrOptional,
          "duration": attrOptional,
          "value": attrOptional,
          "delay": attrOptional,
          "min": attrOptional,
          "max": attrOptional,
          "qualifier": attrOptional,
          "repeat": attrOptional,
          "repeatDelay": attrOptional,
          "by": attrOptional,
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
        attributes: {"operator": attrRequired, "isNegated": attrOptional},
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
        attributes: {"comparator": attrRequired},
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
          "role": attrRequiredNonemptyName,
          "eventType": attrOptional,
          "key": attrOptional,
          "attributeType": attrOptional,
          "offset": attrOptional,
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
        attributes: {"value": attrRequired},
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
        attributes: {"id": attrOptId},
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
        attributes: {"id": attrId, "operator": attrRequired},
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
          "id": attrId,
          "var": attrRequiredNonemptyName,
          "comparator": attrRequired,
          "value": attrRequired,
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
        attributes: {"id": attrOptId},
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
          "id": attrId,
          "type": attrRequiredNonemptyName,
          "subtype": attrNonemptyName,
          "dur": attrOptional,
          "startProgress": attrOptional,
          "endProgress": attrOptional,
          "direction": attrOptional,
          "fadeColor": attrOptional,
          "horzRepeat": attrOptional,
          "vertRepeat": attrOptional,
          "borderWidth": attrOptional,
          "borderColor": attrOptional,
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
          "alias": attrRequiredNonemptyName,
          "documentURI": attrRequired,
          "region": attrOptional,
          "baseId": attrOptional,
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
          "fontFamily": attrRequired,
          "src": attrRequired,
          "fontStyle": attrOptional,
          "fontWeight": attrOptional,
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
        attributes: {"id": attrOptId},
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
        attributes: {"id": attrId, "refer": attrOptIdref},
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
          "id": attrId,
          "component": attrIdref,
          "interface": attrOptIdref,
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
        attributes: {"id": attrId, "refer": attrOptIdref},
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
        attributes: {"id": attrId},
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
        attributes: {"component": attrIdref, "interface": attrOptIdref},
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
        attributes: {"constituent": attrIdref, "rule": attrIdref},
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
        attributes: {"component": attrIdref},
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
          "id": attrId,
          "src": attrOptional,
          "type": attrOptional,
          "descriptor": attrOptIdref,
          "refer": attrOptIdref,
          "instance": attrOptional,
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
          "id": attrId,
          "begin": attrOptional,
          "end": attrOptional,
          "label": attrOptional,
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
          "name": attrRequiredNonemptyName,
          "value": attrOptional,
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
        attributes: {"id": attrOptId, "xconnector": attrIdref},
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
          "name": attrRequiredNonemptyName,
          "value": attrRequired,
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
          "role": attrRequiredNonemptyName,
          "component": attrIdref,
          "interface": attrOptIdref,
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
          "name": attrRequiredNonemptyName,
          "value": attrRequired,
        },
      ),
    );
    addElementSyntax(
      "userBase",
      const ElementSyntax(
        possibleParents: ["head"],
        attributes: {
          "id": attrOptId,
        },
      ),
    );
    addElementSyntax(
      "userProfile",
      const ElementSyntax(
        possibleParents: ["userBase"],
        attributes: {
          "id": attrId,
          "name": attrOptional,
          "age": attrOptional,
          "gender": attrOptional,
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
          flag == attrId ||
          flag == attrRequired ||
          flag == attrRequiredNonemptyName ||
          flag == attrIdref;
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
