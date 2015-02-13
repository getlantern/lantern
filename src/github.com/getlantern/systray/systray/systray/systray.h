#pragma once

extern "C" {
	__declspec(dllexport) int nativeLoop(void (*systray_ready)(), void (*_systray_menu_item_selected)(int menu_id));

	__declspec(dllexport) void setIcon(const char* iconFile);
	__declspec(dllexport) void setTooltip(char* tooltip);
	__declspec(dllexport) void add_or_update_menu_item(int menuId, char* title, char* tooltip, short disabled, short checked);
	__declspec(dllexport) void quit();
}