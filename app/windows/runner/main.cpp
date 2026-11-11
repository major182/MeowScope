#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#ifdef MEOWSCOPE_DEV
constexpr const wchar_t kWindowTitle[] = L"MeowScope Dev";
constexpr const wchar_t kInstanceMutex[] = L"Local\\com.meowscope.meowscope-dev";
#else
constexpr const wchar_t kWindowTitle[] = L"MeowScope";
constexpr const wchar_t kInstanceMutex[] = L"Local\\com.meowscope.meowscope";
#endif

// すでに動いていれば、今のウィンドウを前に出して true を返す（#173）。
// 同じ DB を2つのアプリが使わないようにする。開発版と配布版は名前が違うので、同時に動かせる
static bool ActivateRunningInstance() {
  // ハンドルはプロセスが終わるまで持ち続ける（閉じると、次の起動が1つ目と見なされる）
  ::CreateMutexW(nullptr, FALSE, kInstanceMutex);
  if (::GetLastError() != ERROR_ALREADY_EXISTS) {
    return false;
  }
  HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", kWindowTitle);
  if (existing != nullptr) {
    if (::IsIconic(existing)) {
      ::ShowWindow(existing, SW_RESTORE);
    }
    ::SetForegroundWindow(existing);
  }
  return true;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (ActivateRunningInstance()) {
    return EXIT_SUCCESS;
  }

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
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
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
