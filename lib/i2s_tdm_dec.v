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
 *  Description: I2S TDM decoder
 *
 *  https://en.wikipedia.org/wiki/I%C2%B2S
 *  https://en.wikipedia.org/wiki/Time-division_multiplexing
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module i2s_tdm_dec #(
/*============================================================================*/
    parameter NR_CHANNELS = 4,
    parameter OUTPUT_WIDTH = 24,
    parameter [0:0] LRCLK_POLARITY = 1, // 0 = I2S, 1 = TDM
    parameter [0:0] LEFT_ALIGNED = 1, // 0 = I2S, 1 = TDM,
    parameter MCLK_BCLK_RATIO = 4 ) // Minimal 2 or 4, not 1 or 3
    (
    mclk, // Master clock
    bclk, // Bit clock
    lrclk, // Frame clock
    i2s_tdm, // Serial data line to decode
    i2s_tdm_d, // Data
    i2s_tdm_ch, // Channel
    i2s_tdm_dv, // Data valid
    i2s_tdm_dr // Data ready
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
input wire i2s_tdm; // Serial data line
output wire [OUTPUT_WIDTH-1:0] i2s_tdm_d;
output wire [CHANNEL_WIDTH-1:0] i2s_tdm_ch;
output wire i2s_tdm_dv;
input  wire i2s_tdm_dr;

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( NR_CHANNELS < 2 ) begin
        $display( "NR_CHANNELS (%d) error", NR_CHANNELS );
        $finish;
    end
    if ( OUTPUT_WIDTH < 8 ) begin
        $display( "OUTPUT_WIDTH smaller than one byte!" );
    end
    if (( MCLK_BCLK_RATIO < 2 ) || ( MCLK_BCLK_RATIO == 3 )) begin
        $display( "MCLK_BCLK_RATIO error" );
        $finish;
    end
end // parameter_check

localparam [0:0] RIGHT_ALIGNED = 1 - LEFT_ALIGNED;
localparam BIT_COUNTER_WIDTH = clog2( OUTPUT_WIDTH + RIGHT_ALIGNED + 1 );

// If mclk is twice the frequency as the bclk, the bclk level alternates for
// every mclk and actions should be done for the previous determined level.
localparam [0:0] MCLK_BCLK_RATIO_TWO = ( MCLK_BCLK_RATIO == 2 );

// Delayed clocks
reg lrclk_i = LRCLK_POLARITY;
reg bclk_i = 0;

// AXIS signals
reg [OUTPUT_WIDTH-1:0] i2s_tdm_d_i = 0;
reg [CHANNEL_WIDTH-1:0] i2s_tdm_ch_i = 0;
reg i2s_tdm_dv_i = 0;
reg i2s_tdm_dr_i = 0;
reg active = 0;

// Bit counter and data input shift register
reg [BIT_COUNTER_WIDTH-1:0] bit_counter = 0;
reg [OUTPUT_WIDTH-1:0] data_in = 0;

// Process to decode serial TDMx or I2S line
/*============================================================================*/
always @(posedge mclk) begin : decode_i2s_tdm
/*============================================================================*/
    i2s_tdm_dr_i <= i2s_tdm_dr;  // Synchronize
    i2s_tdm_dv_i <= i2s_tdm_dv_i & ~( i2s_tdm_dr_i | i2s_tdm_dr );
    lrclk_i <= lrclk;
    if ( lrclk != lrclk_i ) begin
        if ( lrclk == LRCLK_POLARITY ) begin
            i2s_tdm_ch_i = NR_CHANNELS - 1;
            bit_counter = OUTPUT_WIDTH;
            active <= 1;
        end
    end else if ( !active ) begin
        i2s_tdm_ch_i = 0;
        bit_counter = 0;
    end
    bclk_i <= bclk;
    if ( bclk != bclk_i ) begin
        if (( bclk && !MCLK_BCLK_RATIO_TWO ) || ( !bclk && MCLK_BCLK_RATIO_TWO )) begin
            data_in[OUTPUT_WIDTH-1:1] = data_in[OUTPUT_WIDTH-2:0];
            data_in[0] = i2s_tdm; // Shift serial data in
            if (( OUTPUT_WIDTH + RIGHT_ALIGNED ) == bit_counter ) begin
                bit_counter = RIGHT_ALIGNED + 1;
                if (( NR_CHANNELS - 1 ) == i2s_tdm_ch_i ) begin
                    i2s_tdm_ch_i = 0; // Always start at 0 when frame started
                end else begin
                    i2s_tdm_ch_i = i2s_tdm_ch_i + 1;
                end
            end else begin
                bit_counter = bit_counter + 1;
            end
        end
        if (( !bclk && !MCLK_BCLK_RATIO_TWO ) || ( bclk && MCLK_BCLK_RATIO_TWO )) begin
            if (( OUTPUT_WIDTH + RIGHT_ALIGNED ) == bit_counter ) begin // (MSB = 1st/2nd bit after LRCLK)
                i2s_tdm_d_i <= data_in;
                i2s_tdm_dv_i <= 1;
            end
        end
    end
end // decode_i2s_tdm

// Set output signals
assign i2s_tdm_d = i2s_tdm_d_i;
assign i2s_tdm_ch = i2s_tdm_ch_i;
assign i2s_tdm_dv = i2s_tdm_dv_i;

endmodule // i2s_tdm_dec
