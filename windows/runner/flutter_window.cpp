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
              int logical_w = std::get<int>(w_it->second);
              int logical_h = std::get<int>(h_it->second);
              HWND hwnd = GetHandle();
              if (IsZoomed(hwnd)) {
                ShowWindow(hwnd, SW_RESTORE);
              }
              HMONITOR monitor =
                  MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
              UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
              double scale = dpi / 96.0;
              RECT rect = {0, 0, static_cast<LONG>(logical_w * scale),
                           static_cast<LONG>(logical_h * scale)};
              DWORD style =
                  static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_STYLE));
              DWORD ex_style =
                  static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_EXSTYLE));
              AdjustWindowRectEx(&rect, style, FALSE, ex_style);
              SetWindowPos(hwnd, nullptr, 0, 0, rect.right - rect.left,
                           rect.bottom - rect.top,
                           SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
            }
          }
          result->Success();
        } else if (call.method_name() == "autoResize") {
          HWND hwnd = GetHandle();
          if (!IsZoomed(hwnd)) {
            HMONITOR monitor =
                MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
            double scale = dpi / 96.0;
            MONITORINFO mi{};
            mi.cbSize = sizeof(mi);
            GetMonitorInfo(monitor, &mi);
            int work_w = mi.rcWork.right - mi.rcWork.left;
            int work_h = mi.rcWork.bottom - mi.rcWork.top;

            int target_cw = static_cast<int>(1280 * scale);
            int target_ch = static_cast<int>(720 * scale);
            RECT rect = {0, 0, target_cw, target_ch};
            DWORD style = static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_STYLE));
            DWORD ex_style =
                static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_EXSTYLE));
            AdjustWindowRectEx(&rect, style, FALSE, ex_style);
            int w = rect.right - rect.left;
            int h = rect.bottom - rect.top;
            if (w > work_w) w = work_w;
            if (h > work_h) h = work_h;

            RECT current_client = GetClientArea();
            int cur_cw = current_client.right - current_client.left;
            int cur_ch = current_client.bottom - current_client.top;
            if ((cur_cw != target_cw || cur_ch != target_ch) &&
                w < work_w && h < work_h) {
              SetWindowPos(hwnd, nullptr, 0, 0, w, h,
                           SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
            }
          }
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
