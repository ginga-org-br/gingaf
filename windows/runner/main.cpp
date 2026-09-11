#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <iostream>

#include "../../linux/runner/usage.h"
#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  CreateAndAttachConsole();

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  for (const auto& arg : command_line_arguments) {
    if (arg == "-h" || arg == "--help") {
      std::cout << kUsageMessage << std::endl;
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }
  }

  const char* app_env = std::getenv("APP");
  const char* config_env = std::getenv("CONFIG");
  bool has_env = (app_env != nullptr && app_env[0] != '\0') ||
                 (config_env != nullptr && config_env[0] != '\0');

  if (command_line_arguments.empty() && !has_env) {
    std::cerr << kUsageMessage << std::endl;
    ::CoUninitialize();
    return EXIT_FAILURE;
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"gingaf", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
