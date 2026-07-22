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
  // Respect an existing non-empty override (machine-level or debug config)
  // rather than clobbering it. Read into a buffer instead of probing with a
  // null one: the size probe can't tell "unset" from "set but empty", and an
  // empty value isn't a meaningful override. GetEnvironmentVariableW returns the
  // number of chars written — 0 when unset or empty, or the required size when
  // an override is too long to fit (still counts as present).
  wchar_t existing[MAX_PATH];
  if (::GetEnvironmentVariableW(L"WEBVIEW2_USER_DATA_FOLDER", existing,
                                ARRAYSIZE(existing)) > 0) {
    return;
  }

  const wchar_t kUnexpanded[] = L"%LOCALAPPDATA%\\Lantern\\WebView2";
  wchar_t path[MAX_PATH];
  DWORD length =
      ::ExpandEnvironmentStringsW(kUnexpanded, path, ARRAYSIZE(path));
  if (length == 0 || length > ARRAYSIZE(path)) {
    return;
  }

  // If %LOCALAPPDATA% is undefined, ExpandEnvironmentStringsW leaves the
  // template literal, so the result starts with '%'; a real expanded path
  // starts with a drive letter. Only the leading char is a reliable signal —
  // '%' is legal elsewhere in a folder name — so don't reject those. Bail on an
  // unexpanded path rather than create a garbage relative folder.
  if (path[0] == L'%') {
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

  // Only advertise the folder if it now exists as a directory: CreateDirectoryW
  // may have failed (permissions, invalid path), and pointing WebView2 at a
  // nonexistent folder just moves the failure somewhere harder to diagnose. If
  // we couldn't create it, leave WebView2 to its default.
  DWORD attrs = ::GetFileAttributesW(path);
  if (attrs == INVALID_FILE_ATTRIBUTES || !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
    return;
  }

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
