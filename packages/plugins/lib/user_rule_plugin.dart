import 'package:ncldoc/ncl_document.dart';

import 'plugin_base.dart';

class UserRulePlugin implements NclRulePlugin, PluginBase {
  @override
  PluginType get type => PluginType.experimental;

  @override
  bool? evaluate(Element ruleElement, NclDocument document) {
    if (ruleElement.xmlTagName != 'rule') {
      return null;
    }
    final userAttr = ruleElement.rawAttributes['user'];
    if (userAttr == null || userAttr.isEmpty) {
      return null;
    }

    final varName = ruleElement.rawAttributes['var'] ?? '';
    final value = ruleElement.rawAttributes['value'] ?? '';
    final comparator = ruleElement.rawAttributes['comparator'] ?? 'eq';

    String? systemVal;
    if (document.isUserProfile(userAttr)) {
      final profile = document.loadedProfiles[userAttr];
      final currentUser = document.users.currentUser;
      if (currentUser != null &&
          profile != null &&
          !document.users.evaluateProfileForUser(profile, currentUser.id)) {
        return false;
      }
      systemVal = currentUser?.getProperty(varName)?.toString();
    }

    if (systemVal == null) {
      for (final s in document.body.children.whereType<UserSettings>()) {
        final profileId = s.user;
        if (profileId != userAttr &&
            profileId != 'currentUser' &&
            userAttr != 'currentUser') {
          continue;
        }
        var propName = varName;
        if (s.id != null && varName.startsWith('${s.id}.')) {
          propName = varName.substring(s.id!.length + 1);
        }
        final val = document.getPropertyValue(s, propName);
        if (val != null) {
          systemVal = val;
          break;
        }
      }
      if (systemVal == null) {
        final currentUser = document.users.currentUser;
        if (currentUser != null) {
          final userVal = currentUser.getProperty(varName);
          if (userVal != null) {
            systemVal = userVal.toString();
          }
        }
      }
    }

    return document.compareValues(systemVal, value, comparator);
  }
}
