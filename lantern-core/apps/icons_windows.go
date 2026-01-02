// apps_icon_windows.go
//go:build windows

package apps

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

const (
	biRGB    = 0
	diNormal = 0x0003

	defaultIconSize = 32
)

// We call a few Win32 APIs directly for icon extraction
var (
	modShell32         = windows.NewLazySystemDLL("shell32.dll")
	procExtractIconExW = modShell32.NewProc("ExtractIconExW")

	modUser32       = windows.NewLazySystemDLL("user32.dll")
	procDestroyIcon = modUser32.NewProc("DestroyIcon")
	procGetDC       = modUser32.NewProc("GetDC")
	procReleaseDC   = modUser32.NewProc("ReleaseDC")
	procDrawIconEx  = modUser32.NewProc("DrawIconEx")

	modGdi32               = windows.NewLazySystemDLL("gdi32.dll")
	procCreateCompatibleDC = modGdi32.NewProc("CreateCompatibleDC")
	procDeleteDC           = modGdi32.NewProc("DeleteDC")
	procCreateDIBSection   = modGdi32.NewProc("CreateDIBSection")
	procSelectObject       = modGdi32.NewProc("SelectObject")
	procDeleteObject       = modGdi32.NewProc("DeleteObject")
)

type bitmapInfoHeader struct {
	Size          uint32
	Width         int32
	Height        int32
	Planes        uint16
	BitCount      uint16
	Compression   uint32
	SizeImage     uint32
	XPelsPerMeter int32
	YPelsPerMeter int32
	ClrUsed       uint32
	ClrImportant  uint32
}
type bitmapInfo struct {
	Header bitmapInfoHeader
	Colors [1]uint32
}

// parseIconLocation parses strings like:
//
//	"C:\Path\App.exe,0"
//	"%SystemRoot%\system32\shell32.dll,-154"
//
// It returns (file, index)
func parseIconLocation(s string) (string, int) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", 0
	}

	s = expandPercentEnv(s)
	s = strings.Trim(s, `"`)

	lastComma := strings.LastIndex(s, ",")
	if lastComma > 0 {
		tail := strings.TrimSpace(s[lastComma+1:])
		// if tail looks like an int, treat as index
		if tail != "" && len(tail) <= 10 {
			if idx, err := strconv.Atoi(tail); err == nil {
				file := strings.TrimSpace(strings.Trim(s[:lastComma], `"`))
				return file, idx
			}
		}
	}

	return strings.TrimSpace(s), 0
}

func getIconPath(string) (string, error) { return "", nil }

// getIconBytes extracts an icon for an exe/dll path
func getIconBytes(appPath string) ([]byte, error) {
	if appPath == "" {
		return nil, nil
	}
	// Prefer the target exe itself at index 0
	return getIconBytesFromLocation(appPath, 0)
}

// getIconBytesFromLocation extracts an icon from (file,index) and returns it as PNG bytes
func getIconBytesFromLocation(file string, index int) ([]byte, error) {
	file = strings.TrimSpace(file)
	if file == "" {
		return nil, errors.New("empty icon file")
	}
	file = expandPercentEnv(file)
	file = strings.Trim(file, `"`)

	// Many registry DisplayIcon values include args or weird suffixes
	// If file is not an existing file, try to salvage by cutting at first .exe/.dll/.ico
	if _, err := os.Stat(file); err != nil {
		l := strings.ToLower(file)
		for _, ext := range []string{".exe", ".dll", ".ico"} {
			if i := strings.Index(l, ext); i >= 0 {
				cand := file[:i+len(ext)]
				if _, err2 := os.Stat(cand); err2 == nil {
					file = cand
					break
				}
			}
		}
	}

	if _, err := os.Stat(file); err != nil {
		return nil, fmt.Errorf("icon file not found: %w (%s)", err, file)
	}

	pFile, err := windows.UTF16PtrFromString(file)
	if err != nil {
		return nil, err
	}

	var large windows.Handle
	var small windows.Handle

	// ExtractIconExW(file, index, &large, &small, 1)
	r1, _, _ := procExtractIconExW.Call(
		uintptr(unsafe.Pointer(pFile)),
		uintptr(int32(index)),
		uintptr(unsafe.Pointer(&large)),
		uintptr(unsafe.Pointer(&small)),
		1,
	)
	if r1 == 0 {
		// fallback: try index 0 if requested index fails
		if index != 0 {
			return getIconBytesFromLocation(file, 0)
		}
		return nil, fmt.Errorf("ExtractIconExW returned 0 for %s,%d", file, index)
	}

	// Prefer large icon if present
	hicon := large
	if hicon == 0 {
		hicon = small
	}
	if hicon == 0 {
		return nil, fmt.Errorf("no icon handles for %s,%d", file, index)
	}
	defer procDestroyIcon.Call(uintptr(hicon))
	if small != 0 && small != hicon {
		defer procDestroyIcon.Call(uintptr(small))
	}
	if large != 0 && large != hicon {
		defer procDestroyIcon.Call(uintptr(large))
	}

	img, err := drawIconToRGBA(hicon, defaultIconSize, defaultIconSize)
	if err != nil {
		return nil, err
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func drawIconToRGBA(hicon windows.Handle, w, h int) (*image.RGBA, error) {
	// screen DC
	hdc, _, _ := procGetDC.Call(0)
	if hdc == 0 {
		return nil, errors.New("GetDC failed")
	}
	defer procReleaseDC.Call(0, hdc)

	// mem DC
	memDC, _, _ := procCreateCompatibleDC.Call(hdc)
	if memDC == 0 {
		return nil, errors.New("CreateCompatibleDC failed")
	}
	defer procDeleteDC.Call(memDC)

	// Create DIB section (top-down by using negative height)
	var bi bitmapInfo
	bi.Header.Size = uint32(unsafe.Sizeof(bi.Header))
	bi.Header.Width = int32(w)
	bi.Header.Height = -int32(h) // top-down
	bi.Header.Planes = 1
	bi.Header.BitCount = 32
	bi.Header.Compression = biRGB

	var bits unsafe.Pointer
	hbmp, _, _ := procCreateDIBSection.Call(
		memDC,
		uintptr(unsafe.Pointer(&bi)),
		0,
		uintptr(unsafe.Pointer(&bits)),
		0,
		0,
	)
	if hbmp == 0 || bits == nil {
		return nil, errors.New("CreateDIBSection failed")
	}
	defer procDeleteObject.Call(hbmp)

	oldObj, _, _ := procSelectObject.Call(memDC, hbmp)
	defer procSelectObject.Call(memDC, oldObj)

	// DrawIconEx(memDC, 0, 0, hicon, w, h, 0, 0, DI_NORMAL)
	r1, _, _ := procDrawIconEx.Call(
		memDC,
		0,
		0,
		uintptr(hicon),
		uintptr(w),
		uintptr(h),
		0,
		0,
		diNormal,
	)
	if r1 == 0 {
		return nil, errors.New("DrawIconEx failed")
	}

	// Copy BGRA to RGBA
	stride := w * 4
	src := unsafe.Slice((*byte)(bits), h*stride)

	img := image.NewRGBA(image.Rect(0, 0, w, h))
	dst := img.Pix

	for i := 0; i < len(src); i += 4 {
		// BGRA -> RGBA
		b := src[i+0]
		g := src[i+1]
		r := src[i+2]
		a := src[i+3]
		dst[i+0] = r
		dst[i+1] = g
		dst[i+2] = b
		dst[i+3] = a
	}

	return img, nil
}

// Normalize weird relative icon file paths from shortcuts/registry
func normalizePathIfNeeded(p string) string {
	p = strings.TrimSpace(p)
	if p == "" {
		return ""
	}
	p = strings.Trim(p, `"`)
	p = expandPercentEnv(p)
	if !filepath.IsAbs(p) {
		if cwd, err := os.Getwd(); err == nil {
			p = filepath.Join(cwd, p)
		}
	}
	return p
}
