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
 *  Description:
 *  Sine wave generator with optional linear interpolation test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module sine_wg_lin_tb;

parameter SG_NR_CHANNELS = 3;
parameter SG_INPUT_WIDTH = 24;
parameter SG_SAMPLE_FREQUENCY = 48000;

parameter CHANNEL_WIDTH_1 = $clog2( SG_NR_CHANNELS );
parameter CHANNEL_WIDTH_2 = $clog2( SG_NR_CHANNELS );
parameter FREQUENCY_WIDTH_1 = $clog2( SG_SAMPLE_FREQUENCY / 2 ); // Nyquist
parameter FREQUENCY_WIDTH_2 = $clog2( SG_SAMPLE_FREQUENCY / 2 );

reg clk = 0;
reg rst_n = 0;

reg [FREQUENCY_WIDTH_1-1:0] frequency_1 = 0;
reg m_sg_dr_1 = 0;
wire [CHANNEL_WIDTH_1-1:0] freq_ch_1;
wire [6:0] freq_step_1;
wire [SG_INPUT_WIDTH-1:0] m_sg_d_1;
wire [CHANNEL_WIDTH_1-1:0] m_sg_ch_1;
wire m_sg_dv_1;

sine_wg_lin sg_1(
    .clk(clk),
    .rst_n(rst_n),
    .sg_frequency(frequency_1),
    .sg_freq_ch(freq_ch_1),
    .sg_freq_step(freq_step_1),
    .m_sg_d(m_sg_d_1),
    .m_sg_ch(m_sg_ch_1),
    .m_sg_dv(m_sg_dv_1),
    .m_sg_dr(m_sg_dr_1)
    );

defparam sg_1.NR_CHANNELS = SG_NR_CHANNELS;
defparam sg_1.INPUT_WIDTH = SG_INPUT_WIDTH;
defparam sg_1.SAMPLE_FREQUENCY = SG_SAMPLE_FREQUENCY;
defparam sg_1.INTERPOLATION = "LINEAR";

reg [FREQUENCY_WIDTH_2-1:0] frequency_2 = 0;
reg m_sg_dr_2 = 0;
wire [CHANNEL_WIDTH_2-1:0] freq_ch_2;
wire [6:0] freq_step_2;
wire [SG_INPUT_WIDTH-1:0] m_sg_d_2;
wire [CHANNEL_WIDTH_2-1:0] m_sg_ch_2;
wire m_sg_dv_2;

sine_wg_lin sg_2(
    .clk(clk),
    .rst_n(rst_n),
    .sg_frequency(frequency_2),
    .sg_freq_ch(freq_ch_2),
    .sg_freq_step(freq_step_2),
    .m_sg_d(m_sg_d_2),
    .m_sg_ch(m_sg_ch_2),
    .m_sg_dv(m_sg_dv_2),
    .m_sg_dr(m_sg_dr_2)
    );

defparam sg_2.NR_CHANNELS = SG_NR_CHANNELS;
defparam sg_2.INPUT_WIDTH = SG_INPUT_WIDTH;
defparam sg_2.SAMPLE_FREQUENCY = SG_SAMPLE_FREQUENCY;
defparam sg_2.INTERPOLATION = "NONE";

reg [SG_INPUT_WIDTH-1:0] tone_1[SG_NR_CHANNELS-1:0];
reg [SG_INPUT_WIDTH-1:0] tone_2[SG_NR_CHANNELS-1:0];
reg [SG_NR_CHANNELS-1:0] collect_data_1 = 0;
reg [SG_NR_CHANNELS-1:0] collect_data_2 = 0;
wire [SG_INPUT_WIDTH-1:0] tone_1_1;
wire [SG_INPUT_WIDTH-1:0] tone_1_2;
wire [SG_INPUT_WIDTH-1:0] tone_1_3;
wire [SG_INPUT_WIDTH-1:0] tone_2_1;
wire [SG_INPUT_WIDTH-1:0] tone_2_2;
wire [SG_INPUT_WIDTH-1:0] tone_2_3;
assign tone_1_1 = tone_1[0];
assign tone_1_2 = tone_1[1];
assign tone_1_3 = tone_1[2];
assign tone_2_1 = tone_2[0];
assign tone_2_2 = tone_2[1];
assign tone_2_3 = tone_2[2];

// Generate clock 49.152MHz
always #( 20.345 / 2 ) clk = ~clk;

// Generate clock 48kHz, 96kHz, 192kHz
reg [9:0] clk_counter = 0;
reg clk_48kHz = 0;
reg clk_96kHz = 0;
reg clk_192kHz = 0;
reg clk_48kHz_i = 0;
reg clk_96kHz_i = 0;
reg clk_192kHz_i = 0;

/*============================================================================*/
always @(posedge clk) begin : clock_gen
/*============================================================================*/
    clk_counter <= clk_counter + 1;
    clk_48kHz <= clk_counter[9];  // clk divide by 1024
    clk_96kHz <= clk_counter[8];  // clk divide by 512
    clk_192kHz <= clk_counter[7]; // clk divide by 256
    clk_48kHz_i <= clk_48kHz;
    clk_96kHz_i <= clk_96kHz;
    clk_192kHz_i <= clk_192kHz;

    if ( !rst_n ) begin
        clk_counter <= 0;
        clk_48kHz <= 0;
        clk_96kHz <= 0;
        clk_192kHz <= 0;
    end
end // clock_gen

integer i;
/*============================================================================*/
initial begin
/*============================================================================*/
    for ( i = 0; i < sg_1.NR_CHANNELS; i = i + 1 ) begin
        tone_1[i] = 0;
    end
    for ( i = 0; i < sg_2.NR_CHANNELS; i = i + 1 ) begin
        tone_2[i] = 0;
    end
end

/*============================================================================*/
always @(*) begin : output_sg // Output channel sg_frequency
/*============================================================================*/
    case ( freq_ch_1 )
        0 : frequency_1 = 1010;
        1 : frequency_1 = 12010;
        2 : frequency_1 = 22510;
        default: $display( "Error in sg_frequency 1 channel" );
    endcase
    case ( freq_ch_2 )
        0 : frequency_2 = 1000;
        1 : frequency_2 = 12000;
        2 : frequency_2 = 22500;
        default: $display( "Error in sg_frequency 2 channel" );
    endcase
end // output_sg

/*============================================================================*/
always @(posedge clk) begin : collect_data
/*============================================================================*/
    m_sg_dr_1 <= 0;
    m_sg_dr_2 <= 0;
    if ( clk_48kHz && ( clk_48kHz != clk_48kHz_i )) begin
        collect_data_1 <= 8'hFF;
        collect_data_2 <= 8'hFF;
    end
    if ( m_sg_dv_1 && collect_data_1[m_sg_ch_1] ) begin
        m_sg_dr_1 <= 1;
        tone_1[m_sg_ch_1] <= m_sg_d_1;
        collect_data_1[m_sg_ch_1] <= 0;
    end
    if ( m_sg_dv_2 && collect_data_1[m_sg_ch_2] ) begin
        m_sg_dr_2 <= 1;
        tone_2[m_sg_ch_2] <= m_sg_d_2;
        collect_data_2[m_sg_ch_2] <= 0;
    end
end // collect_data

localparam US_10 = 10000;
localparam US_100 = 10 * US_10;
localparam MS_1 = 10 * US_100;
localparam MS_10 = 10 * MS_1;

/*============================================================================*/
initial begin : test
/*============================================================================*/
    clk = 0;
    rst_n = 0;
    frequency_1 = 1000;
    frequency_2 = 1000;
    $display( "Sine wave generator (optional linear interpolation) simulation started" );
    $display( "Sine wave generator 1 step size = %0dHz", freq_step_1 );
    $display( "Sine wave generator 2 step size = %0dHz", freq_step_2 );
    #100
    wait ( clk ) @( negedge clk );
    rst_n = 1;
    #MS_10 $finish;
end // test

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "sine_wg_lin_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // sine_wg_lin_tb
