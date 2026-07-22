#include "utils.h"

#include <flutter_windows.h>
#include <io.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE *unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }
    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

void EnsureWebView2UserDataFolder() {
  // Respect an existing value (e.g. a machine-level override or a debug
  // configuration) rather than clobbering it.
  if (::GetEnvironmentVariableW(L"WEBVIEW2_USER_DATA_FOLDER", nullptr, 0) > 0) {
    return;
  }

  const wchar_t kUnexpanded[] = L"%LOCALAPPDATA%\\Lantern\\WebView2";
  wchar_t path[MAX_PATH];
  DWORD length =
      ::ExpandEnvironmentStringsW(kUnexpanded, path, ARRAYSIZE(path));
  if (length == 0 || length > ARRAYSIZE(path)) {
    return;
  }

  // Create each directory component in turn; CreateDirectoryW only creates the
  // final segment, so intermediate parents must be created first.
  for (wchar_t* cursor = path; *cursor != L'\0'; ++cursor) {
    if (*cursor == L'\\' && cursor != path && *(cursor - 1) != L':') {
      *cursor = L'\0';
      ::CreateDirectoryW(path, nullptr);
      *cursor = L'\\';
    }
  }
  ::CreateDirectoryW(path, nullptr);

  ::SetEnvironmentVariableW(L"WEBVIEW2_USER_DATA_FOLDER", path);
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert the UTF-16 command line arguments to UTF-8 for the Engine to use.
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  // Skip the first argument as it's the binary name.
  for (int i = 1; i < argc; i++) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);

  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return std::string();
  }
  unsigned int target_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      -1, nullptr, 0, nullptr, nullptr)
    -1; // remove the trailing null character
  int input_length = (int)wcslen(utf16_string);
  std::string utf8_string;
  if (target_length == 0 || target_length > utf8_string.max_size()) {
    return utf8_string;
  }
  utf8_string.resize(target_length);
  int converted_length = ::WideCharToMultiByte(
      CP_UTF8, WC_ERR_INVALID_CHARS, utf16_string,
      input_length, utf8_string.data(), target_length, nullptr, nullptr);
  if (converted_length == 0) {
    return std::string();
  }
  return utf8_string;
}
