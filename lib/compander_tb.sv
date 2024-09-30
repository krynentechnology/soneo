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
 *  Description: Signal compander to/from 16-bit two's complement value test
 *               bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module compander_tb;
/*============================================================================*/

localparam INW16 = 16;
localparam INW20 = 20;
localparam INW27 = 27;
localparam OUTW16 = 16;
localparam OUTW20 = 20;
localparam OUTW27 = 27;
localparam real MATH_PI = 3.141592653589793115997963;

reg clk = 0;
reg rst_n = 0;

real s_sine_d_1 = MATH_PI * 1/24;
wire s_sine_dv_1;
wire [INW27-1:0] m_sine_d_1;
wire m_sine_dv_1;
assign s_sine_dv_1 = ~m_sine_dv_1;

sine_wg swg_1(
    .clk(clk),
    .rst_n(rst_n),
    .s_sine_d(s_sine_d_1),
    .s_sine_ch(1'b0),
    .s_sine_dv(s_sine_dv_1),
    .m_sine_d(m_sine_d_1),
    .m_sine_dv(m_sine_dv_1),
    .m_sine_dr(1'b1)
    );

defparam swg_1.NR_CHANNELS = 1;
defparam swg_1.FRACTION_1_0_WIDTH = INW27 - 2;
defparam swg_1.OUTPUT_WIDTH = INW27;

wire [INW20-1:0] s_cmpndr_1_d;
wire [OUTW16-1:0] m_cmpndr_1_d;
wire m_cmpndr_1_dv;
assign s_cmpndr_1_d = m_sine_d_1[INW27-1:( INW27 - INW20 )]; 

compander compander_1(
    .clk(clk),
    .s_cmpndr_d(s_cmpndr_1_d),
    .s_cmpndr_dv(m_sine_dv_1),
    .m_cmpndr_d(m_cmpndr_1_d),
    .m_cmpndr_dv(m_cmpndr_1_dv));

defparam compander_1.COMPANDING = "20BIT";
defparam compander_1.ENCODER = 1;
defparam compander_1.BARREL_SHIFTER = 1;

wire [OUTW20-1:0] m_cmpndr_2_d;
wire m_cmpndr_2_dv;

compander compander_2(
    .clk(clk),
    .s_cmpndr_d(m_cmpndr_1_d),
    .s_cmpndr_dv(m_cmpndr_1_dv),
    .m_cmpndr_d(m_cmpndr_2_d),
    .m_cmpndr_dv(m_cmpndr_2_dv));

defparam compander_2.COMPANDING = "20BIT";
defparam compander_2.ENCODER = 0; // Decoder
defparam compander_2.BARREL_SHIFTER = 1;

wire [OUTW16-1:0] m_cmpndr_3_d;
wire m_cmpndr_3_dv;

compander compander_3(
    .clk(clk),
    .s_cmpndr_d(s_cmpndr_1_d),
    .s_cmpndr_dv(m_sine_dv_1),
    .m_cmpndr_d(m_cmpndr_3_d),
    .m_cmpndr_dv(m_cmpndr_3_dv));

defparam compander_3.COMPANDING = "20BIT";
defparam compander_3.ENCODER = 1;
defparam compander_3.BARREL_SHIFTER = 0;

wire [OUTW20-1:0] m_cmpndr_4_d;
wire m_cmpndr_4_dv;

compander compander_4(
    .clk(clk),
    .s_cmpndr_d(m_cmpndr_3_d),
    .s_cmpndr_dv(m_cmpndr_3_dv),
    .m_cmpndr_d(m_cmpndr_4_d),
    .m_cmpndr_dv(m_cmpndr_4_dv));

defparam compander_4.COMPANDING = "20BIT";
defparam compander_4.ENCODER = 0; // Decoder
defparam compander_4.BARREL_SHIFTER = 0;

wire [INW27-1:0] s_cmpndr_5_d;
wire [OUTW16-1:0] m_cmpndr_5_d;
wire m_cmpndr_5_dv;
assign s_cmpndr_5_d = m_sine_d_1;

compander compander_5(
    .clk(clk),
    .s_cmpndr_d(s_cmpndr_5_d),
    .s_cmpndr_dv(m_sine_dv_1),
    .m_cmpndr_d(m_cmpndr_5_d),
    .m_cmpndr_dv(m_cmpndr_5_dv));

defparam compander_5.COMPANDING = "27BIT";
defparam compander_5.ENCODER = 1;
defparam compander_5.BARREL_SHIFTER = 1;

wire [OUTW27-1:0] m_cmpndr_6_d;
wire m_cmpndr_6_dv;

compander compander_6(
    .clk(clk),
    .s_cmpndr_d(m_cmpndr_5_d),
    .s_cmpndr_dv(m_cmpndr_5_dv),
    .m_cmpndr_d(m_cmpndr_6_d),
    .m_cmpndr_dv(m_cmpndr_6_dv));

defparam compander_6.COMPANDING = "27BIT";
defparam compander_6.ENCODER = 0; // Decoder
defparam compander_6.BARREL_SHIFTER = 1;

wire [OUTW16-1:0] m_cmpndr_7_d;
wire m_cmpndr_7_dv;

compander compander_7(
    .clk(clk),
    .s_cmpndr_d(s_cmpndr_5_d),
    .s_cmpndr_dv(m_sine_dv_1),
    .m_cmpndr_d(m_cmpndr_7_d),
    .m_cmpndr_dv(m_cmpndr_7_dv));

defparam compander_7.COMPANDING = "27BIT";
defparam compander_7.ENCODER = 1;
defparam compander_7.BARREL_SHIFTER = 0;

wire [OUTW27-1:0] m_cmpndr_8_d;
wire m_cmpndr_8_dv;

compander compander_8(
    .clk(clk),
    .s_cmpndr_d(m_cmpndr_7_d),
    .s_cmpndr_dv(m_cmpndr_7_dv),
    .m_cmpndr_d(m_cmpndr_8_d),
    .m_cmpndr_dv(m_cmpndr_8_dv));

defparam compander_8.COMPANDING = "27BIT";
defparam compander_8.ENCODER = 0; // Decoder
defparam compander_8.BARREL_SHIFTER = 0;

always #10 clk = ~clk; // 50 MHz clock

reg [OUTW20-1:0] m_cmpndr_4_d_dec = 0;
reg [OUTW27-1:0] m_cmpndr_8_d_dec = 0;
/*============================================================================*/
always @(posedge clk) begin : compare_data
/*============================================================================*/
    if ( m_cmpndr_1_dv && m_cmpndr_3_dv ) begin
        if ( m_cmpndr_1_d != m_cmpndr_3_d ) begin
            $display( "Compander encoder output mismatch!" );
            $finish;
        end
    end
    if ( m_cmpndr_5_dv && m_cmpndr_7_dv ) begin
        if ( m_cmpndr_5_d != m_cmpndr_7_d ) begin
            $display( "Compander encoder output mismatch!" );
            $finish;
        end
    end
    if ( m_cmpndr_3_dv ) begin // Combinatorial result!
        m_cmpndr_4_d_dec <= m_cmpndr_4_d;
    end
    if ( m_cmpndr_2_dv ) begin
        if ( m_cmpndr_2_d != m_cmpndr_4_d_dec ) begin
            $display( "Compander decoder output mismatch!" );
            $finish;
        end
    end
    if ( m_cmpndr_7_dv ) begin // Combinatorial result!
        m_cmpndr_8_d_dec <= m_cmpndr_8_d;
    end
    if ( m_cmpndr_6_dv ) begin
        if ( m_cmpndr_6_d != m_cmpndr_8_d_dec ) begin
            $display( "Compander decoder output mismatch!" );
            $finish;
        end
    end
end // compare_data

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    #100
    rst_n = 1;
    $display( "Compander simulation started" );
    #10000 // 10us
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "compander_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // compander_tb

/*============================================================================*/
module sine_wg #( // Simulation multi channel sine wave generator
/*============================================================================*/
    parameter NR_CHANNELS = 1,
    parameter FRACTION_1_0_WIDTH = 25,
    parameter OUTPUT_WIDTH = 27 )
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

localparam CHANNEL_WIDTH = ( 1 == NR_CHANNELS ) ?  1 : $clog2( NR_CHANNELS );

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
    if ( FRACTION_1_0_WIDTH > ( OUTPUT_WIDTH - 2 )) begin
        $display( "FRACTION_1_0_WIDTH > ( OUTPUT_WIDTH - 2 )!" );
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
        m_sine_d <= 1.5 * ( FRACTION_1_0 * $sin( sine_ch_i )); // Max. > -6dB
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