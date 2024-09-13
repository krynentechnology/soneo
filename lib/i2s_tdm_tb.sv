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
 *  Description: I2S TDM test bench
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module i2s_tdm_tb;
/*============================================================================*/

localparam NR_CHANNELS_1 = 2;
localparam NR_CHANNELS_2 = 4;
localparam NR_CHANNELS_3 = 16;
localparam INPUT_WIDTH_1 = 16;
localparam INPUT_WIDTH_2 = 24;
localparam INPUT_WIDTH_3 = 32;

localparam CHANNEL_WIDTH_1 = $clog2( NR_CHANNELS_1 );
localparam CHANNEL_WIDTH_2 = $clog2( NR_CHANNELS_2 );
localparam CHANNEL_WIDTH_3 = $clog2( NR_CHANNELS_3 );

localparam real MATH_PI = 3.141592653589793115997963;

reg clk = 0;
reg rst_n = 0;

//==============================I2S=============================================
real s_sine_d_1_0 = MATH_PI * 1/24; // 1kHz
real s_sine_d_1_1 = MATH_PI * 2/24; // 2kHz
real s_sine_d_1 = 0.0;
wire [CHANNEL_WIDTH_1-1:0] s_sine_ch_1;
wire s_sine_dv_1;
wire s_sine_dr_1;
wire [INPUT_WIDTH_1-1:0] m_sine_d_1;
wire [CHANNEL_WIDTH_1-1:0] m_sine_ch_1;
wire m_sine_dv_1;
wire m_sine_dr_1;

sine_wg swg_1(
    .clk(clk),
    .rst_n(rst_n),
    .s_sine_d(s_sine_d_1),
    .s_sine_ch(s_sine_ch_1),
    .s_sine_dv(s_sine_dv_1),
    .s_sine_dr(s_sine_dr_1),
    .m_sine_d(m_sine_d_1),
    .m_sine_ch(m_sine_ch_1),
    .m_sine_dv(m_sine_dv_1),
    .m_sine_dr(m_sine_dr_1)
    );

defparam swg_1.NR_CHANNELS = NR_CHANNELS_1;
defparam swg_1.FRACTION_1_0_WIDTH = INPUT_WIDTH_1 - 3;
defparam swg_1.OUTPUT_WIDTH = INPUT_WIDTH_1;

wire bclk_1;
wire lrclk;
wire i2s_tdm_1;

i2s_tdm_enc i2s_tdm_enc_1(
    .mclk(clk),
    .bclk(bclk_1),
    .lrclk(lrclk),
    .i2s_tdm(i2s_tdm_1),
    .i2s_tdm_ch(s_sine_ch_1),
    .i2s_tdm_chv(s_sine_dv_1),
    .i2s_tdm_chr(s_sine_dr_1),
    .i2s_tdm_d(m_sine_d_1),
    .i2s_tdm_dv(m_sine_dv_1),
    .i2s_tdm_dr(m_sine_dr_1));

defparam i2s_tdm_enc_1.NR_CHANNELS = NR_CHANNELS_1;
defparam i2s_tdm_enc_1.INPUT_WIDTH = INPUT_WIDTH_1;
defparam i2s_tdm_enc_1.LRCLK_POLARITY = 0; // I2S
defparam i2s_tdm_enc_1.LEFT_ALIGNED = 0; // I2S
defparam i2s_tdm_enc_1.MCLK_BCLK_RATIO = 64;

wire [INPUT_WIDTH_1-1:0] i2s_tdm_d_1;
wire [CHANNEL_WIDTH_1-1:0] i2s_tdm_ch_1;
wire i2s_tdm_dv_1;
reg i2s_tdm_dr_1 = 1;

i2s_tdm_dec i2s_tdm_dec_1(
    .mclk(clk),
    .bclk(bclk_1),
    .lrclk(lrclk),
    .i2s_tdm(i2s_tdm_1),
    .i2s_tdm_d(i2s_tdm_d_1),
    .i2s_tdm_ch(i2s_tdm_ch_1),
    .i2s_tdm_dv(i2s_tdm_dv_1),
    .i2s_tdm_dr(i2s_tdm_dr_1));

defparam i2s_tdm_dec_1.NR_CHANNELS = NR_CHANNELS_1;
defparam i2s_tdm_dec_1.OUTPUT_WIDTH = INPUT_WIDTH_1;
defparam i2s_tdm_dec_1.LRCLK_POLARITY = 0; // I2S
defparam i2s_tdm_dec_1.LEFT_ALIGNED = 0; // I2S
defparam i2s_tdm_dec_1.MCLK_BCLK_RATIO = 64; // I2S

//==============================TDM4============================================
real s_sine_d_2_0 = MATH_PI * 1/24; // 1kHz
real s_sine_d_2_1 = MATH_PI * 2/24; // 2kHz
real s_sine_d_2_2 = MATH_PI * 3/24; // 3kHz
real s_sine_d_2_3 = MATH_PI * 4/24; // 4kHz
real s_sine_d_2 = 0.0;
wire [CHANNEL_WIDTH_2-1:0] s_sine_ch_2;
wire s_sine_dv_2;
wire s_sine_dr_2;
wire [INPUT_WIDTH_2-1:0] m_sine_d_2;
wire [CHANNEL_WIDTH_2-1:0] m_sine_ch_2;
wire m_sine_dv_2;
wire m_sine_dr_2;

sine_wg swg_2(
    .clk(clk),
    .rst_n(rst_n),
    .s_sine_d(s_sine_d_2),
    .s_sine_ch(s_sine_ch_2),
    .s_sine_dv(s_sine_dv_2),
    .s_sine_dr(s_sine_dr_2),
    .m_sine_d(m_sine_d_2),
    .m_sine_ch(m_sine_ch_2),
    .m_sine_dv(m_sine_dv_2),
    .m_sine_dr(m_sine_dr_2)
    );

defparam swg_2.NR_CHANNELS = NR_CHANNELS_2;
defparam swg_2.FRACTION_1_0_WIDTH = INPUT_WIDTH_2 - 3;
defparam swg_2.OUTPUT_WIDTH = INPUT_WIDTH_2;

wire bclk_2;
wire frame;
wire i2s_tdm_2;

i2s_tdm_enc i2s_tdm_enc_2(
    .mclk(clk),
    .bclk(bclk_2),
    .lrclk(frame),
    .i2s_tdm(i2s_tdm_2),
    .i2s_tdm_ch(s_sine_ch_2),
    .i2s_tdm_chv(s_sine_dv_2),
    .i2s_tdm_chr(s_sine_dr_2),
    .i2s_tdm_d({m_sine_d_2, 8'h01}), // Set bit 0 for LSB verification
    .i2s_tdm_dv(m_sine_dv_2),
    .i2s_tdm_dr(m_sine_dr_2));

defparam i2s_tdm_enc_2.NR_CHANNELS = NR_CHANNELS_2;
defparam i2s_tdm_enc_2.INPUT_WIDTH = INPUT_WIDTH_3;
defparam i2s_tdm_enc_2.LRCLK_POLARITY = 1; // TDM
defparam i2s_tdm_enc_2.LEFT_ALIGNED = 1; // TDM
defparam i2s_tdm_enc_2.MCLK_BCLK_RATIO = 8; // TDM4

wire [INPUT_WIDTH_2-1:0] i2s_tdm_d_2;
wire [CHANNEL_WIDTH_2-1:0] i2s_tdm_ch_2;
wire i2s_tdm_dv_2;
reg i2s_tdm_dr_2 = 1;
wire [INPUT_WIDTH_3-INPUT_WIDTH_2-1:0] i2s_tdm_ignore_2;

i2s_tdm_dec i2s_tdm_dec_2(
    .mclk(clk),
    .bclk(bclk_2),
    .lrclk(frame),
    .i2s_tdm(i2s_tdm_2),
    .i2s_tdm_d({i2s_tdm_d_2, i2s_tdm_ignore_2}),
    .i2s_tdm_ch(i2s_tdm_ch_2),
    .i2s_tdm_dv(i2s_tdm_dv_2),
    .i2s_tdm_dr(i2s_tdm_dr_2));

defparam i2s_tdm_dec_2.NR_CHANNELS = NR_CHANNELS_2;
defparam i2s_tdm_dec_2.OUTPUT_WIDTH = INPUT_WIDTH_3;
defparam i2s_tdm_dec_2.LRCLK_POLARITY = 1; // TDM
defparam i2s_tdm_dec_2.LEFT_ALIGNED = 1; // TDM
defparam i2s_tdm_dec_2.MCLK_BCLK_RATIO = 8; // TDM4

//==============================TDM16===========================================
real s_sine_d_3_0  = MATH_PI * 1/24;  // 1kHz
real s_sine_d_3_1  = MATH_PI * 2/24;  // 2kHz
real s_sine_d_3_2  = MATH_PI * 3/24;  // 3kHz
real s_sine_d_3_3  = MATH_PI * 4/24;  // 4kHz
real s_sine_d_3_4  = MATH_PI * 5/24;  // 5kHz
real s_sine_d_3_5  = MATH_PI * 6/24;  // 6kHz
real s_sine_d_3_6  = MATH_PI * 7/24;  // 7kHz
real s_sine_d_3_7  = MATH_PI * 8/24;  // 8kHz
real s_sine_d_3_8  = MATH_PI * 9/24;  // 9kHz
real s_sine_d_3_9  = MATH_PI * 10/24; // 10kHz
real s_sine_d_3_10 = MATH_PI * 11/24; // 11kHz
real s_sine_d_3_11 = MATH_PI * 12/24; // 12kHz
real s_sine_d_3_12 = MATH_PI * 13/24; // 13kHz
real s_sine_d_3_13 = MATH_PI * 14/24; // 14kHz
real s_sine_d_3_14 = MATH_PI * 15/24; // 15kHz
real s_sine_d_3_15 = MATH_PI * 16/24; // 16kHz
real s_sine_d_3 = 0.0;
wire [CHANNEL_WIDTH_3-1:0] s_sine_ch_3;
wire s_sine_dv_3;
wire s_sine_dr_3;
wire [INPUT_WIDTH_2-1:0] m_sine_d_3;
wire [CHANNEL_WIDTH_3-1:0] m_sine_ch_3;
wire m_sine_dv_3;
wire m_sine_dr_3;

sine_wg swg_3(
    .clk(clk),
    .rst_n(rst_n),
    .s_sine_d(s_sine_d_3),
    .s_sine_ch(s_sine_ch_3),
    .s_sine_dv(s_sine_dv_3),
    .s_sine_dr(s_sine_dr_3),
    .m_sine_d(m_sine_d_3),
    .m_sine_ch(m_sine_ch_3),
    .m_sine_dv(m_sine_dv_3),
    .m_sine_dr(m_sine_dr_3)
    );

defparam swg_3.NR_CHANNELS = NR_CHANNELS_3;
defparam swg_3.FRACTION_1_0_WIDTH = INPUT_WIDTH_2 - 3;
defparam swg_3.OUTPUT_WIDTH = INPUT_WIDTH_2;

wire bclk_3;
wire i2s_tdm_3;

i2s_tdm_enc i2s_tdm_enc_3(
    .mclk(clk),
    .bclk(bclk_3),
    .lrclk(frame),
    .i2s_tdm(i2s_tdm_3),
    .i2s_tdm_ch(s_sine_ch_3),
    .i2s_tdm_chv(s_sine_dv_3),
    .i2s_tdm_chr(s_sine_dr_3),
    .i2s_tdm_d({m_sine_d_3, 8'h01}), // Set bit 0 for LSB verification
    .i2s_tdm_dv(m_sine_dv_3),
    .i2s_tdm_dr(m_sine_dr_3));

defparam i2s_tdm_enc_3.NR_CHANNELS = NR_CHANNELS_3;
defparam i2s_tdm_enc_3.INPUT_WIDTH = INPUT_WIDTH_3;
defparam i2s_tdm_enc_3.LRCLK_POLARITY = 1; // TDM
defparam i2s_tdm_enc_3.LEFT_ALIGNED = 1; // TDM
defparam i2s_tdm_enc_3.MCLK_BCLK_RATIO = 2; // TDM16

wire [INPUT_WIDTH_2-1:0] i2s_tdm_d_3;
wire [CHANNEL_WIDTH_3-1:0] i2s_tdm_ch_3;
wire i2s_tdm_dv_3;
reg i2s_tdm_dr_3 = 1;
wire [INPUT_WIDTH_3-INPUT_WIDTH_2-1:0] i2s_tdm_ignore_3;

i2s_tdm_dec i2s_tdm_dec_3(
    .mclk(clk),
    .bclk(bclk_3),
    .lrclk(frame),
    .i2s_tdm(i2s_tdm_3),
    .i2s_tdm_d({i2s_tdm_d_3, i2s_tdm_ignore_3}),
    .i2s_tdm_ch(i2s_tdm_ch_3),
    .i2s_tdm_dv(i2s_tdm_dv_3),
    .i2s_tdm_dr(i2s_tdm_dr_3));

defparam i2s_tdm_dec_3.NR_CHANNELS = NR_CHANNELS_3;
defparam i2s_tdm_dec_3.OUTPUT_WIDTH = INPUT_WIDTH_3;
defparam i2s_tdm_dec_3.LRCLK_POLARITY = 1; // TDM
defparam i2s_tdm_dec_3.LEFT_ALIGNED = 1; // TDM
defparam i2s_tdm_dec_3.MCLK_BCLK_RATIO = 2; // TDM16

//===========================Clocks and data collect============================

always #10.173 clk = ~clk; // 49.152 MHz clock

reg [9:0] clk_counter = 0;
/*============================================================================*/
always @(posedge clk) begin : generate_clocks
/*============================================================================*/
    clk_counter <= clk_counter + 1;
    if ( !rst_n ) begin
        clk_counter <= 0;
    end
end // generate_clocks

assign bclk_3 = clk_counter[0]; // 24.576MHz, clk divide by 2
assign bclk_2 = clk_counter[2]; // 6.144MHz, clk divide by 8
assign bclk_1 = clk_counter[4]; // 1.536MHz, clk divide by 32
assign lrclk = clk_counter[9]; // 48kHz, clk divide by 1024
assign frame = ~lrclk;

// Sine values from sine wave generator, input for I2S/TDM encoder
reg signed [INPUT_WIDTH_1-1:0] sine_1_1 = 0;
reg signed [INPUT_WIDTH_1-1:0] sine_1_2 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_2_1 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_2_2 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_2_3 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_2_4 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_1 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_2 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_3 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_4 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_5 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_6 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_7 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_8 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_9 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_10 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_11 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_12 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_13 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_14 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_15 = 0;
reg signed [INPUT_WIDTH_2-1:0] sine_3_16 = 0;
// Decoded sine values from I2S/TDM decoder, should match the sine input values!
reg signed [INPUT_WIDTH_1-1:0] dec_i2s_1_1 = 0;
reg signed [INPUT_WIDTH_1-1:0] dec_i2s_1_2 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_2_1 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_2_2 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_2_3 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_2_4 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_1 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_2 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_3 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_4 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_5 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_6 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_7 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_8 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_9 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_10 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_11 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_12 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_13 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_14 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_15 = 0;
reg signed [INPUT_WIDTH_2-1:0] dec_i2s_3_16 = 0;

/*============================================================================*/
always @(posedge clk) begin : collect_data
//==============================I2S=============================================
    if ( m_sine_dv_1 ) begin
        case ( m_sine_ch_1 )
            0 : sine_1_1 <= m_sine_d_1;
            1 : sine_1_2 <= m_sine_d_1;
        endcase
    end
    if ( i2s_tdm_dv_1 ) begin
        case ( i2s_tdm_ch_1 )
            0 : dec_i2s_1_1 <= i2s_tdm_d_1;
            1 : dec_i2s_1_2 <= i2s_tdm_d_1;
        endcase
    end
//==============================TDM4============================================
    if ( m_sine_dv_2 ) begin
        case ( m_sine_ch_2 )
            0 : sine_2_1 <= m_sine_d_2;
            1 : sine_2_2 <= m_sine_d_2;
            2 : sine_2_3 <= m_sine_d_2;
            3 : sine_2_4 <= m_sine_d_2;
        endcase
    end
    if ( i2s_tdm_dv_2 ) begin
        case ( i2s_tdm_ch_2 )
            0 : dec_i2s_2_1 <= i2s_tdm_d_2;
            1 : dec_i2s_2_2 <= i2s_tdm_d_2;
            2 : dec_i2s_2_3 <= i2s_tdm_d_2;
            3 : dec_i2s_2_4 <= i2s_tdm_d_2;
        endcase
    end
//==============================TDM16===========================================
    if ( m_sine_dv_3 ) begin
        case ( m_sine_ch_3 )
            0  : sine_3_1  <= m_sine_d_3;
            1  : sine_3_2  <= m_sine_d_3;
            2  : sine_3_3  <= m_sine_d_3;
            3  : sine_3_4  <= m_sine_d_3;
            4  : sine_3_5  <= m_sine_d_3;
            5  : sine_3_6  <= m_sine_d_3;
            6  : sine_3_7  <= m_sine_d_3;
            7  : sine_3_8  <= m_sine_d_3;
            8  : sine_3_9  <= m_sine_d_3;
            9  : sine_3_10 <= m_sine_d_3;
            10 : sine_3_11 <= m_sine_d_3;
            11 : sine_3_12 <= m_sine_d_3;
            12 : sine_3_13 <= m_sine_d_3;
            13 : sine_3_14 <= m_sine_d_3;
            14 : sine_3_15 <= m_sine_d_3;
            15 : sine_3_16 <= m_sine_d_3;
        endcase
    end
    if ( i2s_tdm_dv_3 ) begin
        case ( i2s_tdm_ch_3 )
            0  : dec_i2s_3_1  <= i2s_tdm_d_3;
            1  : dec_i2s_3_2  <= i2s_tdm_d_3;
            2  : dec_i2s_3_3  <= i2s_tdm_d_3;
            3  : dec_i2s_3_4  <= i2s_tdm_d_3;
            4  : dec_i2s_3_5  <= i2s_tdm_d_3;
            5  : dec_i2s_3_6  <= i2s_tdm_d_3;
            6  : dec_i2s_3_7  <= i2s_tdm_d_3;
            7  : dec_i2s_3_8  <= i2s_tdm_d_3;
            8  : dec_i2s_3_9  <= i2s_tdm_d_3;
            9  : dec_i2s_3_10 <= i2s_tdm_d_3;
            10 : dec_i2s_3_11 <= i2s_tdm_d_3;
            11 : dec_i2s_3_12 <= i2s_tdm_d_3;
            12 : dec_i2s_3_13 <= i2s_tdm_d_3;
            13 : dec_i2s_3_14 <= i2s_tdm_d_3;
            14 : dec_i2s_3_15 <= i2s_tdm_d_3;
            15 : dec_i2s_3_16 <= i2s_tdm_d_3;
        endcase
    end
end // collect_data

/*============================================================================*/
always @(*) begin : set_sine_rad
/*============================================================================*/
    case ( s_sine_ch_1 )
        0 : s_sine_d_1 = s_sine_d_1_0;
        1 : s_sine_d_1 = s_sine_d_1_1;
    endcase
    case ( s_sine_ch_2 )
        0 : s_sine_d_2 = s_sine_d_2_0;
        1 : s_sine_d_2 = s_sine_d_2_1;
        2 : s_sine_d_2 = s_sine_d_2_2;
        3 : s_sine_d_2 = s_sine_d_2_3;
    endcase
    case ( s_sine_ch_3 )
        0  : s_sine_d_3 = s_sine_d_3_0;
        1  : s_sine_d_3 = s_sine_d_3_1;
        2  : s_sine_d_3 = s_sine_d_3_2;
        3  : s_sine_d_3 = s_sine_d_3_3;
        4  : s_sine_d_3 = s_sine_d_3_4;
        5  : s_sine_d_3 = s_sine_d_3_5;
        6  : s_sine_d_3 = s_sine_d_3_6;
        7  : s_sine_d_3 = s_sine_d_3_7;
        8  : s_sine_d_3 = s_sine_d_3_8;
        9  : s_sine_d_3 = s_sine_d_3_9;
        10 : s_sine_d_3 = s_sine_d_3_10;
        11 : s_sine_d_3 = s_sine_d_3_11;
        12 : s_sine_d_3 = s_sine_d_3_12;
        13 : s_sine_d_3 = s_sine_d_3_13;
        14 : s_sine_d_3 = s_sine_d_3_14;
        15 : s_sine_d_3 = s_sine_d_3_15;
    endcase
end // set_sine_rad

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    #100
    $display( "I2S/TDM4/TDM16 simulation started" );
    rst_n = 1;
    #5000000 // 5ms
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "i2s_tdm_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // i2s_tdm_tb

/*============================================================================*/
module sine_wg #( // Simulation multi channel sine wave generator
/*============================================================================*/
    parameter NR_CHANNELS = 2,
    parameter FRACTION_1_0_WIDTH = 21,
    parameter OUTPUT_WIDTH = 24 )
    (
    clk,
    rst_n,
    s_sine_d, // Signed angle (radian -PI, +PI)
    s_sine_ch, // _ch = channel for sine wave generation
    s_sine_dv, // _dv = data valid
    s_sine_dr, // _dr = data ready
    m_sine_d, // Sine, (-1.0, +1.0), S(OUTPUT_WIDTH-FRAC_1_0_WIDTH+1).FRAC_1_0_WIDTH fraction!
    m_sine_ch, // output sine wave channel
    m_sine_dv,
    m_sine_dr
    );

localparam CHANNEL_WIDTH = $clog2( NR_CHANNELS );

input  wire clk;
input  wire rst_n;
input  real s_sine_d;
input  wire [CHANNEL_WIDTH-1:0] s_sine_ch;
input  wire s_sine_dv;
output reg  s_sine_dr = 1;
output reg  [OUTPUT_WIDTH-1:0] m_sine_d = 0;
output reg  [CHANNEL_WIDTH-1:0] m_sine_ch = 0;
output wire m_sine_dv;
input  wire m_sine_dr;

localparam real FRACTION_1_0 = 2.0 ** FRACTION_1_0_WIDTH;
real sine_ch[0:NR_CHANNELS-1];
real sine_ch_i;
reg  m_sine_dv_i = 0;

reg [CHANNEL_WIDTH:0] i;
/*============================================================================*/
initial begin : init_and_check
/*============================================================================*/
    if ( FRACTION_1_0_WIDTH > ( OUTPUT_WIDTH - 3 )) begin
        $display( "FRACTION_1_0_WIDTH > ( OUTPUT_WIDTH - 3 )!" );
        $finish;
    end
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        sine_ch[i] = 0.0;
    end
end // init_and_check

/*============================================================================*/
always @(posedge clk) begin : sine_wave_generator
/*============================================================================*/
    s_sine_dr <= 1;
    m_sine_dv_i <= m_sine_dv_i & ~m_sine_dr;
    if ( s_sine_dv && ( s_sine_ch < NR_CHANNELS )) begin
        s_sine_dr <= 0;
        sine_ch_i = sine_ch[s_sine_ch] + s_sine_d;
        sine_ch[s_sine_ch] <= sine_ch_i;
        m_sine_d <= FRACTION_1_0 * $sin( sine_ch_i );
        m_sine_ch <= s_sine_ch;
        m_sine_dv_i <= 1;
    end
    if ( !rst_n ) begin
        for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
            sine_ch[i] <= 0.0;
        end
        m_sine_d <= 0;
        m_sine_ch <= 0;
        m_sine_dv_i <= 0;
    end
end // sine_wave_generator

assign m_sine_dv = m_sine_dv_i;

endmodule // sine_wg