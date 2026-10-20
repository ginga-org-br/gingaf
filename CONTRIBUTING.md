# Contributing to gingaf

Thank you for your interest in contributing to `gingaf`! We welcome contributions of all forms, including bug reports, feature requests, documentation improvements, unit tests, and code contributions.

## Code of Conduct

All contributors and participants are expected to maintain a friendly, welcoming, and inclusive environment. Treat everyone with respect and patience.

## Recognition and Attribution

Contributors are recognized in release notes and git history. Thank you for helping build `gingaf`!

## Communication and Getting Help

If you have questions, want to discuss an architectural idea, or need help getting started:

- Open an issue or join discussions on the [gingaf GitHub repository](https://github.com/ginga-org-br/gingaf).
- Check the project documentation at [https://ginga-org-br.github.io/gingaf/docs](https://ginga-org-br.github.io/gingaf/docs).
- Review [BUILD.md](BUILD.md) for local environment setup, build commands, and testing instructions.

## Reporting Bugs and Suggesting Enhancements

Before opening an issue, search existing issues to see if it has already been reported or discussed.

- **For bugs**: Provide a clear title, step-by-step reproduction instructions, expected versus actual behavior, and environment details (OS platform, Flutter/Dart version, and sample NCL document if applicable).
- **For enhancements**: Explain the rationale, context, and use case for the proposed change. Discuss breaking changes or API modifications before submitting large pull requests.

## Finding Tasks and First Contributions

If you are looking for ways to contribute:

- Check issues tagged `good first issue` or `help wanted`.
- Small, focused pull requests (such as adding tests, fixing typos, or implementing a single plugin) are preferred over large, monolithic changes.

## Pull Request and Contribution Workflow

1. Fork the repository and create a feature branch (`git checkout -b feature/my-feature`).
2. Install dependencies: `make deps`.
3. Implement your changes adhering to code style and formatting standards.
4. Verify your changes pass analyzer and test suites:
   ```bash
   flutter analyze
   make test
   ```
5. Commit your changes with clear, descriptive commit messages.
6. Open a pull request against the `main` branch with a summary of changes and references to relevant issues.

## Code Style and Standards

- Format all Dart code before submitting:
   ```bash
   dart format .
   ```
- Ensure no analyzer errors or warnings remain:
   ```bash
   flutter analyze
   ```
- Follow official [Effective Dart](https://dart.dev/effective-dart) guidelines.
- Never include unnecessary comments or emojis in source code.

## Creating Plugins

`gingaf` provides an extensible plugin system based on [GetIt](https://pub.dev/packages/get_it) allowing developers to extend it. Plugins are organized in `packages/plugins`. Every plugin implements plugin interface (such as `NclMediaPlugin`) alongside [plugin_base.dart](packages/plugins/lib/plugin_base.dart) (`PluginBase`), specifying a `PluginType` (`optional` or `experimental`).

To add a new plugin:
- Export your plugin class from [plugins.dart](packages/plugins/lib/plugins.dart).
- Register it as a factory with `di.registerFactory` in [plugins_registry.dart](packages/plugins/lib/plugins_registry.dart):

```dart
if (!di.isRegistered<NclMediaPlugin>(instanceName: 'my_custom_plugin')) {
  di.registerFactory<NclMediaPlugin>(
    () => MyCustomPlugin(),
    instanceName: 'my_custom_plugin',
  );
}
```
