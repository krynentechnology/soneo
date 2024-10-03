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
 *  Description: Randomizer, periodic noise generator
 *
 *  https://en.wikipedia.org/wiki/Linear-feedback_shift_register
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module randomizer #(
/*============================================================================*/
    parameter NR_CHANNELS = 1,
    parameter OUTPUT_WIDTH = 32 )
    (
    clk,
    rndm_ch, // Channel
    rndm_seed, // Initial random value (seed)
    rndm_init, // Initial seed valid
    rndm_out,
    rndm_ready // Ready for random generated output
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
endfunction // clog2

localparam CHANNEL_WIDTH = clog2( NR_CHANNELS );

input  wire clk;
input  wire [CHANNEL_WIDTH-1:0] rndm_ch;
input  wire [OUTPUT_WIDTH-1:0] rndm_seed;
input  wire rndm_init;
output reg  [OUTPUT_WIDTH-1:0] rndm_out;
input  wire rndm_ready;

localparam COUNTER_WIDTH = clog2( OUTPUT_WIDTH );

reg [OUTPUT_WIDTH-1:0] lfsr;
reg [OUTPUT_WIDTH-1:0] lfsr_i;
reg [OUTPUT_WIDTH-1:0] lfsr_ch[0:NR_CHANNELS-1];
reg [OUTPUT_WIDTH-2:0] LFSR_TAP; // Constant, see init_lsfr_tap!
reg [COUNTER_WIDTH-1:0] i;

/*============================================================================*/
initial begin // Parameter checks
/*============================================================================*/
    if ( OUTPUT_WIDTH < 3 ) begin
        $display( "Invalid OUTPUT_WIDTH = %d", OUTPUT_WIDTH );
        $finish;
    end
    if ( COUNTER_WIDTH > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )) begin
        $display( "COUNTER_WIDTH > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )!" );
        $finish;
    end
end

/*============================================================================*/
always @(posedge clk) begin : noise_generator
/*============================================================================*/
    if ( rndm_ready && ( rndm_ch < NR_CHANNELS )) begin
        lfsr_i = lfsr_ch[rndm_ch];
        lfsr[OUTPUT_WIDTH-1] = lfsr_i[0];
        for ( i = OUTPUT_WIDTH - 1; i > 0; i = i - 1 ) begin
            lfsr[i-1] = lfsr_i[i];
            if ( LFSR_TAP[i] ) begin
                lfsr[i-1] = lfsr_i[i] ~^ lfsr_i[0]; // Galois LFSR
            end
        end
        if ( &lfsr ) begin // Prevent lock-up state!
            lfsr = 0;
        end
        lfsr_ch[rndm_ch] <= lfsr;
        rndm_out <= lfsr;
    end
    if ( rndm_init ) begin
        lfsr_ch[rndm_ch] <= rndm_seed;
    end
end // noise_generator

integer n = 0;
/*============================================================================*/
initial begin : init_lsfr_tap
/*============================================================================*/
    for ( n = 0; n < NR_CHANNELS; n = n + 1 ) begin
        lfsr_ch[n] = 0;
    end
    // Tap points to insert XNOR gates as feedback, (2^OUTPUT_WIDTH)-1 numbers are
    // cycled through before the sequence is repeated (see Xilinx XAPP052)
    LFSR_TAP[OUTPUT_WIDTH-2:0] = 0;
    case ( OUTPUT_WIDTH )
        3  : begin LFSR_TAP[2] = 1'b1; end
        4  : begin LFSR_TAP[3] = 1'b1; end
        5  : begin LFSR_TAP[3] = 1'b1; end
        6  : begin LFSR_TAP[5] = 1'b1; end
        7  : begin LFSR_TAP[6] = 1'b1; end
        8  : begin LFSR_TAP[6] = 1'b1; LFSR_TAP[5] = 1'b1; LFSR_TAP[4] = 1'b1; end
        9  : begin LFSR_TAP[5] = 1'b1; end
        10 : begin LFSR_TAP[7] = 1'b1; end
        11 : begin LFSR_TAP[9] = 1'b1; end
        12 : begin LFSR_TAP[6] = 1'b1; LFSR_TAP[4] = 1'b1; LFSR_TAP[1] = 1'b1; end
        13 : begin LFSR_TAP[4] = 1'b1; LFSR_TAP[3] = 1'b1; LFSR_TAP[1] = 1'b1; end
        14 : begin LFSR_TAP[5] = 1'b1; LFSR_TAP[3] = 1'b1; LFSR_TAP[1] = 1'b1; end
        15 : begin LFSR_TAP[14] = 1'b1; end
        16 : begin LFSR_TAP[15] = 1'b1; LFSR_TAP[13] = 1'b1; LFSR_TAP[4] = 1'b1; end
        17 : begin LFSR_TAP[14] = 1'b1; end
        18 : begin LFSR_TAP[11] = 1'b1; end
        19 : begin LFSR_TAP[6] = 1'b1; LFSR_TAP[2] = 1'b1; LFSR_TAP[1] = 1'b1; end
        20 : begin LFSR_TAP[17] = 1'b1; end
        21 : begin LFSR_TAP[19] = 1'b1; end
        22 : begin LFSR_TAP[21] = 1'b1; end
        23 : begin LFSR_TAP[18] = 1'b1; end
        24 : begin LFSR_TAP[23] = 1'b1; LFSR_TAP[22] = 1'b1; LFSR_TAP[17] = 1'b1; end
        25 : begin LFSR_TAP[22] = 1'b1; end
        26 : begin LFSR_TAP[6] = 1'b1; LFSR_TAP[2] = 1'b1; LFSR_TAP[1] = 1'b1; end
        27 : begin LFSR_TAP[5] = 1'b1; LFSR_TAP[2] = 1'b1; LFSR_TAP[1] = 1'b1; end
        28 : begin LFSR_TAP[25] = 1'b1; end
        29 : begin LFSR_TAP[27] = 1'b1; end
        30 : begin LFSR_TAP[6] = 1'b1; LFSR_TAP[4] = 1'b1; LFSR_TAP[1] = 1'b1; end
        31 : begin LFSR_TAP[28] = 1'b1; end
        32 : begin LFSR_TAP[22] = 1'b1; LFSR_TAP[2] = 1'b1; LFSR_TAP[1] = 1'b1; end
        33 : begin LFSR_TAP[20] = 1'b1; end
        34 : begin LFSR_TAP[27] = 1'b1; LFSR_TAP[2] = 1'b1; LFSR_TAP[1] = 1'b1; end
        35 : begin LFSR_TAP[33] = 1'b1; end
        36 : begin LFSR_TAP[25] = 1'b1; end
        37 : begin LFSR_TAP[5] = 1'b1; LFSR_TAP[4] = 1'b1; LFSR_TAP[3] = 1'b1; LFSR_TAP[2] = 1'b1; LFSR_TAP[1] = 1'b1; end
        38 : begin LFSR_TAP[6] = 1'b1; LFSR_TAP[5] = 1'b1; LFSR_TAP[1] = 1'b1; end
        39 : begin LFSR_TAP[35] = 1'b1; end
        40 : begin LFSR_TAP[38] = 1'b1; LFSR_TAP[21] = 1'b1; LFSR_TAP[19] = 1'b1; end
        41 : begin LFSR_TAP[38] = 1'b1; end
        42 : begin LFSR_TAP[41] = 1'b1; LFSR_TAP[20] = 1'b1; LFSR_TAP[19] = 1'b1; end
        43 : begin LFSR_TAP[42] = 1'b1; LFSR_TAP[38] = 1'b1; LFSR_TAP[37] = 1'b1; end
        44 : begin LFSR_TAP[43] = 1'b1; LFSR_TAP[18] = 1'b1; LFSR_TAP[17] = 1'b1; end
        45 : begin LFSR_TAP[44] = 1'b1; LFSR_TAP[42] = 1'b1; LFSR_TAP[41] = 1'b1; end
        46 : begin LFSR_TAP[45] = 1'b1; LFSR_TAP[26] = 1'b1; LFSR_TAP[25] = 1'b1; end
        47 : begin LFSR_TAP[42] = 1'b1; end
        48 : begin LFSR_TAP[47] = 1'b1; LFSR_TAP[21] = 1'b1; LFSR_TAP[20] = 1'b1; end
        49 : begin LFSR_TAP[40] = 1'b1; end
        50 : begin LFSR_TAP[49] = 1'b1; LFSR_TAP[24] = 1'b1; LFSR_TAP[23] = 1'b1; end
        51 : begin LFSR_TAP[50] = 1'b1; LFSR_TAP[36] = 1'b1; LFSR_TAP[35] = 1'b1; end
        52 : begin LFSR_TAP[49] = 1'b1; end
        53 : begin LFSR_TAP[52] = 1'b1; LFSR_TAP[38] = 1'b1; LFSR_TAP[37] = 1'b1; end
        54 : begin LFSR_TAP[53] = 1'b1; LFSR_TAP[18] = 1'b1; LFSR_TAP[17] = 1'b1; end
        55 : begin LFSR_TAP[31] = 1'b1; end
        56 : begin LFSR_TAP[55] = 1'b1; LFSR_TAP[35] = 1'b1; LFSR_TAP[34] = 1'b1; end
        57 : begin LFSR_TAP[50] = 1'b1; end
        58 : begin LFSR_TAP[39] = 1'b1; end
        59 : begin LFSR_TAP[58] = 1'b1; LFSR_TAP[38] = 1'b1; LFSR_TAP[37] = 1'b1; end
        60 : begin LFSR_TAP[59] = 1'b1; end
        61 : begin LFSR_TAP[60] = 1'b1; LFSR_TAP[46] = 1'b1; LFSR_TAP[45] = 1'b1; end
        62 : begin LFSR_TAP[61] = 1'b1; LFSR_TAP[6] = 1'b1; LFSR_TAP[5] = 1'b1; end
        63 : begin LFSR_TAP[62] = 1'b1; end
        64 : begin LFSR_TAP[63] = 1'b1; LFSR_TAP[61] = 1'b1; LFSR_TAP[60] = 1'b1; end
    endcase
    if ( !LFSR_TAP[OUTPUT_WIDTH-2:0] ) begin
        $display( "Invalid LFSR_TAP = %b" , LFSR_TAP );
        $finish;
    end
end // init_lsfr_tap

endmodule
