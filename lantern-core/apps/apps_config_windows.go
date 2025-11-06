package apps

const appExtension = ".exe"

// msg="found process path: C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"
func defaultAppDirs() []string {
	return []string{
		"C:\\Program Files",
	}
}

var excludeDirs = []string{}

// getIconPath finds the .icns file inside the app bundle
func getIconPath(appPath string) (string, error) {
	/*
		// Load kernel32.dll
		//kernel32 := syscall.NewLazyDLL("kernel32.dll")
		//loadLibraryExW := kernel32.NewProc("LoadLibraryExW")
		// ... other kernel32 functions

		// Load user32.dll
		//user32 := syscall.NewLazyDLL("user32.dll")
		// ... user32 functions

		// Load shell32.dll
		shell32 := syscall.NewLazyDLL("shell32.dll")
		extractIconExW := shell32.NewProc("ExtractIconExW")

		executablePath, err := syscall.UTF16PtrFromString(appPath)
		if err != nil {
			return "", fmt.Errorf("could not get executable path %w", err)
		}

		iconIndex := int32(0)
		var largeIcon, smallIcon syscall.Handle

		// Example of calling ExtractIconExW (simplified)
		// You would need to allocate memory for large and small icons
		// and handle the return values and errors properly.
		ret, _, err := extractIconExW.Call(
			uintptr(unsafe.Pointer(executablePath)),
			uintptr(iconIndex),
			uintptr(unsafe.Pointer(&largeIcon)),
			uintptr(unsafe.Pointer(&smallIcon)),
			uintptr(1), // Number of icons to extract
		)

		if ret == 0 {
			return "", errors.New("no icons extracted")
		}

		if err != nil && err.(syscall.Errno) != 0 {
			fmt.Printf("Error calling ExtractIconExW: %v\n", err)
		} else {
			fmt.Println("ExtractIconExW called (check for icon handles)")
		}

		if largeIcon != 0 {
			err = SaveIconToFile(largeIcon, "extracted_large_icon.ico")
			if err != nil {
				fmt.Printf("Error saving large icon: %v\n", err)
			} else {
				fmt.Println("Successfully saved large icon to extracted_large_icon.ico")
			}
			// Destroy the icon handle after use
			procDestroyIcon.Call(uintptr(largeIcon))
		}

		if smallIcon != 0 {
			// Destroy the icon handle after use
			procDestroyIcon.Call(uintptr(smallIcon))
		}

		fmt.Printf("Large icon handle: %v\n", largeIcon)
		fmt.Printf("Small icon handle: %v\n", smallIcon)
	*/

	return "", nil // errors.New("not implemented")
}

func getAppID(appPath string) (string, error) {
	return appPath, nil
	//return "", errors.New("not implemented")
}

/*
var (
	modoleaut32 = syscall.NewLazyDLL("oleaut32.dll")
	modgdi32    = syscall.NewLazyDLL("gdi32.dll")
	moduser32   = syscall.NewLazyDLL("user32.dll")
	modkernel32 = syscall.NewLazyDLL("kernel32.dll")

	procOleCreatePictureIndirect = modoleaut32.NewProc("OleCreatePictureIndirect")
	procCreateStreamOnHGlobal    = modoleaut32.NewProc("CreateStreamOnHGlobal")
	procGetHGlobalFromStream     = modoleaut32.NewProc("GetHGlobalFromStream")
	procDestroyIcon              = moduser32.NewProc("DestroyIcon")
	procGlobalLock               = modkernel32.NewProc("GlobalLock")
	procGlobalUnlock             = modkernel32.NewProc("GlobalUnlock")
)

var IID_IPicture = syscall.GUID{0x7bf80980, 0xbf32, 0x101a, [8]byte{0x8b, 0xb8, 0x00, 0xaa, 0x00, 0x38, 0x32, 0xbc}}

const (
	PICTYPE_ICON = 3
)

// PICTDESC structure
type PICTDESC struct {
	CbSizeOfStruct uint32
	PicType        uint32
	Icon           struct {
		Hicon syscall.Handle
	}
	// Add more fields if needed for other picture types
}

// IPicture virtual table (simplified)
type IPictureVtbl struct {
	QueryInterface uintptr
	AddRef         uintptr
	Release        uintptr
	// ... other IPicture methods
	SaveAsFile uintptr
}

// IPicture COM interface (simplified)
type IPicture struct {
	LpVtbl *IPictureVtbl
}

func SaveIconToFile(hIcon syscall.Handle, filePath string) error {

		// 1. Create a PICTDESC structure
		picDesc := PICTDESC{
			CbSizeOfStruct: uint32(unsafe.Sizeof(PICTDESC{})),
			PicType:        PICTYPE_ICON,
		}
		picDesc.Icon.Hicon = hIcon

		// 2. Create an IPicture interface
		var pPicture *IPicture
		hr, _, _ := procOleCreatePictureIndirect.Call(
			uintptr(unsafe.Pointer(&picDesc)),
			uintptr(unsafe.Pointer(&IID_IPicture)),
			uintptr(0), // fOwn
			uintptr(unsafe.Pointer(&pPicture)))
		if hr != 0 {
			return fmt.Errorf("OleCreatePictureIndirect failed: %x", hr)
		}
		defer syscall.Syscall(pPicture.LpVtbl.Release, 1, uintptr(unsafe.Pointer(pPicture)), 0, 0)

		// 3. Create a memory stream
		var pStream *syscall.IStream
		hr, _, _ = procCreateStreamOnHGlobal.Call(0, uintptr(1), uintptr(unsafe.Pointer(&pStream))) // TRUE for delete on release
		if hr != 0 {
			return fmt.Errorf("CreateStreamOnHGlobal failed: %x", hr)
		}
		defer syscall.Syscall(pStream.LpVtbl.Release, 1, uintptr(unsafe.Pointer(pStream)), 0, 0)

		// 4. Save the picture to the stream
		var cbSize int32
		hr, _, _ = syscall.Syscall(pPicture.LpVtbl.SaveAsFile, 3,
			uintptr(unsafe.Pointer(pStream)),
			uintptr(1), // fSaveMemCopy
			uintptr(unsafe.Pointer(&cbSize)))
		if hr != 0 {
			return fmt.Errorf("IPicture::SaveAsFile failed: %x", hr)
		}

		// 5. Get the HGLOBAL handle from the stream
		var hBuf syscall.Handle
		hr, _, _ = procGetHGlobalFromStream.Call(uintptr(unsafe.Pointer(pStream)), uintptr(unsafe.Pointer(&hBuf)))
		if hr != 0 {
			return fmt.Errorf("GetHGlobalFromStream failed: %x", hr)
		}

		// 6. Lock the global memory to get a pointer
		buffer, _, _ := procGlobalLock.Call(uintptr(hBuf))
		if buffer == 0 {
			return fmt.Errorf("GlobalLock failed")
		}
		defer procGlobalUnlock.Call(uintptr(hBuf))

		// 7. Write the buffer to a file
		data := (*[1 << 30]byte)(unsafe.Pointer(buffer))[:cbSize:cbSize]
		err := os.WriteFile(filePath, data, 0644)
		if err != nil {
			return fmt.Errorf("WriteFile failed: %w", err)
		}

		return nil

	return errors.New("not implemented")
}
*/
