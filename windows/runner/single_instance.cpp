#include "single_instance.h"

#include "app_links/app_links_plugin_c_api.h"
#include "win32_window.h"

namespace {

HWND FindExistingLanternWindow() {
  if (HWND window = FindWindowW(Win32Window::GetWindowClassName(), nullptr)) {
    return window;
  }

  // Older builds used Flutter's default class name before the single-instance
  // guard existed. Keep these fallbacks so upgrading while Lantern is already
  // running still activates that window instead of opening a duplicate.
  if (HWND window = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Lantern")) {
    return window;
  }
  return FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"lantern");
}

void FlashTaskbar(HWND window) {
  FLASHWINFO flash_info = {};
  flash_info.cbSize = sizeof(flash_info);
  flash_info.hwnd = window;
  flash_info.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
  flash_info.uCount = 3;
  FlashWindowEx(&flash_info);
}

void AttachThreadInputIfNeeded(DWORD current_thread, DWORD target_thread,
                               BOOL attach) {
  if (target_thread != 0 && target_thread != current_thread) {
    AttachThreadInput(current_thread, target_thread, attach);
  }
}

}  // namespace

SingleInstanceLock::SingleInstanceLock(const wchar_t* mutex_name) {
  mutex_ = CreateMutexW(nullptr, TRUE, mutex_name);
  const DWORD last_error = GetLastError();

  if (mutex_ == nullptr) {
    is_primary_instance_ = last_error != ERROR_ACCESS_DENIED;
    return;
  }

  is_primary_instance_ = last_error != ERROR_ALREADY_EXISTS;
}

SingleInstanceLock::~SingleInstanceLock() {
  if (mutex_ == nullptr) {
    return;
  }

  if (is_primary_instance_) {
    ReleaseMutex(mutex_);
  }
  CloseHandle(mutex_);
}

bool SingleInstanceLock::IsPrimaryInstance() const {
  return is_primary_instance_;
}

bool ActivateExistingLanternWindow() {
  HWND existing_window = FindExistingLanternWindow();
  if (existing_window == nullptr) {
    return false;
  }

  SendAppLink(existing_window);

  if (IsIconic(existing_window)) {
    ShowWindow(existing_window, SW_RESTORE);
  } else {
    ShowWindow(existing_window, SW_SHOW);
  }

  const DWORD current_thread = GetCurrentThreadId();
  const HWND foreground_window = GetForegroundWindow();
  const DWORD foreground_thread =
      foreground_window == nullptr
          ? 0
          : GetWindowThreadProcessId(foreground_window, nullptr);
  const DWORD target_thread = GetWindowThreadProcessId(existing_window, nullptr);

  AttachThreadInputIfNeeded(current_thread, foreground_thread, TRUE);
  if (target_thread != foreground_thread) {
    AttachThreadInputIfNeeded(current_thread, target_thread, TRUE);
  }

  BringWindowToTop(existing_window);
  const bool activated = SetForegroundWindow(existing_window) != 0;
  SetFocus(existing_window);

  if (target_thread != foreground_thread) {
    AttachThreadInputIfNeeded(current_thread, target_thread, FALSE);
  }
  AttachThreadInputIfNeeded(current_thread, foreground_thread, FALSE);

  if (!activated) {
    FlashTaskbar(existing_window);
  }
  return true;
}
