#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "gingaf/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "resize") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto w_it = args->find(flutter::EncodableValue("width"));
            auto h_it = args->find(flutter::EncodableValue("height"));
            if (w_it != args->end() && h_it != args->end()) {
              int w = std::get<int>(w_it->second);
              int h = std::get<int>(h_it->second);
              HWND hwnd = GetHandle();
              SetWindowPos(hwnd, nullptr, 0, 0, w, h, SWP_NOMOVE | SWP_NOZORDER);
            }
          }
          result->Success();
        } else if (call.method_name() == "autoResize") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          bool pg = false;
          if (args) {
            auto pg_it = args->find(flutter::EncodableValue("playground"));
            if (pg_it != args->end()) {
              pg = std::get<bool>(pg_it->second);
            }
          }
          int sw = GetSystemMetrics(SM_CXSCREEN);
          int sh = GetSystemMetrics(SM_CYSCREEN);
          int w = pg ? ((sw >= 1920) ? 1920 : (sw - 60)) : (sw < 1280 ? sw - 60 : 1280);
          int h = pg ? ((sh >= 1080) ? 800 : (sh - 100)) : (sh < 720 ? sh - 100 : 720);
          HWND hwnd = GetHandle();
          SetWindowPos(hwnd, nullptr, 0, 0, w, h, SWP_NOMOVE | SWP_NOZORDER);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
