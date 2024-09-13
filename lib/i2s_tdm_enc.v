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
 *  Description: I2S TDM encoder
 *
 *  https://en.wikipedia.org/wiki/I%C2%B2S
 *  https://en.wikipedia.org/wiki/Time-division_multiplexing
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module i2s_tdm_enc #(
/*============================================================================*/
    parameter NR_CHANNELS = 4,
    parameter INPUT_WIDTH = 24,
    parameter [0:0] LRCLK_POLARITY = 1, // 0 = I2S, 1 = TDM
    parameter [0:0] LEFT_ALIGNED = 1, // 0 = I2S, 1 = TDM,
    parameter MCLK_BCLK_RATIO = 4 ) // Minimal 2 or 4, not 1 or 3
    (
    mclk, // Master clock
    bclk, // Bit clock
    lrclk, // Frame clock
    i2s_tdm, // Serial data line encoded
    // Channel output signals
    i2s_tdm_ch, i2s_tdm_chv, i2s_tdm_chr, // Channel, ch valid, ch ready
    // Data input signals
    i2s_tdm_d, i2s_tdm_dv, i2s_tdm_dr // Data, data valid, data ready
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
endfunction

localparam CHANNEL_WIDTH = clog2( NR_CHANNELS );

input wire mclk; // Master clock
input wire bclk; // Bit clock
input wire lrclk; // Frame clock
output wire i2s_tdm; // Serial data line
// Channel output signals
output wire [CHANNEL_WIDTH-1:0] i2s_tdm_ch;
output wire i2s_tdm_chv;
input wire i2s_tdm_chr;
// Data input signals
input wire [INPUT_WIDTH-1:0] i2s_tdm_d;
input wire i2s_tdm_dv;
output wire i2s_tdm_dr;

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( NR_CHANNELS < 2 ) begin
        $display( "NR_CHANNELS (%d) < 2!", NR_CHANNELS );
        $stop;
    end
    if ( INPUT_WIDTH < 8 ) begin
        $display( "INPUT_WIDTH smaller than one byte!" );
    end
    if (( MCLK_BCLK_RATIO <= 1 ) || ( MCLK_BCLK_RATIO == 3 )) begin
        $display( "MCLK_BCLK_RATIO error" );
        $stop;
    end
end // parameter_check

localparam [0:0] RIGHT_ALIGNED = 1 - LEFT_ALIGNED;
localparam BIT_COUNTER_WIDTH = clog2( INPUT_WIDTH + RIGHT_ALIGNED + 1 );

// The bclk level alternates for every mclk when mclk is twice the frequency as
// the bclk and actions should be done for the previous determined level.
localparam [0:0] MCLK_BCLK_RATIO_TWO = ( 2 == MCLK_BCLK_RATIO );

// Delayed clocks
reg lrclk_i = LRCLK_POLARITY;
reg bclk_i = 0;

// I/O bus signals
reg [INPUT_WIDTH-1:0] i2s_tdm_d_i = 0;
reg i2s_tdm_dv_i = 0;
reg i2s_tdm_dr_i = 0;
reg [CHANNEL_WIDTH-1:0] i2s_tdm_ch_i = 0;
reg i2s_tdm_chv_i = 0;
reg i2s_tdm_chr_i = 0;
reg active = 0;

// Bit counter and data input shift register
reg [BIT_COUNTER_WIDTH-1:0] bit_counter = 0;
reg [INPUT_WIDTH-1:0] data_out = 0;

// Process to encode serial I2S or TDM line
/*============================================================================*/
always @(posedge mclk) begin : encode_i2s_tdm
/*============================================================================*/
    i2s_tdm_dv_i <= i2s_tdm_dv; // Synchronize
    i2s_tdm_chr_i <= i2s_tdm_chr; // Synchronize
    i2s_tdm_chv_i <= i2s_tdm_chv_i & ~( i2s_tdm_chr_i | i2s_tdm_chr );
    lrclk_i <= lrclk;
    if ( lrclk != lrclk_i ) begin
        if ( LRCLK_POLARITY == lrclk ) begin
            if ( MCLK_BCLK_RATIO_TWO ) begin
                i2s_tdm_ch_i = 1;
                bit_counter = 1;
            end else begin
                i2s_tdm_ch_i = 0;
                bit_counter = INPUT_WIDTH;
            end
            active <= 1;
        end
    end else if ( !active ) begin
        bit_counter = 0;
        i2s_tdm_ch_i = 0;
    end
    bclk_i <= bclk;
    if ( bclk != bclk_i ) begin
        if (( !bclk && !MCLK_BCLK_RATIO_TWO ) || ( bclk && MCLK_BCLK_RATIO_TWO )) begin
            data_out <= {data_out[INPUT_WIDTH-2:0], 1'b0}; // Shift serial data out
            if (( INPUT_WIDTH + RIGHT_ALIGNED ) == bit_counter ) begin
                bit_counter = RIGHT_ALIGNED + 1;
                data_out <= i2s_tdm_d_i; // Get next data out
                if (( NR_CHANNELS - 1 ) == i2s_tdm_ch_i ) begin
                    i2s_tdm_ch_i = 0; // Always start at 0 when frame started
                end else begin
                    i2s_tdm_ch_i = i2s_tdm_ch_i + 1;
                end
                i2s_tdm_chv_i <= 1;
                i2s_tdm_dr_i <= 1;
            end else begin
                bit_counter = bit_counter + 1;
            end
        end
    end
    // Get next channel data
    if ( i2s_tdm_dv_i && i2s_tdm_dr_i ) begin
        i2s_tdm_d_i <= i2s_tdm_d;
        i2s_tdm_dr_i <= 0;
    end
end // encode_i2s_tdm

// Set TDM/I2S signal
assign i2s_tdm = data_out[INPUT_WIDTH-1];

// Set AXIS signals
assign i2s_tdm_ch = i2s_tdm_ch_i;
assign i2s_tdm_chv = i2s_tdm_chv_i;
assign i2s_tdm_dr = i2s_tdm_dv_i & i2s_tdm_dr_i;
assign i2s_tdm_chv = i2s_tdm_chv_i;

endmodule
