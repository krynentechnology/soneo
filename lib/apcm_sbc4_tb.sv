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
 *  Description: APCM SBC4 encoder and decoder test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module apcm_sbc4_tb;
/*============================================================================*/

localparam NR_CHANNELS = 3;
localparam INPUT_WIDTH = 16;
localparam COEFF_WIDTH = 18;
localparam [15:0] AUTH_CRC = 16'hABCD;

parameter CHANNEL_WIDTH = $clog2( NR_CHANNELS );

reg clk = 0;
reg rst_n = 0;
reg mute = 0;

wire signed [INPUT_WIDTH-1:0] in_tdata;
reg [CHANNEL_WIDTH-1:0] in_tid;
wire in_tvalid;
wire in_tready;
wire [7:0] apcm_tdata;
wire [CHANNEL_WIDTH-1:0] apcm_tid;
wire apcm_tvalid;
wire apcm_tready;
wire apcm_sop;
wire overflow_enc;
wire [15:0] auth_crc;
wire signed [INPUT_WIDTH-1:0] out_tdata0;
wire signed [INPUT_WIDTH-1:0] out_tdata1;
wire signed [INPUT_WIDTH-1:0] out_tdata2;
wire signed [INPUT_WIDTH-1:0] out_tdata3;
wire [CHANNEL_WIDTH-1:0] out_tid;
wire out_tvalid;
reg out_tready = 0;
wire overflow_dec;

apcm_sbc4_enc apcm_enc(
    .clk(clk),
    .rst_n(rst_n),
    .s_tdata(in_tdata),
    .s_tid(in_tid),
    .s_tvalid(in_tvalid),
    .s_tready(in_tready),
    .m_apcm_tdata(apcm_tdata),
    .m_apcm_tid(apcm_tid),
    .m_apcm_tvalid(apcm_tvalid),
    .m_apcm_tready(apcm_tready),
    .auth_crc(AUTH_CRC),
    .apcm_sop(apcm_sop),
    .aes_enable(1'b0),
    .m_aes_tready(1'b1),
    .s_aes_tdata(128'd0),
    .s_aes_tvalid(1'b0),
    .overflow(overflow_enc)
    );

defparam apcm_enc.NR_CHANNELS = NR_CHANNELS;
defparam apcm_enc.COEFF_WIDTH = COEFF_WIDTH;

apcm_sbc4_dec apcm_dec(
    .clk(clk),
    .rst_n(rst_n),
    .s_apcm_tdata(apcm_tdata),
    .s_apcm_tid(apcm_tid),
    .s_apcm_tvalid(apcm_tvalid),
    .s_apcm_tready(apcm_tready),
    .apcm_sop(apcm_sop),
    .aes_enable(1'b0),
    .m_aes_tready(1'b1),
    .auth_crc(auth_crc),
    .m_tdata0(out_tdata0),
    .m_tdata1(out_tdata1),
    .m_tdata2(out_tdata2),
    .m_tdata3(out_tdata3),
    .m_tid(out_tid),
    .m_tvalid(out_tvalid),
    .m_tready(out_tready),
    .s_aes_tdata(128'd0),
    .s_aes_tvalid(1'b0),
    .overflow(overflow_dec)
 );

defparam apcm_dec.NR_CHANNELS = NR_CHANNELS;
defparam apcm_dec.COEFF_WIDTH = COEFF_WIDTH;

reg sg_data_sign = 0;
reg sg_data_sign_prev = 0;
reg sg_data_zero_cross = 0;

////////////////// Sine generator for 4 subbands ///////////////////
reg signed [INPUT_WIDTH-1:0] sg_tdata = 0;
reg [1:0] sg_tid = 0;
reg sg_tvalid = 0;
integer nb_of_samples = 0;

localparam real MATH_2_PI = 2 * 3.14159265358979323846;
localparam integer SAMPLE_FREQUENCY = 32000;
localparam integer MULTIPLIER = ( 2 ** ( INPUT_WIDTH - 1 )) - 1;
real step[0:NR_CHANNELS-1][0:3];
real sine_counter[0:NR_CHANNELS-1];
/*============================================================================*/
initial begin
/*============================================================================*/
    step[0][0] = MATH_2_PI * 2000 / SAMPLE_FREQUENCY;  // center of 0-4kHz subband
    step[0][1] = MATH_2_PI * 6000 / SAMPLE_FREQUENCY;  // center of 4-8kHz subband
    step[0][2] = MATH_2_PI * 10000 / SAMPLE_FREQUENCY; // center of 8-12kHz subband
    step[0][3] = MATH_2_PI * 14000 / SAMPLE_FREQUENCY; // center of 12-16kHz subband
    step[1][0] = MATH_2_PI * 1000 / SAMPLE_FREQUENCY;  // low edge of 0-4kHz subband
    step[1][1] = MATH_2_PI * 5000 / SAMPLE_FREQUENCY;  // low edge of 4-8kHz subband
    step[1][2] = MATH_2_PI * 9000 / SAMPLE_FREQUENCY;  // low edge of 8-12kHz subband
    step[1][3] = MATH_2_PI * 13000 / SAMPLE_FREQUENCY; // low edge of 12-16kHz subband
    step[2][0] = MATH_2_PI * 3000 / SAMPLE_FREQUENCY;  // high edge of 0-4kHz subband
    step[2][1] = MATH_2_PI * 7000 / SAMPLE_FREQUENCY;  // high edge of 4-8kHz subband
    step[2][2] = MATH_2_PI * 11000 / SAMPLE_FREQUENCY; // high edge of 8-12kHz subband
    step[2][3] = MATH_2_PI * 15000 / SAMPLE_FREQUENCY; // high edge of 12-16kHz subband
    sine_counter[0] = 0.0;
    sine_counter[1] = 0.0;
    sine_counter[2] = 0.0;
end

/*============================================================================*/
always @(posedge clk) begin : sine_generator
/*============================================================================*/
    sg_tvalid <= sg_tvalid & ~in_tready;
    if ( !sg_tvalid ) begin
        repeat (128) @(posedge clk); // Wait 128 clock cycles
        sg_tdata <= 0;
        if ( !mute ) begin
            sg_tdata <= $signed( $rtoi( MULTIPLIER * $sin( sine_counter[in_tid] )));
            sine_counter[in_tid] <= sine_counter[in_tid] + step[in_tid][sg_tid];
        end    
        sg_tvalid <= 1;
        nb_of_samples <= nb_of_samples + 1;
    end
    if ( !rst_n ) begin
        sine_counter[0] <= 0.0;
        sine_counter[1] <= 0.0;
        sine_counter[2] <= 0.0;
        sg_tdata <= 0;
        sg_tvalid <= 0;
    end
end // sine_generator

/*============================================================================*/
always @(posedge clk) begin : sg_zero_cross
/*============================================================================*/
    sg_data_sign_prev <= sg_data_sign;
    sg_data_sign <= sg_tdata[INPUT_WIDTH-1];
    sg_data_zero_cross <= (sg_data_sign ^ sg_data_sign_prev) & sg_data_sign_prev;
end // sg_zero_cross

localparam OUTDATA_BUFFER_SIZE = 32;
reg signed [INPUT_WIDTH-1:0] out_tdata_i[0:OUTDATA_BUFFER_SIZE-1];
reg signed [INPUT_WIDTH-1:0] out_tdata_ii[0:OUTDATA_BUFFER_SIZE-1];
reg signed [INPUT_WIDTH-1:0] out_tdata_iii[0:OUTDATA_BUFFER_SIZE-1];
reg signed [INPUT_WIDTH-1:0] out_tdata = 0;
integer i;
/*============================================================================*/
initial begin : i_out_tdata_init // Initialize output synthesis RAM
/*============================================================================*/
    for ( i = 0; i < OUTDATA_BUFFER_SIZE; i = i + 1 ) begin
        out_tdata_i[i] = 0;
        out_tdata_ii[i] = 0;
        out_tdata_iii[i] = 0;
    end
end // i_out_tdata_init

reg sg_tvalid_i = 0;
reg [4:0] sg_valid_count_i = 0;
reg out_tvalid_i = 0;
reg [4:0] out_valid_index = 0;
/*============================================================================*/
always @(posedge clk) begin : collect_data
/*============================================================================*/
    out_tvalid_i <= out_tvalid;
    if ( out_tvalid_i && !out_tvalid ) begin
        out_tdata_i[out_valid_index]   <= out_tdata0;
        out_tdata_i[out_valid_index+1] <= out_tdata1;
        out_tdata_i[out_valid_index+2] <= out_tdata2;
        out_tdata_i[out_valid_index+3] <= out_tdata3;
        out_valid_index <= out_valid_index + 4;
        if ( 0 == out_valid_index ) begin
            for ( i = 0; i < OUTDATA_BUFFER_SIZE; i = i + 1 ) begin
                out_tdata_ii[i] = out_tdata_i[i];
            end
        end
    end
    sg_tvalid_i <= sg_tvalid;
    if ( sg_tvalid_i && !sg_tvalid ) begin
        out_tdata <= out_tdata_iii[sg_valid_count_i];
        sg_valid_count_i <= sg_valid_count_i + 1;
        if (( OUTDATA_BUFFER_SIZE - 1 ) == sg_valid_count_i ) begin
            for ( i = 0; i < OUTDATA_BUFFER_SIZE; i = i + 1 ) begin
                out_tdata_iii[i] = out_tdata_ii[i];
            end
        end
    end
end // collect_data

assign in_tdata = sg_tdata;
assign in_tvalid = sg_tvalid;

always #5 clk = ~clk; // 100 MHz clock

/*============================================================================*/
initial begin : test
/*============================================================================*/
    rst_n = 0;
    sg_tid = 0;
    mute = 0;
    in_tid = 0;
    out_tready = 1;
    #100
    rst_n = 1;
    $display( "APCM/SBC4 simulation started" );
    $display( "Generate 2kHz 0-4kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 1;
    $display( "Generate 6kHz 4-8kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 2;
    $display( "Generate 10kHz 8-12kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 3;
    $display( "Generate 14kHz 12-16kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    mute = 1;
    wait ( !sg_tvalid );
    wait (( nb_of_samples % 32 ) == 0 );
    mute = 0;
    in_tid = 1;
    sg_tid = 0;
    $display( "Generate 1kHz 0-4kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 1;
    $display( "Generate 5kHz 4-8kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 2;
    $display( "Generate 9kHz 8-12kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 3;
    $display( "Generate 13kHz 12-16kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    mute = 1;
    wait ( !sg_tvalid );
    wait (( nb_of_samples % 32 ) == 0 );
    mute = 0;
    in_tid = 2;
    sg_tid = 0;
    $display( "Generate 3kHz 0-4kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 1;
    $display( "Generate 7kHz 4-8kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 2;
    $display( "Generate 11kHz 8-12kHz subband" );
    #200000
    wait ( sg_data_zero_cross );
    sg_tid = 3;
    $display( "Generate 15kHz 12-16kHz subband" );
    #200000

    $display( "Simulation finished" );
    $finish;
end // test

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "apcm_sbc4_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule