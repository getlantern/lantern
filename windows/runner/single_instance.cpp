#include "single_instance.h"

#include "app_links/app_links_plugin_c_api.h"
#include "win32_window.h"

#include <shellapi.h>

namespace {

HWND FindExistingLanternWindow() {
  return FindWindowW(Win32Window::GetWindowClassName(), nullptr);
}

bool IsSchemeFirstChar(wchar_t value) {
  return (value >= L'A' && value <= L'Z') || (value >= L'a' && value <= L'z');
}

bool IsSchemeChar(wchar_t value) {
  return IsSchemeFirstChar(value) || (value >= L'0' && value <= L'9') ||
         value == L'+' || value == L'.' || value == L'-';
}

bool HasUriScheme(const wchar_t* value) {
  if (value == nullptr || !IsSchemeFirstChar(value[0])) {
    return false;
  }

  for (int i = 1; value[i] != L'\0'; ++i) {
    if (value[i] == L':') {
      return true;
    }
    if (!IsSchemeChar(value[i])) {
      return false;
    }
  }
  return false;
}

bool HasLaunchAppLink() {
  int argc = 0;
  wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return false;
  }

  const bool has_launch_app_link = argc == 2 && HasUriScheme(argv[1]);
  LocalFree(argv);
  return has_launch_app_link;
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

SingleInstanceReadyEvent::SingleInstanceReadyEvent(const wchar_t* event_name) {
  event_ = CreateEventW(nullptr, TRUE, FALSE, event_name);
}

SingleInstanceReadyEvent::~SingleInstanceReadyEvent() {
  if (event_ != nullptr) {
    CloseHandle(event_);
  }
}

void SingleInstanceReadyEvent::Signal() {
  if (event_ != nullptr) {
    SetEvent(event_);
  }
}

bool SingleInstanceReadyEvent::Wait(DWORD timeout_ms) const {
  if (event_ == nullptr) {
    return false;
  }
  return WaitForSingleObject(event_, timeout_ms) == WAIT_OBJECT_0;
}

bool ActivateExistingLanternWindow() {
  HWND existing_window = FindExistingLanternWindow();
  if (existing_window == nullptr) {
    return false;
  }

  // SendAppLink reads this process's command line. Guard it so plain launches
  // only focus the existing window and never emit an empty app-link event.
  if (HasLaunchAppLink()) {
    SendAppLink(existing_window);
  }

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

bool ActivateExistingLanternWindowWithRetry(DWORD timeout_ms,
                                            DWORD retry_interval_ms) {
  const ULONGLONG deadline = GetTickCount64() + timeout_ms;

  do {
    if (ActivateExistingLanternWindow()) {
      return true;
    }

    const ULONGLONG now = GetTickCount64();
    if (now >= deadline) {
      break;
    }

    DWORD sleep_ms = static_cast<DWORD>(deadline - now);
    if (sleep_ms > retry_interval_ms) {
      sleep_ms = retry_interval_ms;
    }
    Sleep(sleep_ms);
  } while (true);

  return false;
}
