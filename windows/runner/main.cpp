#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "single_instance.h"
#include "utils.h"

namespace {

constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\org.getlantern.lantern.single-instance";
constexpr const wchar_t kSingleInstanceReadyEventName[] =
    L"Local\\org.getlantern.lantern.window-ready";
constexpr DWORD kWindowReadyTimeoutMs = 5000;
constexpr DWORD kActivationRetryTimeoutMs = 1000;
constexpr DWORD kActivationRetryIntervalMs = 100;

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  SingleInstanceReadyEvent window_ready(kSingleInstanceReadyEventName);
  SingleInstanceLock single_instance(kSingleInstanceMutexName);
  if (!single_instance.IsPrimaryInstance()) {
    window_ready.Wait(kWindowReadyTimeoutMs);
    return ActivateExistingLanternWindowWithRetry(kActivationRetryTimeoutMs,
                                                  kActivationRetryIntervalMs)
               ? EXIT_SUCCESS
               : EXIT_FAILURE;
  }
  // If we acquire the mutex, start this build. Normal installer upgrades close
  // running Lantern instances before launch; handing off here could silently
  // keep a pre-single-instance build alive.

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
  if (!window.Create(L"lantern", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  window_ready.Signal();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
