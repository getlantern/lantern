//go:build windows

package apps

import (
	"bytes"
	"fmt"
	"image"
	"image/png"
	"os"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

const (
	BI_RGB = 0
	// draw image + mask
	DI_NORMAL = 0x0003
)

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

// parseIconLocation parses strings like:
//
//	"C:\Path\App.exe,0"
//	"C:\Path\App.dll,-123"
//
// and returns (file, index)
func parseIconLocation(s string) (string, int) {
	s = strings.TrimSpace(s)
	if s == "" {
		return "", 0
	}
	s = expandPercentEnv(s)
	s = strings.Trim(s, `"`)

	i := strings.LastIndex(s, ",")
	if i < 0 {
		return s, 0
	}

	left := strings.TrimSpace(strings.Trim(s[:i], `"`))
	right := strings.TrimSpace(s[i+1:])
	idx := 0
	if right != "" {
		sign := 1
		if strings.HasPrefix(right, "-") {
			sign = -1
			right = strings.TrimPrefix(right, "-")
		}
		n := 0
		for _, r := range right {
			if r < '0' || r > '9' {
				return s, 0
			}
			n = n*10 + int(r-'0')
		}
		idx = sign * n
	}

	return left, idx
}

// For scanAppDirs fallback. Uses exe itself, index 0
func getIconBytes(appPath string) ([]byte, error) {
	return getIconBytesFromLocation(appPath, 0)
}

func getIconBytesFromLocation(file string, index int) ([]byte, error) {
	if file == "" {
		return nil, fmt.Errorf("empty icon file")
	}
	if _, err := os.Stat(file); err != nil {
		return nil, err
	}

	img, err := extractIconAsImage(file, index, 32)
	if err != nil {
		return nil, err
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func extractIconAsImage(path string, index int, size int) (*image.RGBA, error) {
	p, err := windows.UTF16PtrFromString(path)
	if err != nil {
		return nil, err
	}

	var hLarge, hSmall windows.Handle
	r1, _, callErr := procExtractIconExW.Call(
		uintptr(unsafe.Pointer(p)),
		uintptr(index),
		uintptr(unsafe.Pointer(&hLarge)),
		uintptr(unsafe.Pointer(&hSmall)),
		uintptr(1),
	)
	if r1 == 0 {
		return nil, fmt.Errorf("ExtractIconExW failed: %v", callErr)
	}

	// prefer large
	hicon := hLarge
	if hicon == 0 {
		hicon = hSmall
	}
	if hicon == 0 {
		return nil, fmt.Errorf("no icon returned")
	}

	defer func() {
		if hLarge != 0 {
			procDestroyIcon.Call(uintptr(hLarge))
		}
		if hSmall != 0 && hSmall != hLarge {
			procDestroyIcon.Call(uintptr(hSmall))
		}
	}()

	bgra, err := drawIconToBGRA(hicon, size, size)
	if err != nil {
		return nil, err
	}

	out := image.NewRGBA(image.Rect(0, 0, size, size))
	// BGRA -> RGBA
	for i := 0; i < len(bgra); i += 4 {
		b, g, r, a := bgra[i], bgra[i+1], bgra[i+2], bgra[i+3]
		out.Pix[i] = r
		out.Pix[i+1] = g
		out.Pix[i+2] = b
		out.Pix[i+3] = a
	}

	return out, nil
}

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

func drawIconToBGRA(hicon windows.Handle, w, h int) ([]byte, error) {
	hdc, _, _ := procGetDC.Call(0)
	if hdc == 0 {
		return nil, fmt.Errorf("GetDC failed")
	}
	defer procReleaseDC.Call(0, hdc)

	memDC, _, _ := procCreateCompatibleDC.Call(hdc)
	if memDC == 0 {
		return nil, fmt.Errorf("CreateCompatibleDC failed")
	}
	defer procDeleteDC.Call(memDC)

	var bi bitmapInfo
	bi.Header.Size = uint32(unsafe.Sizeof(bi.Header))
	bi.Header.Width = int32(w)
	bi.Header.Height = -int32(h)
	bi.Header.Planes = 1
	bi.Header.BitCount = 32
	bi.Header.Compression = BI_RGB

	var bitsPtr uintptr
	hbmp, _, _ := procCreateDIBSection.Call(
		memDC,
		uintptr(unsafe.Pointer(&bi)),
		uintptr(BI_RGB),
		uintptr(unsafe.Pointer(&bitsPtr)),
		0,
		0,
	)
	if hbmp == 0 || bitsPtr == 0 {
		return nil, fmt.Errorf("procCreateDIBSection failed")
	}
	defer procDeleteObject.Call(hbmp)

	oldObj, _, _ := procSelectObject.Call(memDC, hbmp)
	defer procSelectObject.Call(memDC, oldObj)

	ok, _, _ := procDrawIconEx.Call(
		memDC,
		0, 0,
		uintptr(hicon),
		uintptr(w), uintptr(h),
		0,
		0,
		DI_NORMAL,
	)
	if ok == 0 {
		return nil, fmt.Errorf("DrawIconEx failed")
	}

	n := w * h * 4
	src := unsafe.Slice((*byte)(unsafe.Pointer(bitsPtr)), n)
	out := make([]byte, n)
	copy(out, src)
	return out, nil
}

// not used, windows uses IconBytes
func getIconPath(appPath string) (string, error) {
	return "", nil
}
