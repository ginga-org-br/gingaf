import 'package:get_it/get_it.dart';
import 'package:ncldoc/ncldoc_plugins.dart';
import 'package:nclui/nclui_plugins.dart';

import 'data_binding_plugin.dart';
import 'ncl360_plugin.dart';
import 'srt_plugin.dart';
import 'user_rule_plugin.dart';

void registerAllPlugins(GetIt di) {
  if (!di.isRegistered<NclMediaPlugin>(instanceName: 'data_binding_plugin')) {
    di.registerFactory<NclMediaPlugin>(
      () => DataBindingMediaPlugin(),
      instanceName: 'data_binding_plugin',
    );
  }

  if (!di.isRegistered<NclParserPlugin>(
    instanceName: 'data_binding_parser_plugin',
  )) {
    di.registerFactory<NclParserPlugin>(
      () => DataBindingMediaPlugin(),
      instanceName: 'data_binding_parser_plugin',
    );
  }

  if (!di.isRegistered<NclKeyPlugin>(instanceName: 'data_binding_key_plugin')) {
    di.registerFactory<NclKeyPlugin>(
      () => DataBindingMediaPlugin(),
      instanceName: 'data_binding_key_plugin',
    );
  }

  if (!di.isRegistered<NclTickPlugin>(
    instanceName: 'data_binding_tick_plugin',
  )) {
    di.registerFactory<NclTickPlugin>(
      () => DataBindingMediaPlugin(),
      instanceName: 'data_binding_tick_plugin',
    );
  }

  if (!di.isRegistered<NclMediaPlugin>(instanceName: 'ncl360_media_plugin')) {
    di.registerFactory<NclMediaPlugin>(
      () => Ncl360MediaPlugin(),
      instanceName: 'ncl360_media_plugin',
    );
  }

  if (!di.isRegistered<NclMediaPlugin>(instanceName: 'srt_media_plugin')) {
    di.registerFactory<NclMediaPlugin>(
      () => SrtMediaPlugin(),
      instanceName: 'srt_media_plugin',
    );
  }

  if (!di.isRegistered<NclParserPlugin>(
    instanceName: 'ncl360_parser_plugin',
  )) {
    di.registerFactory<NclParserPlugin>(
      () => Ncl360ParserPlugin(),
      instanceName: 'ncl360_parser_plugin',
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
