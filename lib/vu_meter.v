/**
 *  Copyright (C) 2024, Kees Krijnen.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU Lesser General Public License as published by the
 *  Free Software Foundation, either version 3 of the License, or (at your
 *  option) any later version.
 *
 *  This program is distributed WITHOUT ANY WARRANTY; without even the implied
 *  warranty of MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program. If not, see <https://www.gnu.org/licenses/> for a
 *  copy.
 *
 *  License: LGPL, v3, as defined and found on www.gnu.org,
 *           https://www.gnu.org/licenses/lgpl-3.0.html
 *
 *  Description: VU meter. For every channel a LED lights up and blinks to
 *               indicate the channel signal level. The output is a LED
 *               bit array, matching the number of channels.
 *
 *  The LED activity is affected by the number of levels, the level signal range
 *  and the ratio between the actual level and the sync reset count.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module vu_meter #(
/*============================================================================*/
    parameter NR_CHANNELS = 4,
    parameter SYNC_RESET = 4,
    parameter MAX_LEVEL = 5, // 0, 1, .., MAX_LEVEL-1
    parameter INPUT_WIDTH = 24 )
    (
    clk,
    vm_signal_d,
    vm_signal_ch,
    vm_signal_dv,
    vm_sync,
    vm_level_d
    );

localparam MAX_CLOG2_WIDTH = 8;
/*============================================================================*/
function integer clog2( input [MAX_CLOG2_WIDTH-1:0] value );
/*============================================================================*/
    reg [MAX_CLOG2_WIDTH-1:0] depth;
    begin
        clog2 = 1; // Minimum bit width
        if ( value > 1 ) begin
            depth = value - 1;
            clog2 = 0;
            while ( depth > 0 ) begin
                depth = depth >> 1;
                clog2 = clog2 + 1;
            end
        end
    end
endfunction // clog2

localparam CHANNEL_WIDTH = clog2( NR_CHANNELS );

input  wire clk;
input  wire [INPUT_WIDTH-1:0] vm_signal_d;
input  wire [CHANNEL_WIDTH-1:0] vm_signal_ch;
input  wire vm_signal_dv;
input  wire vm_sync;
output reg  [NR_CHANNELS-1:0] vm_level_d; // VU meter level bit array output

localparam ABS_WIDTH = 10; // Upper significant ABS_WIDTH bits determine level!

/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( SYNC_RESET < 1 ) begin
        $display( "SYNC_RESET < 1!" );
        $finish;
    end
    if ( MAX_LEVEL < 5 ) begin
        $display( "MAX_LEVEL < 5!" );
        $finish;
    end
    if ( NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )) begin
        $display( "NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )!" );
        $finish;
    end
    if ( INPUT_WIDTH < ( ABS_WIDTH + 1 )) begin
        $display( "INPUT_WIDTH < (ABS_WIDTH + 1)!" );
        $finish;
    end
end // param_check

localparam COUNT_WIDTH = clog2( SYNC_RESET );
localparam LEVEL_WIDTH = clog2( MAX_LEVEL );
localparam AW = ABS_WIDTH;

reg [COUNT_WIDTH-1:0] sync_count = 0;
reg [LEVEL_WIDTH-1:0] vm_level[0:NR_CHANNELS-1];
reg [LEVEL_WIDTH-1:0] abs_level;
reg [NR_CHANNELS-1:0] reset_level = 0;

wire [AW-1:0] signal_level;
assign signal_level = vm_signal_d[INPUT_WIDTH-1] ?
    ~vm_signal_d[INPUT_WIDTH-2:INPUT_WIDTH-AW-1] : // ABS_WIDTH nr of bits
    vm_signal_d[INPUT_WIDTH-2:INPUT_WIDTH-AW-1];

reg [CHANNEL_WIDTH:0] i = 0; // +1 width for NR_CHANNELS value!
/*============================================================================*/
initial begin
/*============================================================================*/
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        vm_level[i] = 0;
    end
    vm_level_d = 0;
end

/*============================================================================*/
always @(*) begin : set_abs_level
/*============================================================================*/
    abs_level = 0;
    if ( signal_level[AW-1] ) begin
        abs_level = MAX_LEVEL - 1;
    end else if ( signal_level[AW-2:AW-4] ) begin
        abs_level = 3;
    end else if ( signal_level[AW-5:AW-7] ) begin
        abs_level = 2;
    end else if ( signal_level[AW-8:0] ) begin
        abs_level = 1;
    end
end // set_abs_level

/*============================================================================*/
always @(posedge clk) begin : vu_meter_level
/*============================================================================*/
    if ( vm_sync ) begin
        vm_level_d <= 0;
        for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
            if ( vm_level[i] > sync_count ) begin
                vm_level_d[i] <= 1;
            end
        end
        sync_count <= sync_count + 1;
        if (( SYNC_RESET - 1 ) == sync_count ) begin
           sync_count <= 0;
           reset_level <= {(NR_CHANNELS){1'b1}};
        end
    end
    if ( vm_signal_dv && ( vm_signal_ch < NR_CHANNELS )) begin
        if (( abs_level > vm_level[vm_signal_ch] ) || ( reset_level[vm_signal_ch] )) begin
            vm_level[vm_signal_ch] <= abs_level;
            reset_level[vm_signal_ch] <= 0;
        end
    end
end // vu_meter_level

endmodule // vu_meter
