package processpath

import (
	"path/filepath"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

func normalize(path string) string {
	volume := filepath.VolumeName(path)
	if len(volume) != 2 || volume[1] != ':' || !filepath.IsAbs(path) {
		return strings.ToLower(path)
	}
	path = filepath.Clean(path)
	fallback := strings.ToLower(path)
	if strings.Contains(path[2:], ":") {
		return fallback
	}
	root, err := windows.UTF16PtrFromString(volume + `\`)
	if err != nil {
		return fallback
	}
	switch windows.GetDriveType(root) {
	case windows.DRIVE_FIXED, windows.DRIVE_REMOVABLE, windows.DRIVE_CDROM, windows.DRIVE_RAMDISK:
	default:
		return fallback
	}
	rootHandle, err := windows.CreateFile(root, windows.FILE_READ_ATTRIBUTES|windows.SYNCHRONIZE,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE, nil,
		windows.OPEN_EXISTING, windows.FILE_FLAG_BACKUP_SEMANTICS|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
	if err != nil {
		return fallback
	}
	defer windows.CloseHandle(rootHandle)
	name, err := windows.NewNTUnicodeString(path[len(volume)+1:])
	if err != nil {
		return fallback
	}
	attributes := windows.OBJECT_ATTRIBUTES{
		Length:        uint32(unsafe.Sizeof(windows.OBJECT_ATTRIBUTES{})),
		RootDirectory: rootHandle,
		ObjectName:    name,
		// Do not follow reparse points into network shares.
		Attributes: windows.OBJ_DONT_REPARSE | windows.OBJ_CASE_INSENSITIVE,
	}
	var handle windows.Handle
	err = windows.NtCreateFile(&handle, windows.FILE_READ_ATTRIBUTES|windows.SYNCHRONIZE,
		&attributes, &windows.IO_STATUS_BLOCK{}, nil, 0,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE,
		windows.FILE_OPEN, windows.FILE_SYNCHRONOUS_IO_NONALERT, 0, 0)
	if err != nil {
		return fallback
	}
	defer windows.CloseHandle(handle)
	buffer := make([]uint16, windows.MAX_PATH)
	for {
		n, err := windows.GetFinalPathNameByHandle(handle, &buffer[0], uint32(len(buffer)), 0)
		if err != nil || n == 0 {
			return fallback
		}
		if int(n) < len(buffer) {
			resolved, ok := strings.CutPrefix(windows.UTF16ToString(buffer[:n]), `\\?\`)
			if !ok || !strings.EqualFold(filepath.VolumeName(resolved), volume) {
				return fallback
			}
			return strings.ToLower(filepath.Clean(resolved))
		}
		if n >= windows.MAX_LONG_PATH {
			return fallback
		}
		buffer = make([]uint16, n+1)
	}
}
