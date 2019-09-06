# i18n

A simple i18n library in Go, only supports text translation currently.

# Usage

### Setup

Place all you translation json files under 'locale' directory.
*  Use current user's locale
`UseOSLocale()`

*  Specifies locale to use manually
`SetLocale("en_US")`

If your translations is under another place,
`SetMessagesDir("mydir")`

Or feed from in memory data structure.
`SetMessagesFunc(func)`

### Use

```go
t := i18n.T("KEY_OF_STRING")
t := i18n.T("KEY_OF_FORMAT_STRING", var1, var1, ...)
```
