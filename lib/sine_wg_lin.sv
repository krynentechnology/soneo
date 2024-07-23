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
 *  Description:
 *  Sine wave generator with optional linear interpolation. There is no output
 *  sine error (except for quantization) when the frequncy requested is a
 *  multiple of the frequency step. Block RAM sine table generated.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module sine_wg_lin #(
/*============================================================================*/
    parameter NR_CHANNELS = 2,
    parameter INPUT_WIDTH = 24,
    parameter SAMPLE_FREQUENCY = 48000, // Maximum = 204400Hz!
    parameter real SINE_AMPLITUDE = 1.0,
    parameter INTERPOLATION = "LINEAR" ) // Otherwise "NONE"
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    sg_frequency, sg_freq_ch, sg_freq_step, // _ch = channel
    m_sg_d, m_sg_ch, m_sg_dv, m_sg_dr // _d = data, _dv = data valid, _dr = data ready
    );

localparam CHANNEL_WIDTH = $clog2( NR_CHANNELS );
localparam FREQUENCY_WIDTH = $clog2( SAMPLE_FREQUENCY / 2 ); // Nyquist

input  wire clk;
input  wire rst_n;
input  wire [FREQUENCY_WIDTH-1:0] sg_frequency; // 0 == starting channel phase is zero
output wire [CHANNEL_WIDTH-1:0] sg_freq_ch;
output wire [6:0] sg_freq_step;
output wire [INPUT_WIDTH-1:0] m_sg_d;
output wire [CHANNEL_WIDTH-1:0] m_sg_ch;
output wire m_sg_dv;
input  wire m_sg_dr;

/*============================================================================*/
function integer sine_Hz_step_size( input integer sample_frequency );
/*============================================================================*/
begin
    if ( INTERPOLATION == "LINEAR" ) begin     // The 4 stands for four sine quadrants = sine period
        if ( sample_frequency <= 65408 )       // Step size 32 * 4 * block ram max index 511 = 65408
            sine_Hz_step_size = 32;            // Used for 44.1kHz and 48kHz sample frequency
        else if ( sample_frequency <= 130816 ) // Step size 64 * 4 * block ram max index 511 = 130816
            sine_Hz_step_size = 64;            // Used for 96kHz sample frequency
        else if ( sample_frequency <= 261632 ) // Step size 128 * 4 * block ram max index 511 = 261632
            sine_Hz_step_size = 128;           // Used for 192kHz sample frequency
        else
            sine_Hz_step_size = 0;             // Invalid value, causes division error
    end
    else begin                                 // The 4 stands for four sine quadrants = sine period
        if ( sample_frequency <= 51100 )       // Step size 25 * 4 * block ram max index 511 = 51100
            sine_Hz_step_size = 25;            // Used for 44.1kHz and 48kHz sample frequency
        else if ( sample_frequency <= 102200 ) // Step size 50 * 4 * block ram max index 511 = 102200
            sine_Hz_step_size = 50;            // Used for 96kHz sample frequency
        else if ( sample_frequency <= 204400 ) // Step size 100 * 4 * block ram max index 511 = 204400
            sine_Hz_step_size = 100;           // Used for 192kHz sample frequency
        else
            sine_Hz_step_size = 0;             // Invalid value, causes division error
    end
end
endfunction

localparam SINE_HZ_STEP_SIZE = sine_Hz_step_size( SAMPLE_FREQUENCY );
localparam FULL_PERIOD_INDEX = SAMPLE_FREQUENCY / SINE_HZ_STEP_SIZE;
localparam SINE_TABLE_SIZE = FULL_PERIOD_INDEX / 4;
localparam FREQUENCY_INDEX_WIDTH = FREQUENCY_WIDTH + 1;
localparam FULL_PERIOD_INDEX_WIDTH = $clog2( FULL_PERIOD_INDEX );
localparam SINE_HZ_STEP_SIZE_WIDTH = $clog2( SINE_HZ_STEP_SIZE );
localparam real FACTOR_1 = 2.0 ** ( INPUT_WIDTH - 1 ) - 1;
localparam real MATH_PI_OVER_2 = $asin( 1.0 ); // 90 degrees PI/2 radian
localparam integer MAX_SINE_DELTA = FACTOR_1 * SINE_AMPLITUDE * $sin( MATH_PI_OVER_2 ) / SINE_TABLE_SIZE;
localparam SINE_DELTA_WIDTH = $clog2( MAX_SINE_DELTA );
localparam PW = SINE_DELTA_WIDTH + SINE_HZ_STEP_SIZE_WIDTH;

integer i;
(* rom_style = "block" *)
reg signed [INPUT_WIDTH-1:0] sine_table[SINE_TABLE_SIZE:0];
reg [INPUT_WIDTH-1:0] sine;
/*============================================================================*/
initial begin : init_sine_table // block RAM sine table
/*============================================================================*/
    for ( i = 0; i <= SINE_TABLE_SIZE; i = i + 1 ) begin
        sine = ( FACTOR_1 * SINE_AMPLITUDE * $sin( MATH_PI_OVER_2 * i / SINE_TABLE_SIZE ));
        sine_table[i] = $signed( sine );
    end
end // init_sine_table

// Non-interpolation specific registers
reg [FULL_PERIOD_INDEX_WIDTH-1:0] sine_index[NR_CHANNELS-1:0];
reg [FULL_PERIOD_INDEX_WIDTH-2:0] sine_index_step[NR_CHANNELS-1:0];
reg [$clog2( FULL_PERIOD_INDEX + ( FULL_PERIOD_INDEX / 2 ))-1:0] index_ch = 0;
reg [FULL_PERIOD_INDEX_WIDTH-2:0] index_180 = 0;
reg [FULL_PERIOD_INDEX_WIDTH-3:0] index_90 = 0;
reg signed [INPUT_WIDTH-1:0] sine_sample = 0;
// Non-interpolation algorithm flow stages
reg prepare_lookup = 0;
reg sine_negate = 0;
reg lookup_table = 0;
reg sample_out = 0;
// Interpolation algorithm flow stages
reg repeat_lookup = 0;
reg calc_delta = 0;
reg multiply = 0;
reg divide_add_out = 0;
// Interpolation specific registers
reg signed [INPUT_WIDTH-1:0] sine_prev_sample = 0;
reg signed [SINE_DELTA_WIDTH-1:0] sine_sample_diff = 0;
reg signed [SINE_HZ_STEP_SIZE_WIDTH:0] sample_modula = 0; // Add one for signed operation
reg [FREQUENCY_INDEX_WIDTH-1:0] frequency_index[NR_CHANNELS-1:0];
reg [FREQUENCY_INDEX_WIDTH:0] frequency_next_index = 0; // Add one to width for add operation
reg [FREQUENCY_INDEX_WIDTH-1:0] next_index = 0;
reg signed [PW-1:0] sample_product = 0;
// Output registers
reg [CHANNEL_WIDTH-1:0] channel_i = 0;
reg [INPUT_WIDTH-1:0] m_sg_d_i = 0;
reg [CHANNEL_WIDTH-1:0] m_sg_ch_i = 0;
reg m_sg_dv_i = 1;

/*============================================================================*/
initial begin
/*============================================================================*/
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        sine_index[i] = 0;
        sine_index_step[i] = 1;
        frequency_index[i] = 0;
    end
end

/*============================================================================*/
initial begin // Parameter checks
/*============================================================================*/
    if (( SAMPLE_FREQUENCY % FULL_PERIOD_INDEX != 0 ) ||
        ( FULL_PERIOD_INDEX % 4 != 0 ) ||
        ( 0 == SINE_HZ_STEP_SIZE )) begin
        $display( "Sample frequency error" );
        $finish;
    end
    if (( SINE_AMPLITUDE <= 0.0 ) || ( SINE_AMPLITUDE > 1.0 )) begin
        $display( "Sine amplitude error" );
        $finish;
    end
    if (( INTERPOLATION != "LINEAR" ) && ( INTERPOLATION != "NONE" )) begin
        $display( "Interpolation parameter error" );
        $finish;
    end
    if (( INPUT_WIDTH - PW + SINE_HZ_STEP_SIZE_WIDTH ) < 0 ) begin
        $display( "INPUT_WIDTH - PW + SINE_HZ_STEP_SIZE_WIDTH ) < 0" );
        $finish;
    end
end

reg [CHANNEL_WIDTH-1:0] j = 0;
/*============================================================================*/
always @(posedge clk) begin : sine_generator
/*============================================================================*/
    prepare_lookup <= 0; // Pulse
    calc_delta <= 0; // Pulse
    if ( m_sg_dv_i & m_sg_dr ) begin
        m_sg_dv_i <= 0;
        if ( INTERPOLATION == "LINEAR" ) begin // Conditional synthesis!
            index_ch <= frequency_index[channel_i][FREQUENCY_INDEX_WIDTH-1:SINE_HZ_STEP_SIZE_WIDTH];
            sample_modula <= frequency_index[channel_i][SINE_HZ_STEP_SIZE_WIDTH-1:0];
            frequency_next_index <= frequency_index[channel_i] + sg_frequency;
            if ( 0 == sg_frequency ) begin // Reset sine generator index to starting phase 0 degrees
                index_ch <= 0;
                sample_modula <= 0;
                frequency_next_index <= 0;
            end
        end // Conditional synthesis!
        else if ( 0 == sg_frequency ) begin // Reset sine generator index to starting phase 0 degrees
            index_ch <= 0;
            sine_index_step[channel_i] <= 1;
        end
        else begin
            index_ch <= sine_index[channel_i];
            sine_index_step[channel_i] <= sg_frequency / SINE_HZ_STEP_SIZE;
        end
        prepare_lookup <= 1;
    end
    // prepare_lookup also set in sample_out!
    if ( prepare_lookup ) begin
        if  ( index_ch > ( SINE_TABLE_SIZE * 2 )) begin // Passed 180 degrees
            index_180 <= index_ch - ( SINE_TABLE_SIZE * 2 );
            sine_negate <= 1;
        end
        else begin
            index_180 <= index_ch[FULL_PERIOD_INDEX_WIDTH-2:0];
            sine_negate <= 0;
        end
        if ( INTERPOLATION == "LINEAR" ) begin // Conditional synthesis!
            index_ch <= index_ch + 1;
            sine_prev_sample <= sine_sample;
        end
        else begin // Conditional synthesis!
            index_ch <= index_ch + sine_index_step[channel_i];
        end
    end
    lookup_table <= prepare_lookup;
    if ( lookup_table ) begin
        index_90 = index_180;
        if ( index_180 > SINE_TABLE_SIZE ) begin // Get 90 degree index
            index_90 = ( SINE_TABLE_SIZE * 2 ) - index_180;
        end
        if ( index_ch >= FULL_PERIOD_INDEX ) begin
            index_ch <= index_ch - FULL_PERIOD_INDEX;
        end
        sine_sample <= sine_table[index_90];
    end
    sample_out <= lookup_table;
    if ( sample_out ) begin
        if ( INTERPOLATION == "LINEAR" ) begin // Conditional synthesis!
            if ( sine_negate ) begin
                sine_sample <= -sine_sample;
            end
            if ( repeat_lookup ) begin
                repeat_lookup <= 0;
                calc_delta <= 1;
            end
            else begin // Get next sine sample for interpolation
                repeat_lookup <= 1;
                prepare_lookup <= 1;
            end
        end
        else begin // Conditional synthesis!
            sine_index[channel_i] <= index_ch;
            m_sg_d_i <= sine_sample;
            if ( sine_negate ) begin
                m_sg_d_i <= -sine_sample;
            end
            if ( 0 == sg_frequency ) begin
                m_sg_d_i <= 0;
            end
            m_sg_ch_i <= channel_i;
            m_sg_dv_i <= 1;
            // Determine next channel
            channel_i <= 0;
            if ( channel_i < ( NR_CHANNELS - 1 )) begin
                channel_i <= channel_i + 1;
            end
        end
    end
    // calc_delta set in sample_out, conditional synthesis!
    if ( calc_delta ) begin // Conditional synthesis!
        sine_sample_diff <= sine_sample - sine_prev_sample;
        if ( frequency_next_index < SAMPLE_FREQUENCY ) begin
            next_index = frequency_next_index;
        end
        else begin
            next_index = frequency_next_index - SAMPLE_FREQUENCY;
        end
        frequency_index[channel_i] <= next_index;
    end
    multiply <= calc_delta;
    if ( multiply ) begin // Conditional synthesis!
        sample_product <= sine_sample_diff * sample_modula;
        m_sg_ch_i <= channel_i;
        // Determine next channel
        channel_i <= 0;
        if ( channel_i < ( NR_CHANNELS - 1 )) begin
            channel_i <= channel_i + 1;
        end
    end
    divide_add_out <= multiply;
    if ( divide_add_out ) begin // Conditional synthesis!
        m_sg_d_i <= sine_prev_sample +
            {{(INPUT_WIDTH-PW+SINE_HZ_STEP_SIZE_WIDTH){sample_product[PW-1]}},
                sample_product[PW-1:SINE_HZ_STEP_SIZE_WIDTH]};
        if ( 0 == sg_frequency ) begin
            m_sg_d_i <= 0;
        end
        m_sg_dv_i <= 1;
    end
    if ( !rst_n ) begin
        lookup_table <= 0;
        sample_out <= 0;
        repeat_lookup <= 0;
        calc_delta <= 0;
        multiply <= 0;
        divide_add_out <= 0;
        channel_i <= 0;
        m_sg_d_i <= 0;
        m_sg_ch_i <= 0;
        m_sg_dv_i <= 1;
        for ( j = 0; j < NR_CHANNELS; j = j + 1 ) begin
            sine_index[j] <= 0;
            sine_index_step[j] <= 1;
            frequency_index[j] <= 0;
        end
    end
end // sine_generator

assign sg_freq_ch = channel_i;
assign sg_freq_step = SINE_HZ_STEP_SIZE;
assign m_sg_d = m_sg_d_i;
assign m_sg_ch = m_sg_ch_i;
assign m_sg_dv = m_sg_dv_i;

endmodule // sine_wg_lin
