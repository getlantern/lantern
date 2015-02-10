#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <shellapi.h>
#include "systray.h"

// Message posted into message loop when Notification Icon is clicked
#define WM_SYSTRAY_MESSAGE (WM_USER + 1)

static NOTIFYICONDATA nid;
static HWND hWnd;
static HMENU hTrayMenu;

void reportWindowsError(const char* action) {
	LPTSTR pErrMsg = NULL;
	DWORD errCode = GetLastError();
	DWORD result = FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|
			FORMAT_MESSAGE_FROM_SYSTEM|
			FORMAT_MESSAGE_ARGUMENT_ARRAY,
			NULL,
			errCode,
			LANG_NEUTRAL,
			pErrMsg,
			0,
			NULL);
	printf("Systray error %s: %d %s\n", action, errCode, pErrMsg);
}

wchar_t* UTF8ToUnicode(const char* str) {
	wchar_t* result;
	int textLen = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL ,0);
	result = (wchar_t *)calloc((textLen+1), sizeof(wchar_t));
	int converted = MultiByteToWideChar(CP_UTF8, 0, str, -1, (LPWSTR)result, textLen);
	// Ensure result is alway zero terminated in case either syscall failed
	if (converted == 0) {
		reportWindowsError("convert UTF8 to UNICODE");
		result[0] = L'\0';
	}
	return result;
}

void ShowMenu(HWND hWnd) {
	POINT p;
	if (0 == GetCursorPos(&p)) {
		reportWindowsError("get tray menu position");
		return;
	};
	SetForegroundWindow(hWnd); // Win32 bug work-around
	TrackPopupMenu(hTrayMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, p.x, p.y, 0, hWnd, NULL);

}

char* GetMenuItemId(int index) {
	MENUITEMINFO menuItemInfo;
	menuItemInfo.cbSize = sizeof(MENUITEMINFO);
	menuItemInfo.fMask = MIIM_DATA;
	if (0 == GetMenuItemInfo(hTrayMenu, index, TRUE, &menuItemInfo)) {
		reportWindowsError("get menu item id");
		return NULL;
	}
	return (char*)menuItemInfo.dwItemData;
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	switch (message) {
		case WM_MENUCOMMAND:
			{
				char * menuId = GetMenuItemId(wParam);
				if (menuId != NULL) {
					systray_menu_item_selected(menuId);
				}
			}
			break;
		case WM_DESTROY:
			Shell_NotifyIcon(NIM_DELETE, &nid);
			PostQuitMessage(0);
			break;
		case WM_SYSTRAY_MESSAGE:
			switch(lParam) {
				case WM_RBUTTONUP:
					ShowMenu(hWnd);
					break;
				case WM_LBUTTONUP:
					ShowMenu(hWnd);
					break;
				default:
					return DefWindowProc(hWnd, message, wParam, lParam);
			};
			break;
		default:
			return DefWindowProc(hWnd, message, wParam, lParam);
	}
	return 0;
}

void MyRegisterClass(HINSTANCE hInstance, TCHAR* szWindowClass) {
	WNDCLASSEX wcex;

	wcex.cbSize = sizeof(WNDCLASSEX);
	wcex.style          = CS_HREDRAW | CS_VREDRAW;
	wcex.lpfnWndProc    = WndProc;
	wcex.cbClsExtra     = 0;
	wcex.cbWndExtra     = 0;
	wcex.hInstance      = hInstance;
	wcex.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
	wcex.hCursor        = LoadCursor(NULL, IDC_ARROW);
	wcex.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
	wcex.lpszMenuName   = 0;
	wcex.lpszClassName  = szWindowClass;
	wcex.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

	RegisterClassEx(&wcex);
}

HWND InitInstance(HINSTANCE hInstance, int nCmdShow, TCHAR* szWindowClass) {
	HWND hWnd = CreateWindow(szWindowClass, TEXT(""), WS_OVERLAPPEDWINDOW,
			CW_USEDEFAULT, 0, CW_USEDEFAULT, 0, NULL, NULL, hInstance, NULL);
	if (!hWnd) {
		return 0;
	}

	ShowWindow(hWnd, nCmdShow);
	UpdateWindow(hWnd);

	return hWnd;
}


BOOL createMenu() {
	hTrayMenu = CreatePopupMenu();
	MENUINFO menuInfo;
	menuInfo.cbSize = sizeof(MENUINFO);
	menuInfo.fMask = MIM_APPLYTOSUBMENUS | MIM_STYLE;
	menuInfo.dwStyle = MNS_NOTIFYBYPOS;
	return SetMenuInfo(hTrayMenu, &menuInfo);
}

BOOL addNotifyIcon() {
	nid.cbSize = sizeof(NOTIFYICONDATA);
	nid.hWnd = hWnd;
	nid.uID = 100;
	nid.uCallbackMessage = WM_SYSTRAY_MESSAGE;
	nid.uFlags = NIF_MESSAGE;
	return Shell_NotifyIcon(NIM_ADD, &nid);
}

int nativeLoop(void) {
	HINSTANCE hInstance = GetModuleHandle(NULL);
	TCHAR* szWindowClass = TEXT("SystrayClass");
	MyRegisterClass(hInstance, szWindowClass);
	hWnd = InitInstance(hInstance, FALSE, szWindowClass); // Don't show window
	if (!hWnd) {
		return EXIT_FAILURE;
	}
	if (!createMenu() || !addNotifyIcon()) {
		return EXIT_FAILURE;
	}
	systray_ready();

	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}   
	return EXIT_SUCCESS;
}


void setIcon(const char* iconBytes, int length) {
	HICON hIcon;
	// This is really hacky, but LoadImage won't let me load an image from memory.
	// So we have to write out a temporary file, load it from there, then delete the file.

	// From http://msdn.microsoft.com/en-us/library/windows/desktop/aa363875.aspx
	TCHAR szTempFileName[MAX_PATH+1];
	TCHAR lpTempPathBuffer[MAX_PATH+1];
	int dwRetVal = GetTempPath(MAX_PATH+1, lpTempPathBuffer);
	if (dwRetVal > MAX_PATH+1 || (dwRetVal == 0)) {
		reportWindowsError("get temp icon path");
		return;
	}

	int uRetVal = GetTempFileName(lpTempPathBuffer, TEXT("systray_"), 0, szTempFileName);
	if (uRetVal == 0) {
		reportWindowsError("get temp icon file name");
		return;
	}

	FILE* fIcon = _wfopen(szTempFileName, TEXT("wb"));
	if (fIcon == NULL) {
		reportWindowsError("open temp icon file to write");
		return;
	}
	ssize_t bytesWritten = fwrite(iconBytes, 1, length, fIcon);
	fclose(fIcon);
	if (bytesWritten != length) {
		printf("error write temp icon file\n");
	} else {

		hIcon = LoadImage(NULL, szTempFileName, IMAGE_ICON, 64, 64, LR_LOADFROMFILE);
		if (hIcon == NULL) {
			reportWindowsError("load icon image");
		} else {

			nid.hIcon = hIcon;
			nid.uFlags = NIF_ICON;
			Shell_NotifyIcon(NIM_MODIFY, &nid);
		}
	}
	_wremove(szTempFileName);

}

// Don't support for Windows
void setTitle(char* ctitle) {
	free(ctitle);
}

void setTooltip(char* ctooltip) {
	wchar_t* tooltip = UTF8ToUnicode(ctooltip);
	wcsncpy(nid.szTip, tooltip, 64);
	nid.uFlags = NIF_TIP;
	Shell_NotifyIcon(NIM_MODIFY, &nid);
	free(tooltip);
	free(ctooltip);
}

void add_or_update_menu_item(char* menuId, char* ctitle, char* ctooltip, short disabled, short checked) {
	wchar_t* title = UTF8ToUnicode(ctitle);
	MENUITEMINFO menuItemInfo;
	menuItemInfo.cbSize = sizeof(MENUITEMINFO);
	menuItemInfo.fMask = MIIM_FTYPE | MIIM_STRING | MIIM_DATA | MIIM_STATE;
	menuItemInfo.fType = MFT_STRING;
	menuItemInfo.dwTypeData = title;
	menuItemInfo.cch = wcslen(title) + 1;
	menuItemInfo.dwItemData = (ULONG_PTR)menuId;
	menuItemInfo.fState = 0;
	if (disabled == 1) {
		menuItemInfo.fState |= MFS_DISABLED;
	}
	if (checked == 1) {
		menuItemInfo.fState |= MFS_CHECKED;
	}

	int itemCount = GetMenuItemCount(hTrayMenu);
	int i;
	for (i = 0; i < itemCount; i++) {
		char * idString = GetMenuItemId(i);
		if (NULL == idString) {
			continue;
		}
		if (strcmp(menuId, idString) == 0) {
			free(idString);
			SetMenuItemInfo(hTrayMenu, i, TRUE, &menuItemInfo);
			break;
		}
	}
	if (i == itemCount) {
		InsertMenuItem(hTrayMenu, -1, TRUE, &menuItemInfo);
	}
	free(title);
	free(ctitle);
	free(ctooltip);
}

void quit() {
	PostMessage(hWnd, WM_DESTROY, 0, 0);
}
