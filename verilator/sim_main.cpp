#include <verilated.h>
#include "Vemu.h"

#include "imgui.h"
#ifndef _MSC_VER
#include <stdio.h>
#include <SDL.h>
#include <SDL_opengl.h>
#else
#define WIN32
#include <dinput.h>
#endif

#include "sim_console.h"
#include "sim_bus.h"
#include "sim_video.h"
#include "sim_input.h"
#include "sim_clock.h"

#include "../imgui/imgui_memory_editor.h"
#include "../imgui/ImGuiFileDialog.h"

#include <iostream>
#include <sstream>
#include <fstream>
#include <iterator>
#include <string>
#include <sstream>
#include <iomanip>

using namespace std;

// Simulation control
// ------------------
int initialReset = 48;
bool run_enable = 1;
int batchSize = 25000000 / 1000000;
bool single_step = 0;
bool multi_step = 0;
int multi_step_amount = 1024;

// Debug GUI 
// ---------
const char* windowTitle = "Verilator Sim: Aznable";
const char* windowTitle_Control = "Simulation control";
const char* windowTitle_DebugLog = "Debug log";
const char* windowTitle_Video = "VGA output";
bool showDebugLog = true;
DebugConsole console;
MemoryEditor mem_edit;

// HPS emulator
// ------------
SimBus bus(console);

// Input handling
// --------------
SimInput input(12, console);
const int input_right = 0;
const int input_left = 1;
const int input_down = 2;
const int input_up = 3;
const int input_fire1 = 4;
const int input_fire2 = 5;
const int input_start_1 = 6;
const int input_start_2 = 7;
const int input_coin_1 = 8;
const int input_coin_2 = 9;
const int input_coin_3 = 10;
const int input_pause = 11;

// Video
// -----
#define VGA_WIDTH 320
#define VGA_HEIGHT 240
#define VGA_ROTATE 0  // 90 degrees anti-clockwise
#define VGA_SCALE_X vga_scale
#define VGA_SCALE_Y vga_scale
SimVideo video(VGA_WIDTH, VGA_HEIGHT, VGA_ROTATE);
float vga_scale = 3.0;

// Verilog module
// --------------
Vemu* top = NULL;
vluint64_t main_time = 0; // Current simulation time.
double sc_time_stamp()
{ // Called by $time in Verilog.
	return main_time;
}

int clockSpeed = 8;	 // This is not used, just a reminder for the dividers below
SimClock clk_sys(1); // 4mhz
SimClock clk_pix(0); // 4mhz

void resetSim()
{
	main_time = 0;
	top->reset = 1;
	clk_sys.Reset();
	clk_pix.Reset();
}


// CPU debug
bool cpu_sync;
bool cpu_sync_last;
std::vector<std::vector<std::string> > opcodes;
std::map<std::string, std::string> opcode_lookup;

void loadOpcodes()
{
	std::string fileName = "8080_opcodes.csv";

	std::string                           header;
	std::ifstream                         reader(fileName);
	if (reader.is_open()) {
		std::string line, column, id;
		std::getline(reader, line);
		header = line;
		while (std::getline(reader, line)) {
			std::stringstream        ss(line);
			std::vector<std::string> columns;
			bool                     withQ = false;
			std::string              part{ "" };
			while (std::getline(ss, column, ',')) {
				auto pos = column.find("\"");
				if (pos < column.length()) {
					withQ = !withQ;
					part += column.substr(0, pos);
					column = column.substr(pos + 1, column.length());
				}
				if (!withQ) {
					column += part;
					columns.emplace_back(std::move(column));
					part = "";
				}
				else {
					part += column + ",";
				}
			}
			opcodes.push_back(columns);
			opcode_lookup[columns[0]] = columns[1];
		}
	}
};

std::string int_to_hex(unsigned char val)
{
	std::stringstream ss;
	ss << std::setfill('0') << std::setw(2) << std::hex << (val | 0);
	return ss.str();
}

std::string get_opcode(int i)
{
	std::string hex = "0x";
	hex.append(int_to_hex(i));
	std::string code = opcode_lookup[hex];
	return code;
}

int verilate()
{

	if (!Verilated::gotFinish())
	{

		// Assert reset during startup
		if (main_time < initialReset) { top->reset = 1; }
		// Deassert reset after startup
		if (main_time == initialReset) { top->reset = 0; }

		// Clock dividers
		clk_sys.Tick();
		clk_pix.Tick();

		// Set system clock in core
		top->clk_sys = clk_sys.clk;

		//// Update console with current cycle for logging
		//console.prefix = "(" + std::to_string(main_time) + ") ";

		// Simulate both edges of system clock
		if (clk_sys.clk != clk_sys.old) {
			if (clk_sys.clk) {
				input.BeforeEval();
				bus.BeforeEval();
			}
			top->eval();
			if (clk_sys.clk) { bus.AfterEval(); }

			cpu_sync = top->emu__DOT__blockade__DOT__SYNC;
			if (cpu_sync && !cpu_sync_last)
			{
				unsigned short pc = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__r16_pc;
				unsigned short addr = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__a;
				unsigned char data = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__d;
				unsigned char i = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__i;
				unsigned char acc = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__acc;

				std::string log = "PC=%04X ADDR=%04x D=%02x ACC=%02X I=%02x ";
				log.append(get_opcode(i));
				console.AddLog(log.c_str(), pc,
					addr,
					data, 
					acc,
					i);

			}

			cpu_sync_last = cpu_sync;


		}

#ifdef DEBUG_AUDIO
		clk_audio.Tick();
		if (clk_audio.IsRising()) {
			// Output audio
			unsigned short audio_l = top->AUDIO_L;
			audioFile.write((const char*)&audio_l, 2);
		}
#endif

		// Output pixels on rising edge of pixel clock
		if (clk_sys.IsRising() && top->emu__DOT__ce_pix) {
			uint32_t colour = 0xFF000000 | top->VGA_B << 16 | top->VGA_G << 8 | top->VGA_R;
			video.Clock(top->VGA_HB, top->VGA_VB, top->VGA_HS, top->VGA_VS, colour);
		}

		main_time++;
		return 1;
	}
	// Stop verilating and cleanup
	top->final();
	delete top;
	exit(0);
	return 0;
}

int main(int argc, char** argv, char** env)
{
	// Create core and initialise
	top = new Vemu();
	Verilated::commandArgs(argc, argv);

#ifdef WIN32
	// Attach debug console to the verilated code
	Verilated::setDebug(console);
#endif

	// Load debug opcodes
	loadOpcodes();


	// Attach bus
	bus.ioctl_addr = &top->ioctl_addr;
	bus.ioctl_index = &top->ioctl_index;
	bus.ioctl_wait = &top->ioctl_wait;
	bus.ioctl_download = &top->ioctl_download;
	bus.ioctl_upload = &top->ioctl_upload;
	bus.ioctl_wr = &top->ioctl_wr;
	bus.ioctl_dout = &top->ioctl_dout;
	bus.ioctl_din = &top->ioctl_din;

	// Set up input module
	input.Initialise();
#ifdef WIN32
	input.SetMapping(input_up, DIK_UP);
	input.SetMapping(input_right, DIK_RIGHT);
	input.SetMapping(input_down, DIK_DOWN);
	input.SetMapping(input_left, DIK_LEFT);
	input.SetMapping(input_fire1, DIK_LCONTROL);
	input.SetMapping(input_fire2, DIK_LALT);
	input.SetMapping(input_start_1, DIK_1);
	input.SetMapping(input_coin_1, DIK_5);
#else
	input.SetMapping(input_up, SDL_SCANCODE_UP);
	input.SetMapping(input_right, SDL_SCANCODE_RIGHT);
	input.SetMapping(input_down, SDL_SCANCODE_DOWN);
	input.SetMapping(input_left, SDL_SCANCODE_LEFT);
	input.SetMapping(input_fire1, SDL_SCANCODE_LCONTROL);
	input.SetMapping(input_fire2, SDL_SCANCODE_LALT);
	input.SetMapping(input_start_1, SDL_SCANCODE_1);
	input.SetMapping(input_coin_1, SDL_SCANCODE_3);
#endif
	// Setup video output
	if (video.Initialise(windowTitle) == 1)
	{
		return 1;
	}

	// Reset simulation
	resetSim();

	// Stage roms for this core
	bus.QueueDownload("roms/blockade/316-0001.u43", 0);
	bus.QueueDownload("roms/blockade/316-0002.u29", 0);
	bus.QueueDownload("roms/blockade/316-0003.u3", 0);
	bus.QueueDownload("roms/blockade/316-0004.u2", 0);

#ifdef WIN32
	MSG msg;
	ZeroMemory(&msg, sizeof(msg));
	while (msg.message != WM_QUIT)
	{
		if (PeekMessage(&msg, NULL, 0U, 0U, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
			continue;
		}
#else
	bool done = false;
	while (!done)
	{
		SDL_Event event;
		while (SDL_PollEvent(&event))
		{
			ImGui_ImplSDL2_ProcessEvent(&event);
			if (event.type == SDL_QUIT)
				done = true;
		}
#endif
		video.StartFrame();

		input.Read();

		// Draw GUI
		// --------
		ImGui::NewFrame();

		// Simulation control window
		ImGui::Begin(windowTitle_Control);
		ImGui::SetWindowPos(windowTitle_Control, ImVec2(0, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Control, ImVec2(500, 150), ImGuiCond_Once);
		if (ImGui::Button("Reset simulation")) { resetSim(); } ImGui::SameLine();
		if (ImGui::Button("Start running")) { run_enable = 1; } ImGui::SameLine();
		if (ImGui::Button("Stop running")) { run_enable = 0; } ImGui::SameLine();
		ImGui::Checkbox("RUN", &run_enable);
		//ImGui::PopItemWidth();
		ImGui::SliderInt("Run batch size", &batchSize, 1, 250000);
		if (single_step == 1) { single_step = 0; }
		if (ImGui::Button("Single Step")) { run_enable = 0; single_step = 1; }
		ImGui::SameLine();
		if (multi_step == 1) { multi_step = 0; }
		if (ImGui::Button("Multi Step")) { run_enable = 0; multi_step = 1; }
		//ImGui::SameLine();
		ImGui::SliderInt("Multi step amount", &multi_step_amount, 8, 1024);

		ImGui::End();

		// Debug log window
		console.Draw(windowTitle_DebugLog, &showDebugLog, ImVec2(500, 700));
		ImGui::SetWindowPos(windowTitle_DebugLog, ImVec2(0, 160), ImGuiCond_Once);
		// Video window
		ImGui::Begin(windowTitle_Video);
		ImGui::SetWindowPos(windowTitle_Video, ImVec2(550, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Video, ImVec2((VGA_WIDTH * VGA_SCALE_X) + 24, (VGA_HEIGHT * VGA_SCALE_Y) + 114), ImGuiCond_Once);

		ImGui::SliderFloat("Zoom", &vga_scale, 1, 8);
		ImGui::SliderInt("Rotate", &video.output_rotate, -1, 1); ImGui::SameLine();
		ImGui::Checkbox("Flip V", &video.output_vflip);
		ImGui::Text("main_time: %d frame_count: %d sim FPS: %f", main_time, video.count_frame, video.stats_fps);
		//ImGui::Text("pixel: %06d line: %03d", video.count_pixel, video.count_line);

		//float vol_l = ((signed short)(top->AUDIO_L) / 256.0f) / 256.0f;
		//float vol_r = ((signed short)(top->AUDIO_R) / 256.0f) / 256.0f;
		//ImGui::ProgressBar(vol_l + 0.5, ImVec2(200, 16), 0); ImGui::SameLine();
		//ImGui::ProgressBar(vol_r + 0.5, ImVec2(200, 16), 0);

		// Draw VGA output
		ImGui::Image(video.texture_id, ImVec2(video.output_width * VGA_SCALE_X, video.output_height * VGA_SCALE_Y));
		ImGui::End();


		//ImGui::Begin("rom_lsb");
		//mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom_lsb__DOT__mem, 1024, 0);
		//ImGui::End();
		//ImGui::Begin("rom_msb");
		//mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom_msb__DOT__mem, 1024, 0);
		//ImGui::End();
		ImGui::Begin("ram");
		mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__ram__DOT__mem, 1024, 0);
		ImGui::End();
		ImGui::Begin("sram");
		mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__sram__DOT__mem, 256, 0);
		ImGui::End();
		//ImGui::Begin("prom_lsb");
		//mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom_lsb__DOT__mem, 256, 0);
		//ImGui::End();
		//ImGui::Begin("prom_msb");
		//mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom_msb__DOT__mem, 256, 0);
		//ImGui::End();

		// ImGui::Begin("ROM");
		// memoryEditor_hs.DrawContents(&top->top__DOT__blockade__DOT__MEM_ROM__DOT__ram, 4096, 0);
		// ImGui::End();

		video.UpdateTexture();

		// Pass inputs to sim
		top->inputs = 0;
		for (int i = 0; i < input.inputCount; i++)
		{
			if (input.inputs[i])
			{
				top->inputs |= (1 << i);
			}
		}

		// Run simulation
		if (run_enable)
		{
			for (int step = 0; step < batchSize; step++)
			{
				verilate();
			}
		}
		else
		{
			if (single_step)
			{
				verilate();
			}
			if (multi_step)
			{
				for (int step = 0; step < multi_step_amount; step++)
				{
					verilate();
				}
			}
		}
	}

	// Clean up before exit
	// --------------------

	video.CleanUp();
	input.CleanUp();

	return 0;
}
