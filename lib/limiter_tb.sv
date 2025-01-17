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
 *  Description: Limiter test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module limiter_tb;
/*============================================================================*/

reg clk = 0;
reg rst_n = 0;

localparam NR_CHANNELS = 3;
localparam INPUT_WIDTH = 30;
localparam OUTPUT_WIDTH = 24;
localparam CHW = $clog2( NR_CHANNELS );
localparam INW = INPUT_WIDTH;
localparam OUTW = OUTPUT_WIDTH;
localparam MAX_ATTACK_SHIFT = 10;
localparam ATTACK_SHIFT_WIDTH = $clog2( MAX_ATTACK_SHIFT );
localparam MAX_RELEASE_SHIFT = 10;
localparam RELEASE_SHIFT_WIDTH = $clog2( MAX_RELEASE_SHIFT );
localparam MAX_AVG_SHIFT = 3;
localparam AVG_SHIFT_WIDTH = $clog2( MAX_AVG_SHIFT );

wire [INW-1:0] signal_d;
wire [CHW-1:0] signal_ch;
wire signal_dv;
wire signal_dr;
reg  [ATTACK_SHIFT_WIDTH-1:0] attack_shift = 0;
reg  [RELEASE_SHIFT_WIDTH-1:0] release_shift = 0;
reg  [AVG_SHIFT_WIDTH-1:0] avg_shift = 0;
wire [OUTW-1:0] lim1_d;
wire [CHW-1:0] lim1_ch;
wire lim1_dv;

limiter #(
    .NR_CHANNELS( NR_CHANNELS ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .OUTPUT_WIDTH( OUTPUT_WIDTH ),
    .ATTENUATION( 0 ))
lim1 (
    .clk(clk),
    .rst_n(rst_n),
    .signal_d(signal_d),
    .signal_ch(signal_ch),
    .signal_dv(signal_dv),
    .signal_dr(),
    .attack_shift(),
    .release_shift(),
    .avg_shift(),
    .lim_d(lim1_d),
    .lim_ch(lim1_ch),
    .lim_dv(lim1_dv)
    );

wire [OUTW-1:0] lim2_d;
wire [CHW-1:0] lim2_ch;
wire lim2_dv;

limiter #(
    .NR_CHANNELS( NR_CHANNELS ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .OUTPUT_WIDTH( OUTPUT_WIDTH ),
    .ATTENUATION( 1 ),
    .MAX_ATTACK_SHIFT( MAX_ATTACK_SHIFT ),
    .MAX_RELEASE_SHIFT( MAX_RELEASE_SHIFT ),
    .MAX_AVG_SHIFT( MAX_AVG_SHIFT ))
lim2 (
    .clk(clk),
    .rst_n(rst_n),
    .signal_d(signal_d),
    .signal_ch(signal_ch),
    .signal_dv(signal_dv),
    .signal_dr(signal_dr),
    .attack_shift(attack_shift),
    .release_shift(release_shift),
    .avg_shift(avg_shift),
    .lim_d(lim2_d),
    .lim_ch(lim2_ch),
    .lim_dv(lim2_dv)
    );

reg signed [INW-1:0] signal_in_0 = 0;
reg signal_in_0_dv = 0;
wire [OUTW-1:0] lim3_d;
wire lim3_dv;

limiter #(
    .NR_CHANNELS( 1 ), //Single channel!
    .INPUT_WIDTH( INPUT_WIDTH ),
    .OUTPUT_WIDTH( OUTPUT_WIDTH ),
    .ATTENUATION( 0 ))
lim3 (
    .clk(clk),
    .rst_n(rst_n),
    .signal_d(signal_in_0),
    .signal_ch(1'b0),
    .signal_dv(signal_in_0_dv),
    .signal_dr(),
    .attack_shift(),
    .release_shift(),
    .avg_shift(),
    .lim_d(lim3_d),
    .lim_ch(),
    .lim_dv(lim3_dv)
    );

wire [OUTW-1:0] lim4_d;
wire lim4_dv;

limiter #(
    .NR_CHANNELS( 1 ), //Single channel!
    .INPUT_WIDTH( INPUT_WIDTH ),
    .OUTPUT_WIDTH( OUTPUT_WIDTH ),
    .ATTENUATION( 1 ),
    .MAX_ATTACK_SHIFT( MAX_ATTACK_SHIFT ),
    .MAX_RELEASE_SHIFT( MAX_RELEASE_SHIFT ),
    .MAX_AVG_SHIFT( MAX_AVG_SHIFT ))
lim4 (
    .clk(clk),
    .rst_n(rst_n),
    .signal_d(signal_in_0),
    .signal_ch(1'b0),
    .signal_dv(signal_in_0_dv),
    .signal_dr(),
    .attack_shift(attack_shift),
    .release_shift(release_shift),
    .avg_shift(avg_shift),
    .lim_d(lim4_d),
    .lim_ch(),
    .lim_dv(lim4_dv)
    );

always #5 clk = ~clk; // 100 MHz clock

reg sg_enabled = 0; // Sine generator
reg [3:0] sg_shift = 0;
reg mute = 0;

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    sg_enabled = 0;
    attack_shift = 6;
    release_shift = 7;
    avg_shift = 1;
    sg_shift = 7;
    mute = 0;
    #100 // 0.1us
    $display( "Limiter simulation started" );
    rst_n = 1;
    sg_enabled = 1;
    #5000 // 5us
    sg_shift = 6;
    #5000 // 5us
    sg_shift = 5;
    #5000 // 5us
    sg_shift = 4;
    #5000 // 5us
    sg_shift = 3;
    #5000 // 5us
    sg_shift = 2;
    #5000 // 5us
    sg_shift = 1;
    #5000 // 5us
    sg_shift = 0;
    $display( "Unmute, attack_shift = %0d, release_shift = %0d, avg_shift = %0d", attack_shift, release_shift, avg_shift );
    #200000 // 200us
    mute = 1;
    $display( "Mute" );
    #20000 // 20us
    mute = 0;
    avg_shift = 2;
    $display( "Unmute, avg_shift = %0d", avg_shift );
    #200000 // 200us
    mute = 1;
    $display( "Mute" );
    #20000 // 20us
    mute = 0;
    avg_shift = 3;
    $display( "Unmute, avg_shift = %0d", avg_shift );
    #200000 // 200us
    mute = 1;
    $display( "Mute" );
    #20000 // 20us
    mute = 0;
    attack_shift = 8;
    release_shift = 9;
    avg_shift = 1;
    $display( "Unmute, attack_shift = %0d, release_shift = %0d, avg_shift = %0d", attack_shift, release_shift, avg_shift );
    #200000 // 200us
    mute = 1;
    $display( "Mute" );
    #20000 // 20us
    mute = 0;
    avg_shift = 2;
    $display( "Unmute, avg_shift = %0d", avg_shift );
    #200000 // 200us
    mute = 1;
    $display( "Mute" );
    #20000 // 20us
    mute = 0;
    avg_shift = 3;
    $display( "Unmute, avg_shift = %0d", avg_shift );
    #200000 // 200us
    $finish;
end

reg signed [INW-1:0] signal_in_1 = 0;
reg signed [INW-1:0] signal_in_2 = 0;
reg signed [OUTW-1:0] lim_out_0 = 0;
reg signed [OUTW-1:0] lim_out_1 = 0;
reg signed [OUTW-1:0] lim_out_2 = 0;
reg signed [OUTW-1:0] lim_out_3 = 0;
reg signed [OUTW-1:0] lim_out_4 = 0;
reg signed [OUTW-1:0] lim_out_5 = 0;
reg signed [OUTW-1:0] lim_out_6 = 0;
reg signed [OUTW-1:0] lim_out_7 = 0;

/*============================================================================*/
always @(posedge clk) begin : collect_data
/*============================================================================*/
    signal_in_0_dv <= 0;
    if ( signal_dv ) begin
        case ( signal_ch )
        0 : begin
            signal_in_0 <= signal_d;
            signal_in_0_dv <= 1;
        end
        1 : begin
            signal_in_1 <= signal_d;
        end
        2 : begin
            signal_in_2 <= signal_d;
        end
        endcase
    end
    if ( lim1_dv ) begin
        case ( lim1_ch )
        0 : begin
            lim_out_0 <= lim1_d;
        end
        1 : begin
            lim_out_1 <= lim1_d;
        end
        2 : begin
            lim_out_2 <= lim1_d;
        end
        endcase
    end
    if ( lim2_dv ) begin
        case ( lim2_ch )
        0 : begin
            lim_out_3 <= lim2_d;
        end
        1 : begin
            lim_out_4 <= lim2_d;
        end
        2 : begin
            lim_out_5 <= lim2_d;
        end
        endcase
    end
    if ( lim3_dv ) begin
        lim_out_6 <= lim3_d;
    end
    if ( lim4_dv ) begin
        lim_out_7 <= lim4_d;
    end
end

/////////////////// Sine generator for NR_CHANNELS channels ////////////////////
reg signed [INPUT_WIDTH-1:0] sg_d = 0;
reg [CHW-1:0] sg_ch = 0;
reg sg_dv = 0;

localparam real MATH_2_PI = 2 * 3.14159265358979323846;
localparam integer SAMPLE_FREQUENCY = 48000;
localparam real FACTOR_1 = ( 2.0 ** ( INPUT_WIDTH - 1 )) - 1;
real step[NR_CHANNELS-1:0];
real sine_counter[NR_CHANNELS-1:0];
/*============================================================================*/
initial begin
/*============================================================================*/
    step[0] = MATH_2_PI * 1010 / SAMPLE_FREQUENCY;
    step[1] = MATH_2_PI * 4040 / SAMPLE_FREQUENCY;
    step[2] = MATH_2_PI * 16100 / SAMPLE_FREQUENCY;
    sine_counter[0] = 0;
    sine_counter[1] = 0;
    sine_counter[2] = 0;
end

/*============================================================================*/
always @(posedge clk) begin : sine_generator
/*============================================================================*/
    sg_dv <= 0;
    if ( sg_enabled ) begin
        if ( !sg_dv ) begin
            if ( signal_dr ) begin
                sg_d <= FACTOR_1 * $sin( sine_counter[sg_ch] );
                sine_counter[sg_ch] <= sine_counter[sg_ch] + step[sg_ch];
                sg_dv <= 1;
            end else begin
                if (( NR_CHANNELS - 1 ) == sg_ch ) begin
                    sg_ch <= 0;
                end else begin
                    sg_ch <= sg_ch + 1;
                end
            end
        end
    end
    if ( !rst_n || !sg_enabled ) begin
        sine_counter[0] <= 0;
        sine_counter[1] <= 0;
        sine_counter[2] <= 0;
        sg_d <= 0;
        sg_dv <= 0;
        sg_ch <= 0;
    end
end // sine_generator

assign signal_d = $signed( sg_d & { ( INPUT_WIDTH ){~mute}} ) >>> sg_shift;
assign signal_ch = sg_ch;
assign signal_dv = sg_dv;


/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "limiter_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule // limiter_tb