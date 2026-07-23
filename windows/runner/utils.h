#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both the runner and the Flutter library.
void CreateAndAttachConsole();

// Points WebView2 at a writable per-user data folder by setting the
// WEBVIEW2_USER_DATA_FOLDER environment variable (creating the folder if
// needed). Without this, production builds installed under Program Files
// default their WebView2 data folder next to the read-only executable, so
// WebView2 fails to initialize and in-app webviews (e.g. payment flows) stay
// blank. Must be called before any WebView2 environment is created. Existing
// values of the variable are left untouched so machine-level overrides win.
void EnsureWebView2UserDataFolder();

// Takes a null-terminated wchar_t* encoded in UTF-16 and returns a std::string
// encoded in UTF-8. Returns an empty std::string on failure.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// Gets the command line arguments passed in as a std::vector<std::string>,
// encoded in UTF-8. Returns an empty std::vector<std::string> on failure.
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_
