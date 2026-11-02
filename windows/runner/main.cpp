#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif
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
  const char* flutter_engine_env = std::getenv("FLUTTER_ENGINE_SWITCHES");
  bool has_env = (app_env != nullptr && app_env[0] != '\0') ||
                 (config_env != nullptr && config_env[0] != '\0') ||
                 (flutter_engine_env != nullptr && flutter_engine_env[0] != '\0');

  if (command_line_arguments.empty() && !has_env) {
    std::cerr << kUsageMessage << std::endl;
    ::CoUninitialize();
    return EXIT_FAILURE;
  }

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  bool is_playground = false;
  const char* pg_env = std::getenv("GINGA_PLAYGROUND");
  if (pg_env != nullptr && (_stricmp(pg_env, "true") == 0 || _stricmp(pg_env, "1") == 0 || _stricmp(pg_env, "yes") == 0)) {
    is_playground = true;
  }
  const char* pg_env_lower = std::getenv("ginga_playground");
  if (pg_env_lower != nullptr && (_stricmp(pg_env_lower, "true") == 0 || _stricmp(pg_env_lower, "1") == 0 || _stricmp(pg_env_lower, "yes") == 0)) {
    is_playground = true;
  }
  for (const auto& arg : command_line_arguments) {
    if (arg == "--playground" || arg == "-p" ||
        arg.rfind("--playground=", 0) == 0 || arg.rfind("-p=", 0) == 0 ||
        arg.find("GINGA_PLAYGROUND=true") != std::string::npos) {
      is_playground = true;
      break;
    }
  }
  if (flutter_engine_env != nullptr && std::string(flutter_engine_env).find("GINGA_PLAYGROUND=true") != std::string::npos) {
    is_playground = true;
  }

  int screen_w = GetSystemMetrics(SM_CXSCREEN);
  int screen_h = GetSystemMetrics(SM_CYSCREEN);
  int initial_w = is_playground ? ((screen_w >= 1920) ? 1920 : (screen_w - 60)) : (screen_w < 1280 ? screen_w - 60 : 1280);
  int initial_h = is_playground ? ((screen_h >= 1080) ? 800 : (screen_h - 100)) : (screen_h < 720 ? screen_h - 100 : 720);

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(initial_w, initial_h);
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
