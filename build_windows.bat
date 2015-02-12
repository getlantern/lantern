go build -a -ldflags -H=windowsgui github.com/getlantern/flashlight
move flashlight.exe lantern.exe
"C:\Program Files\NSIS\Bin\makensis.exe" lantern.nsi