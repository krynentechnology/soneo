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

reg clk = 0;
reg rst_n = 0;

localparam NR_CHANNELS_1 = 1;
localparam NR_CHANNELS_1_WIDTH = 1;
localparam OUTPUT_WIDTH_1 = 16;

reg  [NR_CHANNELS_1_WIDTH-1:0] rndm_1_ch = 0;
reg  rndm_1_ready = 0;
reg  [OUTPUT_WIDTH_1-1:0] rndm_1_seed = 16'hFFFF;
wire [OUTPUT_WIDTH_1-1:0] rndm_1_out;

randomizer #(
    .NR_CHANNELS(NR_CHANNELS_1),
    .OUTPUT_WIDTH(OUTPUT_WIDTH_1),
    .SIGNED(0))
rndm_1(
    .clk(clk),
    .rndm_ch(rndm_1_ch),
    .rndm_seed(rndm_1_seed),
    .rndm_init(~rst_n),
    .rndm_out(rndm_1_out),
    .rndm_ready(rndm_1_ready)
    );

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

randomizer #(
    .NR_CHANNELS(NR_CHANNELS_2),
    .OUTPUT_WIDTH(OUTPUT_WIDTH_2),
    .SIGNED(0))
rndm_2(
    .clk(clk),
    .rndm_ch(rndm_2_ch),
    .rndm_seed(rndm_2_seed),
    .rndm_init(~rst_n),
    .rndm_out(rndm_2_out),
    .rndm_ready(rndm_2_ready)
    );

localparam NR_CHANNELS_3 = 1;
localparam NR_CHANNELS_3_WIDTH = 1;
localparam OUTPUT_WIDTH_3 = 8;
localparam VW_3 = ( 2 ** OUTPUT_WIDTH_3 ); // Verify width

reg  [NR_CHANNELS_3_WIDTH-1:0] rndm_3_ch = 0;
reg  rndm_3_ready = 0;
reg  [OUTPUT_WIDTH_3-1:0] rndm_3_seed = 0;
wire [OUTPUT_WIDTH_3-1:0] rndm_3_out;
reg  [VW_3-1:0] rndm_3_verify = 0;

randomizer #(
    .NR_CHANNELS(NR_CHANNELS_3),
    .OUTPUT_WIDTH(OUTPUT_WIDTH_3),
    .SIGNED(0))
rndm_3(
    .clk(clk),
    .rndm_ch(rndm_3_ch),
    .rndm_seed(rndm_3_seed),
    .rndm_init(~rst_n),
    .rndm_out(rndm_3_out),
    .rndm_ready(rndm_3_ready)
    );

localparam NR_CHANNELS_4 = 1;
localparam NR_CHANNELS_4_WIDTH = 1;
localparam OUTPUT_WIDTH_4 = 8;
localparam VW_4 = ( 2 ** OUTPUT_WIDTH_4 ); // Verify width

reg  [NR_CHANNELS_4_WIDTH-1:0] rndm_4_ch = 0;
reg  rndm_4_ready = 0;
reg  [OUTPUT_WIDTH_4-1:0] rndm_4_seed = 0;
wire [OUTPUT_WIDTH_4-1:0] rndm_4_out;
reg  [VW_4-1:0] rndm_4_verify = 0;

randomizer #(
    .NR_CHANNELS(NR_CHANNELS_3),
    .OUTPUT_WIDTH(OUTPUT_WIDTH_3),
    .SIGNED(1))
rndm_4(
    .clk(clk),
    .rndm_ch(rndm_4_ch),
    .rndm_seed(rndm_4_seed),
    .rndm_init(~rst_n),
    .rndm_out(rndm_4_out),
    .rndm_ready(rndm_4_ready)
    );

always #5 clk = ~clk; // 100 MHz clock

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

localparam VW_SPLIT_4 = ( 2 ** ( OUTPUT_WIDTH_4 - 1 )); // Signed output
integer rndm_3_count = 0;
integer rndm_4_count = 0;
/*============================================================================*/
always @(posedge clk) begin : check_output
/*============================================================================*/
    if ( rndm_1_ready ) begin // Unsigned output
        if ( 0 == rndm_1_out ) begin
            $display( "Invalid output RNDM_1 value!" );
            $finish;
        end
    end
    if ( rndm_2_ready ) begin // Unsigned output
        if ( 0 == rndm_2_out ) begin
            $display( "Invalid output RNDM_2 value!" );
            $finish;
        end
    end
    if ( rndm_3_ready ) begin // Unsigned output
        if ( 0 == rndm_3_out ) begin
            $display( "Invalid output RNDM_3 value!" );
            $finish;
        end
        rndm_3_verify[rndm_3_out] <= 1;
        rndm_3_count <= rndm_3_count + 1;
        if ( &rndm_3_verify[VW_3-1:1] ) begin
            rndm_3_count <= 0;
            rndm_3_verify <= 0;
        end;
    end
    if ( rndm_4_ready ) begin // Signed output
        if ( rndm_4_out[OUTPUT_WIDTH_4-1] && !rndm_4_out[OUTPUT_WIDTH_4-2:0] ) begin
            $display( "Invalid output RNDM_4 value!" );
            $finish;
        end
        rndm_4_verify[rndm_4_out] <= 1;
        rndm_4_count <= rndm_4_count + 1;
        if ( &rndm_4_verify[VW_4-1:VW_SPLIT_4+1] && &rndm_4_verify[VW_SPLIT_4-1:0] ) begin
            rndm_4_count <= 0;
            rndm_4_verify <= 0;
        end;
    end
end // check_output

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    rndm_1_ready = 0;
    rndm_2_ready = 0;
    rndm_3_ready = 0;
    rndm_4_ready = 0;
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
    rndm_3_ready = 1;
    rndm_4_ready = 1;
    $display( "Randomizer simulation started" );
    #500000 // 500us
    rndm_1_ready = 0;
    rndm_2_ready = 0;
    rndm_3_ready = 0;
    rndm_4_ready = 0;
    #500
    rndm_1_ready = 1;
    rndm_2_ready = 1;
    rndm_3_ready = 1;
    rndm_4_ready = 1;
    #500000 // 500us
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
