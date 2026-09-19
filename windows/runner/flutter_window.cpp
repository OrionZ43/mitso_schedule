#include "flutter_window.h"

#include <dwmapi.h>

#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Размер компактного окна в логических пикселях: часы, текущая пара и
// аудитория (lib/features/widget_mode/compact_screen.dart).
constexpr int kCompactWidth = 340;
constexpr int kCompactHeight = 172;

// Отступ компактного окна от края рабочей области.
constexpr int kCompactMargin = 24;

// Автозапуск: приложение с ключом --widget сразу открывается компактным.
constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"MitsoSchedule";

std::wstring ExecutablePath() {
  wchar_t path[MAX_PATH] = {};
  ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  return std::wstring(path);
}

bool AutostartEnabled() {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_READ, &key) !=
      ERROR_SUCCESS) {
    return false;
  }
  const LSTATUS status =
      ::RegQueryValueExW(key, kRunValue, nullptr, nullptr, nullptr, nullptr);
  ::RegCloseKey(key);
  return status == ERROR_SUCCESS;
}

void SetAutostart(bool enabled) {
  HKEY key = nullptr;
  if (::RegOpenKeyExW(HKEY_CURRENT_USER, kRunKey, 0, KEY_SET_VALUE, &key) !=
      ERROR_SUCCESS) {
    return;
  }
  if (enabled) {
    const std::wstring command = L"\"" + ExecutablePath() + L"\" --widget";
    ::RegSetValueExW(
        key, kRunValue, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    ::RegDeleteValueW(key, kRunValue);
  }
  ::RegCloseKey(key);
}

// Просит Windows 11 скруглить углы окна. На Windows 10 вызов просто не
// срабатывает.
void RoundCorners(HWND window) {
  // DWMWA_WINDOW_CORNER_PREFERENCE / DWMWCP_ROUND — числами, чтобы не
  // требовать свежий Windows SDK.
  const DWORD attribute = 33;
  const DWORD round = 2;
  ::DwmSetWindowAttribute(window, attribute, &round, sizeof(round));
}

bool BoolArgument(const flutter::EncodableValue* arguments) {
  const bool* value = std::get_if<bool>(arguments);
  return value != nullptr && *value;
}

}  // namespace

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

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "mitso/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        if (method == "setCompact") {
          SetCompact(BoolArgument(call.arguments()));
          result->Success();
        } else if (method == "startDrag") {
          StartDrag();
          result->Success();
        } else if (method == "close") {
          // У компактного окна нет рамки, а значит и системной кнопки
          // закрытия: её роль играет кнопка в интерфейсе.
          ::PostMessageW(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
        } else if (method == "autostart") {
          result->Success(flutter::EncodableValue(AutostartEnabled()));
        } else if (method == "setAutostart") {
          SetAutostart(BoolArgument(call.arguments()));
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

void FlutterWindow::SetCompact(bool compact) {
  HWND window = GetHandle();
  if (window == nullptr || compact == compact_) {
    return;
  }
  compact_ = compact;

  const double scale =
      static_cast<double>(FlutterDesktopGetDpiForHWND(window)) / 96.0;

  if (compact) {
    ::GetWindowRect(window, &normal_rect_);
    SetMinimumSize(Size(kCompactWidth, kCompactHeight));

    const int width = static_cast<int>(kCompactWidth * scale);
    const int height = static_cast<int>(kCompactHeight * scale);
    const int margin = static_cast<int>(kCompactMargin * scale);
    // Правый нижний угол рабочей области — над панелью задач.
    RECT work_area = {};
    ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
    const int x = work_area.right - width - margin;
    const int y = work_area.bottom - height - margin;

    ::SetWindowLongPtrW(window, GWL_STYLE, WS_POPUP | WS_VISIBLE);
    ::SetWindowPos(window, HWND_TOPMOST, x, y, width, height,
                   SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    RoundCorners(window);
  } else {
    SetMinimumSize(Size(360, 600));
    ::SetWindowLongPtrW(window, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
    ::SetWindowPos(window, HWND_NOTOPMOST, normal_rect_.left, normal_rect_.top,
                   normal_rect_.right - normal_rect_.left,
                   normal_rect_.bottom - normal_rect_.top,
                   SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  }
}

void FlutterWindow::StartDrag() {
  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }
  // Приём Windows: отпустить мышь и сказать окну, что тянут за заголовок.
  ::ReleaseCapture();
  ::SendMessageW(window, WM_NCLBUTTONDOWN, HTCAPTION, 0);
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
