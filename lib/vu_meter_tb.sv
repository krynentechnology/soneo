/**
 *  Copyright (C) 2024, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation, either version 3 of the License, or (at your option)
 *  any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <https://www.gnu.org/licenses/> for a copy.
 *
 *  License: GPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/gpl-3.0.html
 *
 *  Description: VU meter test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module vu_meter_tb;
/*============================================================================*/

localparam NR_CHANNELS = 3;
localparam SYNC_RESET = 6;
localparam MAX_LEVEL = 5;
localparam INPUT_WIDTH = 24;
localparam CHW = ( NR_CHANNELS < 2 ) ? 1 : $clog2( NR_CHANNELS );

reg clk = 0;
reg mute = 0;

wire [INPUT_WIDTH-1:0] vm_signal_d;
wire [CHW-1:0] vm_signal_ch;
wire vm_signal_dv;
reg  vm_sync = 0;
wire [NR_CHANNELS-1:0] vm_level_d; // VU meter level bit array output

vu_meter vm(
    .clk(clk),
    .vm_signal_d(vm_signal_d),
    .vm_signal_ch(vm_signal_ch),
    .vm_signal_dv(vm_signal_dv),
    .vm_sync(vm_sync),
    .vm_level_d(vm_level_d)
    );

defparam vm.NR_CHANNELS = NR_CHANNELS;
defparam vm.SYNC_RESET = SYNC_RESET;
defparam vm.MAX_LEVEL = MAX_LEVEL;
defparam vm.INPUT_WIDTH = INPUT_WIDTH;

reg  swg_enabled = 0;
wire led0;
assign led0 = vm_level_d[0];
wire led1;
assign led1 = vm_level_d[1];
wire led2;
assign led2 = vm_level_d[2];

always #5 clk = ~clk; // 100 MHz clock

/*============================================================================*/
initial begin
/*============================================================================*/
    mute = 0;
    vm_sync = 0;
    #100
    $display( "VU meter simulation started" );
    swg_enabled = 1;
    #10000 // 10us
    mute = 1;
    #2000  // 1us
    mute = 0;
    #30000 // 10us
    $display( "Simulation finished" );
    $finish;
end

/////////////////////////////// Sweep generator ////////////////////////////////
localparam real MATH_2_PI = 2 * 3.14159265358979323846;
localparam real FACTOR_1 = ( 2.0 ** ( INPUT_WIDTH - 1 )) - 1;
localparam real EXPONENTIAL = 0.99;
localparam real F_START = 10.0;
localparam real F_END = 24000.0;
localparam real F_INTERVAL = 0.5;
localparam NR_STEPS = 5000;

real swg_amplitude = 0.5;
real swg_delta = 0;
real swg_t = 0;
real swg_phase = 0;
reg [$clog2( NR_STEPS )-1:0] swg_step = 0;
reg signed [INPUT_WIDTH-1:0] swg_d = 0;
reg signed [INPUT_WIDTH-1:0] swg_d_c;
reg [CHW-1:0] swg_ch = 0;
reg swg_dv = 0;
integer vm_sync_count = 0;

/*============================================================================*/
always @(posedge clk) begin : sweep_generator
/*============================================================================*/
    swg_dv <= 0;
    vm_sync <= 0;
    if ( swg_enabled && !swg_dv ) begin
        if ( swg_step < NR_STEPS ) begin
            swg_delta = swg_step / $itor( NR_STEPS );
            swg_t = F_INTERVAL * swg_delta;
            swg_phase = MATH_2_PI * swg_t * ( F_START + (( F_END - F_START ) * swg_delta / 2 ));
            swg_d_c = FACTOR_1 * swg_amplitude * $sin( swg_phase );
            swg_d <= swg_d_c;
            swg_dv <= 1;
            swg_step <= swg_step + 1;
            swg_ch <= swg_ch + 1;
            if (( NR_CHANNELS - 1 ) == swg_ch ) begin
                swg_ch <= 0;
                vm_sync_count <= vm_sync_count + 1;
                if (( NR_CHANNELS-1 ) == vm_sync_count ) begin
                    vm_sync <= 1;
                    vm_sync_count <= 0;
                end
                swg_amplitude <= swg_amplitude * EXPONENTIAL;
            end
        end
    end
end // sweep_generator

assign vm_signal_d = swg_d & {( INPUT_WIDTH ){~mute}};
assign vm_signal_ch = swg_ch;
assign vm_signal_dv = swg_dv;

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "vu_meter_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // vu_meter_tb
