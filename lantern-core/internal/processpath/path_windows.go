package processpath

import (
	"errors"
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
	rootHandle, err := openLocalRoot(path)
	if err != nil {
		return fallback
	}
	defer windows.CloseHandle(rootHandle)
	handle, err := openRelativePath(rootHandle, path[len(volume)+1:])
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

// IsLocalFile reports whether path names a local file without traversing reparse points.
func IsLocalFile(path string) bool {
	path = filepath.Clean(path)
	root, err := openLocalRoot(path)
	if err != nil {
		return false
	}
	defer windows.CloseHandle(root)
	handle, err := openRelativePath(root, path[len(filepath.VolumeName(path))+1:])
	if err != nil {
		return false
	}
	defer windows.CloseHandle(handle)
	var info windows.ByHandleFileInformation
	return windows.GetFileInformationByHandle(handle, &info) == nil &&
		info.FileAttributes&windows.FILE_ATTRIBUTE_DIRECTORY == 0
}

func openLocalRoot(path string) (windows.Handle, error) {
	volume := filepath.VolumeName(path)
	if len(volume) != 2 || volume[1] != ':' || !filepath.IsAbs(path) {
		return 0, windows.ERROR_INVALID_NAME
	}
	if strings.Contains(path[2:], ":") {
		return 0, windows.ERROR_INVALID_NAME
	}
	root, err := windows.UTF16PtrFromString(volume + `\`)
	if err != nil {
		return 0, err
	}
	switch windows.GetDriveType(root) {
	case windows.DRIVE_FIXED, windows.DRIVE_REMOVABLE, windows.DRIVE_CDROM, windows.DRIVE_RAMDISK:
	default:
		return 0, windows.ERROR_NOT_SUPPORTED
	}
	return windows.CreateFile(root, windows.FILE_READ_ATTRIBUTES|windows.SYNCHRONIZE,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE, nil,
		windows.OPEN_EXISTING, windows.FILE_FLAG_BACKUP_SEMANTICS|windows.FILE_FLAG_OPEN_REPARSE_POINT, 0)
}

func openRelativePath(root windows.Handle, path string) (windows.Handle, error) {
	name, err := windows.NewNTUnicodeString(path)
	if err != nil {
		return 0, err
	}
	attributes := windows.OBJECT_ATTRIBUTES{
		Length:        uint32(unsafe.Sizeof(windows.OBJECT_ATTRIBUTES{})),
		RootDirectory: root,
		ObjectName:    name,
		// Do not follow reparse points into network shares.
		Attributes: windows.OBJ_DONT_REPARSE | windows.OBJ_CASE_INSENSITIVE,
	}
	var handle windows.Handle
	err = windows.NtCreateFile(&handle, windows.FILE_READ_ATTRIBUTES|windows.SYNCHRONIZE,
		&attributes, &windows.IO_STATUS_BLOCK{}, nil, 0,
		windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE|windows.FILE_SHARE_DELETE,
		windows.FILE_OPEN, windows.FILE_SYNCHRONOUS_IO_NONALERT, 0, 0)
	return handle, err
}

func aliasPattern(path string) string {
	path = normalize(path)
	parent, err := openLocalRoot(path)
	if err != nil {
		return ""
	}
	defer func() { windows.CloseHandle(parent) }()
	parts := strings.Split(path, `\`)
	aliases := make([]string, len(parts))
	for i, part := range parts[1:] {
		handle, err := openRelativePath(parent, part)
		if err != nil {
			return ""
		}
		windows.CloseHandle(parent)
		parent = handle
		aliases[i+1], err = alternateName(handle)
		if err != nil {
			return ""
		}
	}
	return buildAliasPattern(parts, aliases)
}

func alternateName(handle windows.Handle) (string, error) {
	// FileAlternateNameInformation returns FILE_NAME_INFORMATION with an 8.3 name.
	const fileAlternateNameInformation = 21
	var info struct {
		length uint32
		name   [12]uint16
	}
	var status windows.IO_STATUS_BLOCK
	err := windows.NtQueryInformationFile(handle, &status, (*byte)(unsafe.Pointer(&info)),
		uint32(unsafe.Sizeof(info)), fileAlternateNameInformation)
	if errors.Is(err, windows.STATUS_OBJECT_NAME_NOT_FOUND) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	if info.length%2 != 0 || info.length > uint32(len(info.name))*2 || status.Information < uintptr(4+info.length) {
		return "", windows.ERROR_INVALID_DATA
	}
	name := windows.UTF16ToString(info.name[:info.length/2])
	if strings.ContainsAny(name, `\/:`) || name == "." || name == ".." {
		return "", windows.ERROR_INVALID_DATA
	}
	return name, nil
}
