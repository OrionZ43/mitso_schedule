#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#ifndef _DEBUG
namespace {

// Одна копия приложения на пользователя. Имя обязано совпадать с
// AppMutexName в windows/installer/mitso_schedule.iss: установщик ждёт, пока
// мьютекс исчезнет, и только потом заменяет файлы. В отладочных сборках
// выключено, чтобы `flutter run` работал рядом с установленной копией.
constexpr wchar_t kSingleInstanceMutex[] =
    L"Z43Studios.MitsoSchedule.SingleInstance";

// Показывает уже запущенное окно вместо второй копии.
void ActivateExistingWindow() {
  HWND window =
      ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Расписание");
  if (window == nullptr) {
    return;
  }
  if (::IsIconic(window)) {
    ::ShowWindow(window, SW_RESTORE);
  }
  ::SetForegroundWindow(window);
}

}  // namespace
#endif

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
#ifndef _DEBUG
  HANDLE instance_mutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingWindow();
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }
#endif

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  // Интерфейс телефонный: одна колонка с навигацией внизу. Окно под неё —
  // узкое и высокое; меньше 360x600 оно не станет (WM_GETMINMAXINFO).
  Win32Window::Size size(480, 900);
  if (!window.Create(L"Расписание", origin, size)) {
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
