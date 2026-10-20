enum PluginType { optional, experimental }

abstract class PluginBase {
  PluginType get type;
}
