#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Компактный режим — «виджет» на рабочем столе: окно без рамки, поверх
  // других, в правом нижнем углу. Обычный размер запоминается, чтобы
  // вернуться к нему.
  void SetCompact(bool compact);

  // Перетаскивание окна за содержимое: заголовка, за который тянут обычное
  // окно, у компактного нет.
  void StartDrag();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Канал mitso/window: компактный режим, перетаскивание и автозапуск.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  bool compact_ = false;
  RECT normal_rect_ = {};
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
