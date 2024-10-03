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
 *  Description: Randomizer test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module randomizer_tb;
/*============================================================================*/

localparam NR_CHANNELS_1 = 1;
localparam NR_CHANNELS_1_WIDTH = 1;
localparam OUTPUT_WIDTH_1 = 16;

reg clk = 0;
reg rst_n = 0;

reg  [NR_CHANNELS_1_WIDTH-1:0] rndm_1_ch = 0;
reg  rndm_1_ready = 0;
reg  [OUTPUT_WIDTH_1-1:0] rndm_1_seed = 16'hFFFF;
wire [OUTPUT_WIDTH_1-1:0] rndm_1_out;

randomizer rndm_1(
    .clk(clk),
    .rndm_ch(rndm_1_ch),
    .rndm_seed(rndm_1_seed),
    .rndm_init(~rst_n),
    .rndm_out(rndm_1_out),
    .rndm_ready(rndm_1_ready)
    );

defparam rndm_1.NR_CHANNELS = NR_CHANNELS_1;
defparam rndm_1.OUTPUT_WIDTH = OUTPUT_WIDTH_1;

localparam NR_CHANNELS_2 = 3;
localparam NR_CHANNELS_2_WIDTH = $clog2( NR_CHANNELS_2 );
localparam OUTPUT_WIDTH_2 = 24;

reg  [NR_CHANNELS_2_WIDTH-1:0] rndm_2_ch = 0;
reg  [NR_CHANNELS_2_WIDTH-1:0] rndm_2_ch_i = 0;
reg  rndm_2_ready = 0;
reg  [OUTPUT_WIDTH_2-1:0] rndm_2_seed = 0;
wire [OUTPUT_WIDTH_2-1:0] rndm_2_out;
reg  [OUTPUT_WIDTH_1-1:0] rndm_2_out_1;
reg  [OUTPUT_WIDTH_1-1:0] rndm_2_out_2;
reg  [OUTPUT_WIDTH_1-1:0] rndm_2_out_3;

randomizer rndm_2(
    .clk(clk),
    .rndm_ch(rndm_2_ch),
    .rndm_seed(rndm_2_seed),
    .rndm_init(~rst_n),
    .rndm_out(rndm_2_out),
    .rndm_ready(rndm_2_ready)
    );

defparam rndm_2.NR_CHANNELS = NR_CHANNELS_2;
defparam rndm_2.OUTPUT_WIDTH = OUTPUT_WIDTH_2;

always #10 clk = ~clk; // 50 MHz clock

/*============================================================================*/
always @(posedge clk) begin : alternate_channels
/*============================================================================*/
    if ( rndm_2_ready ) begin
        case ( rndm_2_ch )
            0 : rndm_2_ch <= 1;
            1 : rndm_2_ch <= 2;
            2 : rndm_2_ch <= 0;
        endcase
    end
end // alternate_channels

/*============================================================================*/
always @(posedge clk) begin : collect_data
/*============================================================================*/
    rndm_2_ch_i <= rndm_2_ch;
    case ( rndm_2_ch_i ) // Channel random_out is valid one clock cycle later!
        0 : rndm_2_out_1 <= rndm_2_out;
        1 : rndm_2_out_2 <= rndm_2_out;
        2 : rndm_2_out_3 <= rndm_2_out;
    endcase
end // collect_data

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    rndm_1_ready = 0;
    rndm_2_ready = 0;
    #10
    wait ( clk ) @( negedge clk )
    rndm_2_ch = 0;
    rndm_2_seed = 24'h040000;
    wait ( clk ) @( negedge clk )
    rndm_2_ch = 1;
    rndm_2_seed = 24'h000400;
    wait ( clk ) @( negedge clk )
    rndm_2_ch = 2;
    rndm_2_seed = 24'h000004;
    wait ( clk ) @( negedge clk )
    #100
    rndm_2_ch = 0;
    rst_n = 1;
    rndm_1_ready = 1;
    rndm_2_ready = 1;
    $display( "Randomizer simulation started" );
    #10000 // 10us
    rndm_1_ready = 0;
    rndm_2_ready = 0;
    #500
    rndm_1_ready = 1;
    rndm_2_ready = 1;
    #10000 // 10us
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "randomizer_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // randomizer_tb
