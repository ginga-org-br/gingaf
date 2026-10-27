import 'package:get_it/get_it.dart';
import 'package:ncldoc/ncldoc_plugins.dart';
import 'package:nclui/nclui_plugins.dart';

import 'ncl360_plugin.dart';
import 'srt_plugin.dart';
import 'user_rule_plugin.dart';

void registerAllPlugins(GetIt di) {
  if (!di.isRegistered<NclMediaPlugin>()) {
    di.registerFactory<NclMediaPlugin>(
      () => Ncl360MediaPlugin(),
    );
  }

  if (!di.isRegistered<NclParserPlugin>()) {
    di.registerFactory<NclParserPlugin>(
      () => Ncl360ParserPlugin(),
    );
  }

  if (!di.isRegistered<NclTickPlugin>()) {
    di.registerFactory<NclTickPlugin>(
      () => SrtMediaPlugin(),
    );
  }

  if (!di.isRegistered<NclRulePlugin>()) {
    di.registerFactory<NclRulePlugin>(
      () => UserRulePlugin(),
    );
  }
}
