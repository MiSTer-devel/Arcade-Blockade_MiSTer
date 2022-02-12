#include <verilated.h>
#include "Vemu.h"

#include "imgui.h"
#include "implot.h"
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
#include "sim_audio.h"
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
int batchSize = 25000000 / 100;
bool single_step = 0;
bool multi_step = 0;
int multi_step_amount = 1024;

//#define IS_BLOCKADE
//#define IS_COMOTION
#define IS_HUSTLE


// Debug GUI 
// ---------
const char* windowTitle = "Verilator Sim: Sega/Gremlin - Blockade";
const char* windowTitle_Control = "Simulation control";
const char* windowTitle_DebugLog = "Debug log";
const char* windowTitle_Video = "VGA output";
const char* windowTitle_Audio = "Audio output";
bool showDebugLog = true;
DebugConsole console;
MemoryEditor mem_edit;

// HPS emulator
// ------------
SimBus bus(console);

// Input handling
// --------------
SimInput input(11, console);

const int input_p1_right = 0;
const int input_p1_left = 1;
const int input_p1_down = 2;
const int input_p1_up = 3;

const int input_p2_right = 4;
const int input_p2_left = 5;
const int input_p2_down = 6;
const int input_p2_up = 7;

const int input_coin = 8;
const int input_start1 = 9;
const int input_start2 = 10;

// Video
// -----
#define VGA_WIDTH 256
#define VGA_HEIGHT 224
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

int clk_sys_freq = 20000000;
SimClock clk_sys(1);

void resetSim()
{
	main_time = 0;
	top->reset = 1;
	clk_sys.Reset();
}


// Audio
// -----
//#define DISABLE_AUDIO
#ifndef DISABLE_AUDIO
SimAudio audio(clk_sys_freq, true);
#endif

#ifdef IS_BLOCKADE
std::string tracefilename = "blockade.tr";
int game_mode = 0;
#endif
#ifdef IS_COMOTION 
std::string tracefilename = "comotion.tr";
int game_mode = 1;
#endif
#ifdef IS_HUSTLE
std::string tracefilename = "hustle.tr";
int game_mode = 2;
#endif

// MAME debug log
//#define CPU_DEBUG

#ifdef CPU_DEBUG
bool log_instructions = false;
bool stop_on_log_mismatch = false;


std::vector<std::string> log_mame;
std::vector<std::string> log_cpu;
long log_index;
unsigned int ins_count = 0;

// CPU debug
bool cpu_sync;
bool cpu_sync_last;
std::vector<std::vector<std::string> > opcodes;
std::map<std::string, std::string> opcode_lookup;

bool writeLog(const char* line)
{
	// Write to cpu log
	log_cpu.push_back(line);

	// Compare with MAME log
	bool match = true;
	ins_count++;

	std::string c_line = std::string(line);

	std::string c = "%d > " + c_line;

	if (log_index < log_mame.size()) {
		std::string m_line = log_mame.at(log_index);
		//std::string f = fmt::format("{0}: hcnt={1} vcnt={2} {3} {4}", log_index, top->top__DOT__missile__DOT__sc__DOT__hcnt, top->top__DOT__missile__DOT__sc__DOT__vcnt, m, c);
		//console.AddLog(f.c_str());
		if (log_instructions) { 
			console.AddLog(c.c_str(), ins_count); 
		}

		if (stop_on_log_mismatch && m_line != c_line) {
			console.AddLog("DIFF at %d", log_index);
			std::string m = "MAME > " + m_line;
			console.AddLog(m.c_str());
			console.AddLog(c.c_str(), ins_count);
			match = false;
			run_enable = 0;
		}
	}
	else {
		console.AddLog("MAME OUT");
		run_enable = 0;
	}

	log_index++;
	return match;

}

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

bool hasEnding(std::string const& fullString, std::string const& ending) {
	if (fullString.length() >= ending.length()) {
		return (0 == fullString.compare(fullString.length() - ending.length(), ending.length(), ending));
	}
	else {
		return false;
	}
}

std::string last_log;

unsigned short active_pc;
unsigned short last_pc;

bool new_ins_last;

const int ins_size = 48;
int ins_index = 0;
int ins_pc[ins_size];
int ins_in[ins_size];
int ins_ma[ins_size];
unsigned char active_ins = 0;

bool vbl_last;

#endif

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

		// Set system clock in core
		top->clk_sys = clk_sys.clk;

		// Simulate both edges of system clock
		if (clk_sys.clk != clk_sys.old) {
			if (clk_sys.clk) {
				input.BeforeEval();
				bus.BeforeEval();
			}
			top->eval();
			if (clk_sys.clk) { bus.AfterEval(); }

#ifdef CPU_DEBUG
			if (!top->reset) {
				cpu_sync = top->emu__DOT__blockade__DOT__SYNC;

				unsigned short pc = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__r16_pc;
				unsigned char di = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__di;
				unsigned short ad = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__a;
				unsigned char i = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__i;

				bool pin_f1 = top->emu__DOT__blockade__DOT__cpu__DOT__f1_core;
				bool pin_f2 = top->emu__DOT__blockade__DOT__cpu__DOT__f2_core;
				bool pin_m1 = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__m1;
				bool pin_t3 = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__t3;

				if (pc != last_pc) {
					//console.AddLog("%08d PC> PC=%04x I=%02x AD=%04x DI=%02x  PC0=%04x sync=%x f1=%x f2=%x", main_time, pc, i, ad, di, ins_pc[0], cpu_sync, pin_f1, pin_f2);
				}
				last_pc = pc;

				bool new_ins = !pin_f2 && pin_f1 && (pin_m1 && pin_t3);
				if (new_ins && !new_ins_last) {

					if (active_ins != 0)
					{
						unsigned char skip = (ins_count == 0) ? 2 : 1;
						unsigned char data1 = ins_in[skip];
						unsigned char data2 = ins_in[skip + 1];

						std::string fmt = "%04X: ";
						std::string opcode = get_opcode(active_ins);
						if (hasEnding(opcode, "d16") || hasEnding(opcode, "adr")) {
							opcode.resize(opcode.length() - 3);
							char buf[6];
							sprintf(buf, "$%02x%02x", data2, data1);
							opcode.append(buf);
						}
						if (hasEnding(opcode, "d8")) {
							opcode.resize(opcode.length() - 2);
							char buf[6];
							sprintf(buf, "$%02x", data1);
							opcode.append(buf);
						}
						fmt.append(opcode);

						unsigned short acc = top->emu__DOT__blockade__DOT__cpu__DOT__core__DOT__acc;
						char buf[1024];
						sprintf(buf, fmt.c_str(), active_pc);
						writeLog(buf);
						// Clear instruction cache
						ins_index = 0;
						for (int i = 0; i < ins_size; i++) {
							ins_in[i] = 0;
							ins_ma[i] = 0;
						}
					}
					active_ins = i;
					active_pc = ad;
				}
				new_ins_last = new_ins;

				if (cpu_sync && !cpu_sync_last) {
					//console.AddLog("%08d SC> PC=%04x I=%02x AD=%04x DI=%02x   PC0=%04x", main_time, pc, i, ad, di, ins_pc[0]);
					ins_pc[ins_index] = pc;
					ins_in[ins_index] = di;
					ins_ma[ins_index] = ad;
					ins_index++;
					if (ins_index > ins_size - 1) { ins_index = 0; }
				}


				cpu_sync_last = cpu_sync;
			}
#endif

		}

#ifndef DISABLE_AUDIO
		if (clk_sys.IsRising())
		{
			audio.Clock(top->AUDIO_L, top->AUDIO_R);
		}
#endif

		// Output pixels on rising edge of pixel clock
		if (clk_sys.IsRising() && top->emu__DOT__ce_pix) {
			uint32_t colour = 0xFF000000 | top->VGA_B << 16 | top->VGA_G << 8 | top->VGA_R;
			video.Clock(top->VGA_HB, top->VGA_VB, top->VGA_HS, top->VGA_VS, colour);
		}

		if (clk_sys.IsRising()) {
			main_time++;
		}
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

#ifdef CPU_DEBUG
	// Load debug opcodes
	loadOpcodes();

	// Load debug trace
	std::string line;
	std::ifstream fin(tracefilename);
	while (getline(fin, line)) {
		log_mame.push_back(line);
	}
#endif

	// Attach bus
	bus.ioctl_addr = &top->ioctl_addr;
	bus.ioctl_index = &top->ioctl_index;
	bus.ioctl_wait = &top->ioctl_wait;
	bus.ioctl_download = &top->ioctl_download;
	//bus.ioctl_upload = &top->ioctl_upload;
	bus.ioctl_wr = &top->ioctl_wr;
	bus.ioctl_dout = &top->ioctl_dout;
	//bus.ioctl_din = &top->ioctl_din;
	//input.ps2_key = &top->ps2_key;

#ifndef DISABLE_AUDIO
	audio.Initialise();
#endif

	// Set up input module
	input.Initialise();
#ifdef WIN32
	input.SetMapping(input_p1_up, DIK_UP);
	input.SetMapping(input_p1_right, DIK_RIGHT);
	input.SetMapping(input_p1_down, DIK_DOWN);
	input.SetMapping(input_p1_left, DIK_LEFT);
	input.SetMapping(input_p2_up, DIK_W);
	input.SetMapping(input_p2_right, DIK_D);
	input.SetMapping(input_p2_down, DIK_S);
	input.SetMapping(input_p2_left, DIK_A);
	input.SetMapping(input_coin, DIK_5);
	input.SetMapping(input_start1, DIK_1);
	input.SetMapping(input_start2, DIK_2);
#else
	input.SetMapping(input_p1_up, SDL_SCANCODE_UP);
	input.SetMapping(input_p1_right, SDL_SCANCODE_RIGHT);
	input.SetMapping(input_p1_down, SDL_SCANCODE_DOWN);
	input.SetMapping(input_p1_left, SDL_SCANCODE_LEFT);
	input.SetMapping(input_p2_up, SDL_SCANCODE_W);
	input.SetMapping(input_p2_right, SDL_SCANCODE_D);
	input.SetMapping(input_p2_down, SDL_SCANCODE_S);
	input.SetMapping(input_p2_left, SDL_SCANCODE_A);
	input.SetMapping(input_coin, SDL_SCANCODE_5);
	input.SetMapping(input_start1, SDL_SCANCODE_1);
	input.SetMapping(input_start2, SDL_SCANCODE_2);

#endif

	// Stage ROMs

#ifdef IS_BLOCKADE
	bus.QueueDownload("roms/blockade/316-0004.u2", 0);
	bus.QueueDownload("roms/blockade/316-0003.u3", 0);
	bus.QueueDownload("roms/blockade/316-0004.u2", 0); // Repeat Blockade ROMs for padding
	bus.QueueDownload("roms/blockade/316-0003.u3", 0); // Repeat Blockade ROMs for padding
	bus.QueueDownload("roms/blockade/316-0002.u29", 0);
	bus.QueueDownload("roms/blockade/316-0002.u29", 0); // Repeat PROMs for padding (256 bytes only)
	bus.QueueDownload("roms/blockade/316-0001.u43", 0);
	bus.QueueDownload("roms/blockade/316-0001.u43", 0); // Repeat PROMs for padding (256 bytes only)
#endif

#ifdef IS_COMOTION
	bus.QueueDownload("roms/comotion/316-07.u2", 0);
	bus.QueueDownload("roms/comotion/316-08.u3", 0);
	bus.QueueDownload("roms/comotion/316-09.u4", 0); // Repeat Blockade ROMs for padding
	bus.QueueDownload("roms/comotion/316-10.u5", 0); // Repeat Blockade ROMs for padding
	bus.QueueDownload("roms/comotion/316-06.u43", 0);
	bus.QueueDownload("roms/comotion/316-06.u43", 0); // Repeat PROMs for padding (256 bytes only)
	bus.QueueDownload("roms/comotion/316-05.u29", 0);
	bus.QueueDownload("roms/comotion/316-05.u29", 0); // Repeat PROMs for padding (256 bytes only)
#endif

#ifdef IS_HUSTLE
	bus.QueueDownload("roms/hustle/3160016.u2", 0);
	bus.QueueDownload("roms/hustle/3160017.u3", 0);
	bus.QueueDownload("roms/hustle/3160018.u4", 0); // Repeat Blockade ROMs for padding
	bus.QueueDownload("roms/hustle/3160019.u5", 0); // Repeat Blockade ROMs for padding
	bus.QueueDownload("roms/hustle/3160020.u29", 0);
	bus.QueueDownload("roms/hustle/3160021.u43", 0);
#endif

	// Set game mode
	top->emu__DOT__game_mode = game_mode;
	

	// Setup video output
	if (video.Initialise(windowTitle) == 1) { return 1; }

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

#ifdef CPU_DEBUG
		ImGui::NewLine();
		ImGui::Checkbox("Log CPU instructions", &log_instructions);
		ImGui::Checkbox("Stop on MAME diff", &stop_on_log_mismatch);
#endif

		ImGui::End();

		// Debug log window
		console.Draw(windowTitle_DebugLog, &showDebugLog, ImVec2(500, 700));
		ImGui::SetWindowPos(windowTitle_DebugLog, ImVec2(0, 160), ImGuiCond_Once);

		// Memory debug
		ImGui::Begin("ROM1 MSB");
		mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom1_msb__DOT__mem, 1024, 0);
		ImGui::End();
		ImGui::Begin("ROM1 LSB");
		mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom1_lsb__DOT__mem, 1024, 0);
		ImGui::End();
		ImGui::Begin("ROM2 MSB");
		mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom2_msb__DOT__mem, 1024, 0);
		ImGui::End();
		ImGui::Begin("ROM2 LSB");
		mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__rom2_lsb__DOT__mem, 1024, 0);
		ImGui::End();

		//ImGui::Begin("PROM MSB");
		//mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__prom_msb__DOT__mem, 256, 0);
		//ImGui::End();
		//ImGui::Begin("PROM LSB");
		//mem_edit.DrawContents(&top->emu__DOT__blockade__DOT__prom_lsb__DOT__mem, 256, 0);
		//ImGui::End();
		int windowX = 550;
		int windowWidth = (VGA_WIDTH * VGA_SCALE_X) + 24;
		int windowHeight = (VGA_HEIGHT * VGA_SCALE_Y) + 90;

		// Video window
		ImGui::Begin(windowTitle_Video);
		ImGui::SetWindowPos(windowTitle_Video, ImVec2(windowX, 0), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Video, ImVec2(windowWidth, windowHeight), ImGuiCond_Once);

		ImGui::SliderFloat("Zoom", &vga_scale, 1, 8); ImGui::SameLine();
		ImGui::SliderInt("Rotate", &video.output_rotate, -1, 1); ImGui::SameLine();
		ImGui::Checkbox("Flip V", &video.output_vflip);
		ImGui::Text("main_time: %d frame_count: %d sim FPS: %f", main_time, video.count_frame, video.stats_fps);

		// Draw VGA output
		ImGui::Image(video.texture_id, ImVec2(video.output_width * VGA_SCALE_X, video.output_height * VGA_SCALE_Y));
		ImGui::End();


#ifndef DISABLE_AUDIO

		ImGui::Begin(windowTitle_Audio);
		ImGui::SetWindowPos(windowTitle_Audio, ImVec2(windowX, windowHeight), ImGuiCond_Once);
		ImGui::SetWindowSize(windowTitle_Audio, ImVec2(windowWidth, 250), ImGuiCond_Once);

		
		//float vol_l = ((signed short)(top->AUDIO_L) / 256.0f) / 256.0f;
		//float vol_r = ((signed short)(top->AUDIO_R) / 256.0f) / 256.0f;
		//ImGui::ProgressBar(vol_l + 0.5f, ImVec2(200, 16), 0); ImGui::SameLine();
		//ImGui::ProgressBar(vol_r + 0.5f, ImVec2(200, 16), 0);

		int ticksPerSec = (24000000 / 60);
		if (run_enable) {
			audio.CollectDebug((signed short)top->AUDIO_L, (signed short)top->AUDIO_R);
		}
		int channelWidth = (windowWidth / 2)  -16;
		ImPlot::CreateContext();
		if (ImPlot::BeginPlot("Audio - L", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_l, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImGui::SameLine();
		if (ImPlot::BeginPlot("Audio - R", ImVec2(channelWidth, 220), ImPlotFlags_NoLegend | ImPlotFlags_NoMenus | ImPlotFlags_NoTitle)) {
			ImPlot::SetupAxes("T", "A", ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks, ImPlotAxisFlags_AutoFit | ImPlotAxisFlags_NoLabel | ImPlotAxisFlags_NoTickMarks);
			ImPlot::SetupAxesLimits(0, 1, -1, 1, ImPlotCond_Once);
			ImPlot::PlotStairs("", audio.debug_positions, audio.debug_wave_r, audio.debug_max_samples, audio.debug_pos);
			ImPlot::EndPlot();
		}
		ImPlot::DestroyContext();
		ImGui::End();
#endif

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
		if (run_enable) {
			for (int step = 0; step < batchSize; step++) { verilate(); }
		}
		else {
			if (single_step) { verilate(); }
			if (multi_step) {
				for (int step = 0; step < multi_step_amount; step++) { verilate(); }
			}
		}
	}

	// Clean up before exit
	// --------------------

	audio.CleanUp();
	video.CleanUp();
	input.CleanUp();

	return 0;
}
