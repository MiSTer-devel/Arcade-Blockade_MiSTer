#pragma once
#include <string> 
#include "imgui.h"
#include "verilatedos.h"

struct DebugConsole {
public:
	std::string prefix;
	void AddLog(const char* fmt, ...) IM_FMTARGS(2);
	DebugConsole();
	~DebugConsole();
	void ClearLog();
	void Draw(const char* title, bool* p_open);
	void    ExecCommand(const char* command_line);
	int     TextEditCallback(ImGuiInputTextCallbackData* data);
};
