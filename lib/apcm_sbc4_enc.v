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
 *
 *  APCM SCB4 encoder to process 32 16-bit samples into a 20 byte (160 bit) APCM
 *  packet (downsampling by four, 32 -> 8, 8 sets of four subbands processed).
 *  The first two packet bytes (16-bit word) contain the four 4-bit scale
 *  factors (S0/S1/S2/S3). The last two packet bytes are reserved for an
 *  authentication/CRC 16-bit input which is appended.
 *
 *  The channel number (m_apcm_tid) is not included in the APCM packet! The
 *  number of channels supported depends on the clock speed (clk) and synthesis
 *  of the configured single block RAM size (E.g. 256x36 -> 512x18), which could
 *  be extended to multiple block RAMs (by modification).
 *  The generation of the authentication/CRC 16-bit value is not part of this
 *  module. AES-128 external encryption of the eight 16-bit SBC4/APCM processed
 *  samples result is optional (aes_enable = 1).
 *
 *  APCM/SBC4 encoding is described in the Bluetooth A2DP specification:
 *  https://www.bluetooth.com/specifications/specs/. A software implementation
 *  can be found in the ffmpeg library (libavcodec\sbc*): https://ffmpeg.org/
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module apcm_sbc4_enc #(
    parameter NR_CHANNELS = 3,
    parameter COEFF_WIDTH = 18,
    parameter BLOCK_RAM_SIZE = 512 )
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    s_tdata, s_tid, s_tvalid, s_tready, // Samples input
    aes_enable, // AES-128 encryption enable input
    m_aes_tdata, m_aes_tid, m_aes_tvalid, m_aes_tready, // 128-bit SBC4/APCM processed samples output
    s_aes_tdata, s_aes_tvalid, s_aes_tready, // 128-bit encryption input
    auth_crc, // Authentication/CRC input
    apcm_sop, // APCM start of packet output
    m_apcm_tdata, m_apcm_tid, m_apcm_tvalid, m_apcm_tready, // APCM packet output
    overflow // For test purposes
    );

localparam MAX_CLOG2_WIDTH = 16;
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
localparam INPUT_WIDTH = 16;
localparam [5:0] BIT_POOL = 16;

input  wire clk;
input  wire rst_n;
input  wire [INPUT_WIDTH-1:0] s_tdata;
input  wire [CHANNEL_WIDTH-1:0] s_tid;
input  wire s_tvalid;
output wire s_tready;
input  wire aes_enable;
output wire [127:0] m_aes_tdata;
output wire [CHANNEL_WIDTH-1:0] m_aes_tid;
output wire m_aes_tvalid;
input  wire m_aes_tready;
input  wire [127:0] s_aes_tdata;
input  wire s_aes_tvalid;
output wire s_aes_tready;
input  wire [INPUT_WIDTH-1:0] auth_crc;
output wire apcm_sop; // Start of APCM packet
output wire [7:0] m_apcm_tdata; // Byte output
output wire [CHANNEL_WIDTH-1:0] m_apcm_tid;
output wire m_apcm_tvalid;
input  wire m_apcm_tready;
output wire overflow;

localparam real FACTOR_1 = ( 2.0 ** ( COEFF_WIDTH - 1 )) - 1;
// Prototype filter coefficients, add or subtract 0.5 for correct rounding
localparam real PTC1  = ( 5.3654897628474e-04 * FACTOR_1 ) + 0.5;
localparam real PTC2  = ( 1.4918835706273e-03 * FACTOR_1 ) + 0.5;
localparam real PTC3  = ( 2.7337090367926e-03 * FACTOR_1 ) + 0.5;
localparam real PTC4  = ( 3.8372019280091e-03 * FACTOR_1 ) + 0.5;
localparam real PTC5  = ( 3.8920514850040e-03 * FACTOR_1 ) + 0.5;
localparam real PTC6  = ( 1.8658169061497e-03 * FACTOR_1 ) + 0.5;
localparam real PTC7  = ( -3.0601228600951e-03 * FACTOR_1 ) - 0.5;
localparam real PTC8  = ( -1.0913762016690e-02 * FACTOR_1 ) - 0.5;
localparam real PTC9  = ( -2.0438508719161e-02 * FACTOR_1 ) - 0.5;
localparam real PTC10 = ( -2.8875739180821e-02 * FACTOR_1 ) - 0.5;
localparam real PTC11 = ( -3.2193928982763e-02 * FACTOR_1 ) - 0.5;
localparam real PTC12 = ( -2.5876781146790e-02 * FACTOR_1 ) - 0.5;
localparam real PTC13 = ( -6.1324518594809e-03 * FACTOR_1 ) - 0.5;
localparam real PTC14 = ( 2.8821727426597e-02 * FACTOR_1 ) + 0.5;
localparam real PTC15 = ( 7.7646349365466e-02 * FACTOR_1 ) + 0.5;
localparam real PTC16 = ( 1.3559327369645e-01 * FACTOR_1 ) + 0.5;
localparam real PTC17 = ( 1.9498784104769e-01 * FACTOR_1 ) + 0.5;
localparam real PTC18 = ( 2.4663666230909e-01 * FACTOR_1 ) + 0.5;
localparam real PTC19 = ( 2.8182820289485e-01 * FACTOR_1 ) + 0.5;
localparam real PTC20 = ( 2.9431533161836e-01 * FACTOR_1 ) + 0.5;

localparam real COS_45 = ( 7.0710678118655e-01 * FACTOR_1 ) + 0.5;
localparam signed [COEFF_WIDTH-1:0] cosine_a = COS_45;
localparam real COS_22_5 = ( 9.2387953251129e-01 * FACTOR_1 ) + 0.5;
localparam signed [COEFF_WIDTH-1:0] cosine_b = COS_22_5;
localparam real COS_67_5 = ( 3.8268343236509e-01 * FACTOR_1 ) + 0.5;
localparam signed [COEFF_WIDTH-1:0] cosine_c = COS_67_5;
localparam real COS_0 = FACTOR_1; // == 1!
localparam signed [COEFF_WIDTH-1:0] cosine_d = COS_0; // Not used!
localparam real COS_90 = 0;
localparam signed [COEFF_WIDTH-1:0] cosine_e = COS_90; // Not used!

// FIR filter coefficients
localparam NR_COEFF = 40;
(* rom_style = "block" *) // Synthesis likely will select "distributed"
reg signed [COEFF_WIDTH-1:0] filter[0:NR_COEFF-1];
/*============================================================================*/
initial begin
/*============================================================================*/
    filter[0]  = 0;
    filter[1]  = PTC1;
    filter[2]  = PTC2;
    filter[3]  = PTC3;
    filter[4]  = PTC4;
    filter[5]  = -PTC5;
    filter[6]  = PTC6;
    filter[7]  = PTC7;
    filter[8]  = -PTC8;
    filter[9]  = -PTC9;
    filter[10] = -PTC10;
    filter[11] = -PTC11;
    filter[12] = -PTC12;
    filter[13] = PTC13;
    filter[14] = -PTC14;
    filter[15] = -PTC15;
    filter[16] = PTC16;
    filter[17] = PTC17;
    filter[18] = PTC18;
    filter[19] = PTC19;
    filter[20] = PTC20;
    filter[21] = -PTC19;
    filter[22] = PTC18;
    filter[23] = PTC17;
    filter[24] = -PTC16;
    filter[25] = -PTC15;
    filter[26] = -PTC14;
    filter[27] = -PTC13;
    filter[28] = -PTC12;
    filter[29] = PTC11;
    filter[30] = -PTC10;
    filter[31] = -PTC9;
    filter[32] = PTC8;
    filter[33] = PTC7;
    filter[34] = PTC6;
    filter[35] = PTC5;
    filter[36] = PTC4;
    filter[37] = -PTC3;
    filter[38] = PTC2;
    filter[39] = PTC1;
end

// Intermediate registers
reg s_tready_i = 1;
reg signed [INPUT_WIDTH:0] sb_0_i = 0;
reg signed [INPUT_WIDTH:0] sb_1_i = 0;
reg signed [INPUT_WIDTH:0] sb_2_i = 0;
reg signed [INPUT_WIDTH:0] sb_3_i = 0;
reg [CHANNEL_WIDTH-1:0] sb_tid = 0;
reg [CHANNEL_WIDTH-1:0] sb_tid_i = 0;
reg sb_tvalid_i = 0;
reg [1:0] sb4_count[0:NR_CHANNELS-1];
reg signed [INPUT_WIDTH:0] y0y4 = 0;
reg signed [INPUT_WIDTH:0] y2 = 0;
reg signed [INPUT_WIDTH:0] y1y3 = 0;
reg signed [INPUT_WIDTH:0] y5y7 = 0;
reg signed [INPUT_WIDTH:0] e0 = 0;
reg signed [INPUT_WIDTH:0] e1 = 0;
reg signed [INPUT_WIDTH:0] o0 = 0;
reg signed [INPUT_WIDTH:0] o1 = 0;

// Intermediate registers for summation and multiplication
reg signed [INPUT_WIDTH:0] p_arg_1 = 0;
reg signed [COEFF_WIDTH-1:0] p_arg_2 = 0;

// Boolean states
reg s0 = 0; // Six zero one hot stages s0-s5
reg s1 = 0;
reg s2 = 0;
reg s3 = 0;
reg s4 = 0;
reg s5 = 0;

// Registers
parameter NR_COEFF_WIDTH = clog2( NR_COEFF );
reg [NR_COEFF_WIDTH-1:0] fir_index = 0;
reg signed [COEFF_WIDTH-1:0] fir_coefficient = 0;
// SBC4 RAM data
localparam SBC4_NR_RAM_ELEMENTS = NR_CHANNELS * NR_COEFF;
localparam NR_RAM_ELEMENTS_WIDTH = clog2( SBC4_NR_RAM_ELEMENTS );
(* ram_style = "block" *)
reg signed [INPUT_WIDTH-1:0] sb4_ram_data[0:SBC4_NR_RAM_ELEMENTS-1];

/*============================================================================*/
initial begin : sbc4_param_check
/*============================================================================*/
    if ( SBC4_NR_RAM_ELEMENTS > BLOCK_RAM_SIZE ) begin
        $display( "SBC4_NR_RAM_ELEMENTS exceeds %d (block RAM size)", BLOCK_RAM_SIZE );
        $finish;
    end
    if ( NR_COEFF % 2 != 0 ) begin
        $display( "NR_COEFF should be an even number" );
        $finish;
    end
    if ( COEFF_WIDTH < INPUT_WIDTH + 2 ) begin
        $display( "COEFF_WIDTH < INPUT_WIDTH + 2!" );
        $finish;
    end
end // sbc4_param_check

integer i;
/*============================================================================*/
initial begin : sb4_ram_init // Initialize SB4 block RAM
/*============================================================================*/
    for ( i = 0; i < SBC4_NR_RAM_ELEMENTS; i = i + 1 ) begin
        sb4_ram_data[i] = 0;
    end
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        sb4_count[i] = 0;
    end
end // sb4_ram_init

reg [NR_RAM_ELEMENTS_WIDTH-1:0] sb4_ram_rd_index = 0;
reg [NR_RAM_ELEMENTS_WIDTH-1:0] sb4_ram_wr_index = 0;
reg signed [INPUT_WIDTH-1:0] sb4_ram_rd_data = 0;
reg signed [INPUT_WIDTH-1:0] sb4_ram_wr_data = 0;
reg sb4_ram_wr_enable = 0;
reg delay_block_ram_read = 0;

// Test signals
wire overflow_cos;
wire overflow_fir;

// Combinatorial registers
reg fir_r2z;
reg signed [INPUT_WIDTH+COEFF_WIDTH-1:0] fir_product;
reg cos_r2z;
reg signed [INPUT_WIDTH+COEFF_WIDTH:0] cos_product;
reg [2:0] modula_index;

/*============================================================================*/
always @(posedge clk) begin : block_ram
/*============================================================================*/
    if ( sb4_ram_wr_enable ) begin
        sb4_ram_data[sb4_ram_wr_index] <= sb4_ram_wr_data;
    end
    // Read-first mode
    sb4_ram_rd_data <= sb4_ram_data[sb4_ram_rd_index];
end // block_ram

/*============================================================================*/
always @(posedge clk) begin : sbc4_analysis
/*============================================================================*/
    if ( sb4_ram_rd_index < ( SBC4_NR_RAM_ELEMENTS - 1 )) begin
        sb4_ram_rd_index <= sb4_ram_rd_index + 1;
    end
    sb4_ram_wr_data <= sb4_ram_rd_data;
    sb4_ram_wr_index <= sb4_ram_rd_index;
    if ( s_tvalid && s_tready_i && ( s_tid < NR_CHANNELS )) begin
        sb4_ram_wr_data <= $signed( s_tdata );
        sb_tid_i <= s_tid;
        s_tready_i <= 0;
        for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
            if ( i == s_tid ) begin
                sb4_ram_rd_index <= NR_COEFF * i;
            end
        end
        delay_block_ram_read <= 1;
    end
    if ( delay_block_ram_read ) begin // Block RAM reads are one clock cycle delayed!
        sb4_ram_wr_enable <= 1;
        if ( sb4_ram_wr_enable ) begin
            fir_index <= 1; // fir_index == 0 is skipped! filter(0) == 0!
            delay_block_ram_read <= 0;
        end
        else begin
            sb4_ram_wr_data <= sb4_ram_wr_data; // Copy sb4_ram_wr_data - valid s_tdata!
        end
    end
    s0 <= 0; // Clocked pulse
    // FIR processing
    if ( fir_index != 0 ) begin
        if (( NR_COEFF - 1 ) == fir_index ) begin
            fir_index <= 0; // Stop FIR processing, next clycle all coefficients done
            sb_tid <= sb_tid_i;
            s0 <= 1;
            sb_tvalid_i <= 0; // Reset sb_tvalid
            s_tready_i <= 1;
            p_arg_1 <= y0y4;
            p_arg_2 <= cosine_a;
            sb4_ram_wr_enable <= 0; // Stop RAM writes
            y0y4 <= 0; // Reset for next sample
        end
        else begin
            fir_index <= fir_index + 1;
        end
        if ( 0 == modula_index || 4 == modula_index ) begin
            y0y4 <= y0y4 + fir_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        end
        if ( 1 == modula_index || 3 == modula_index ) begin
            y1y3 <= y1y3 + fir_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        end
        if ( 2 == modula_index ) begin
            y2 <= y2 + fir_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        end
        if ( 5 == modula_index || 7 == modula_index ) begin
            y5y7 <= y5y7 + fir_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        end
    end
    if ( s0 ) begin
        e0 <= y2 + cos_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        e1 <= y2 - cos_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        p_arg_1 <= y1y3;
        p_arg_2 <= cosine_c;
        y1y3 <= 0; // Reset for next sample
        y2 <= 0; // Reset for next sample
    end
    s1 <= s0;
    if ( s1 ) begin
        o1 <= cos_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        p_arg_2 <= cosine_b;
    end
    s2 <= s1;
    if ( s2 ) begin
        o0 <= cos_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        p_arg_1 <= y5y7;
        y5y7 <= 0; // Reset for next sample
    end
    s3 <= s2;
    if ( s3 ) begin
        o1 <= o1 + cos_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        p_arg_2 <= cosine_c;
    end
    s4 <= s3;
    if ( s4 ) begin
        o0 <= o0 - cos_product[INPUT_WIDTH+COEFF_WIDTH-1:COEFF_WIDTH-1];
        sb_1_i <= e1 + o1; // out1
        sb_2_i <= e1 - o1; // out2
    end
    s5 <= s4;
    if ( s5 ) begin // Final output stage
        sb_0_i <= e0 + o0; // out0
        sb_3_i <= e0 - o0; // out3
    end
    sb_tvalid_i <= s5;
    if ( sb_tvalid_i ) begin
        sb4_count[sb_tid] <= sb4_count[sb_tid] + 1;
    end
    if ( !rst_n ) begin
        s_tready_i <= 1;
        delay_block_ram_read <= 0;
        fir_index <= 0;
        s0 <= 0;
        s1 <= 0;
        s2 <= 0;
        s3 <= 0;
        s4 <= 0;
        s5 <= 0;
    end
end // sbc4_analysis

/*============================================================================*/
always @(*) begin : sbc4_analysis_combinatorial
/*============================================================================*/
    // FIR processing
    fir_coefficient = filter[fir_index];
    fir_r2z = sb4_ram_rd_data[INPUT_WIDTH-1] ^ fir_coefficient[COEFF_WIDTH-1]; // Sign of fir_product
    fir_product = ( sb4_ram_rd_data * fir_coefficient ) + // Round to zero fir_product
        $signed( {{(INPUT_WIDTH+1){1'b0}}, {(COEFF_WIDTH-1){fir_r2z}}} );
    modula_index = fir_index % 8;
    // Cosine modulation
    cos_r2z = p_arg_1[INPUT_WIDTH] ^ p_arg_2[COEFF_WIDTH-1]; // Sign of cos_product
    cos_product = ( p_arg_1 * p_arg_2 ) +  // Round to zero cos_product
        $signed( {{(INPUT_WIDTH+2){1'b0}}, {(COEFF_WIDTH-1){cos_r2z}}} );
end // sbc4_analysis_combinatorial

assign s_tready = s_tready_i;

// Signals to bitpool
wire [INPUT_WIDTH-1:0] sb_0;
wire [INPUT_WIDTH-1:0] sb_1;
wire [INPUT_WIDTH-1:0] sb_2;
wire [INPUT_WIDTH-1:0] sb_3;
wire sb_tvalid;

localparam [INPUT_WIDTH-2:0] ALL_ZERO = 0; // 00000...
localparam [INPUT_WIDTH-2:0] ALL_ONES = -1; // 11111...

assign sb_0[INPUT_WIDTH-1] = sb_0_i[INPUT_WIDTH]; // Copy sign, check for overflow!
assign sb_0[INPUT_WIDTH-2:0] =
    (2'b10 == sb_0_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ZERO : // Maximum negative
    (2'b01 == sb_0_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ONES : // Maximum positive
    sb_0_i[INPUT_WIDTH-2:0];
assign sb_1[INPUT_WIDTH-1] = sb_1_i[INPUT_WIDTH]; // Copy sign, check for overflow!
assign sb_1[INPUT_WIDTH-2:0] =
    (2'b10 == sb_1_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ZERO : // Maximum negative
    (2'b01 == sb_1_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ONES : // Maximum positive
    sb_1_i[INPUT_WIDTH-2:0];
assign sb_2[INPUT_WIDTH-1] = sb_2_i[INPUT_WIDTH]; // Copy sign, check for overflow!
assign sb_2[INPUT_WIDTH-2:0] =
    (2'b10 == sb_2_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ZERO : // Maximum negative
    (2'b01 == sb_2_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ONES : // Maximum positive
    sb_2_i[INPUT_WIDTH-2:0];
assign sb_3[INPUT_WIDTH-1] = sb_3_i[INPUT_WIDTH]; // Copy sign, check for overflow!
assign sb_3[INPUT_WIDTH-2:0] =
    (2'b10 == sb_3_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ZERO : // Maximum negative
    (2'b01 == sb_3_i[INPUT_WIDTH:INPUT_WIDTH-1]) ? ALL_ONES : // Maximum positive
    sb_3_i[INPUT_WIDTH-2:0];
assign sb_tvalid = sb_tvalid_i & ~( |sb4_count[sb_tid] ); // Downsampling

// Test signals for simulation
assign overflow_cos = ( sb_0_i[INPUT_WIDTH] ^ sb_0_i[INPUT_WIDTH-1] ) |
        ( sb_1_i[INPUT_WIDTH] ^ sb_1_i[INPUT_WIDTH-1] ) |
        ( sb_2_i[INPUT_WIDTH] ^ sb_2_i[INPUT_WIDTH-1] ) |
        ( sb_3_i[INPUT_WIDTH] ^ sb_3_i[INPUT_WIDTH-1] );
assign overflow_fir = ( y0y4[INPUT_WIDTH] ^ y0y4[INPUT_WIDTH-1] ) |
        ( y2[INPUT_WIDTH] ^ y2[INPUT_WIDTH-1] ) |
        ( y1y3[INPUT_WIDTH] ^ y1y3[INPUT_WIDTH-1] ) |
        ( y5y7[INPUT_WIDTH] ^ y5y7[INPUT_WIDTH-1] );
assign overflow = overflow_cos | overflow_fir;

reg [CHANNEL_WIDTH-1:0] apcm_wr_tid = 0;
reg [CHANNEL_WIDTH-1:0] apcm_rd_tid = 0;
reg [CHANNEL_WIDTH-1:0] m_apcm_tid_i = 0;
reg m_apcm_tvalid_i = 0;
reg m_apcm_tready_i = 0;

// APCM RAM subband data
localparam APCM_CH_NR_RAM_ELEMENTS = 64; // 2 alternating buffers * 8 samples * 4 subband values
localparam APCM_CH_NR_RAM_ELEMENTS_WIDTH = clog2( APCM_CH_NR_RAM_ELEMENTS );
localparam APCM_NR_RAM_ELEMENTS = APCM_CH_NR_RAM_ELEMENTS * NR_CHANNELS;
(* ram_style = "block" *)
reg signed [INPUT_WIDTH-1:0] apcm_ram_data[0:APCM_NR_RAM_ELEMENTS-1];

/*============================================================================*/
initial begin : apcm_param_check
/*============================================================================*/
    if ( APCM_NR_RAM_ELEMENTS > BLOCK_RAM_SIZE ) begin
        $display( "APCM_NR_RAM_ELEMENTS exceeds %d (block RAM size)", BLOCK_RAM_SIZE );
        $finish;
    end
    if ( APCM_CH_NR_RAM_ELEMENTS_WIDTH != 6 ) begin
        $display( "APCM_CH_NR_RAM_ELEMENTS_WIDTH should be 6, 2^6 = 64" );
        $finish;
    end
    if (( INPUT_WIDTH != 16 ) || ( BIT_POOL != 16 )) begin
        $display( "Only INPUT_WIDTH/BIT_POOL = 16 supported!" );
        $finish;
    end
end // apcm_param_check

/*============================================================================*/
initial begin : apcm_ram_init // Initialize block RAM
/*============================================================================*/
    for (i = 0; i < APCM_NR_RAM_ELEMENTS; i = i + 1)
        apcm_ram_data[i] = 0;
end // apcm_ram_init

reg [APCM_CH_NR_RAM_ELEMENTS_WIDTH-1:0] apcm_ram_rd_index = 0;
reg [APCM_CH_NR_RAM_ELEMENTS_WIDTH-1:0] d_apcm_ram_rd_index = 0; // Delayed index!
reg [APCM_CH_NR_RAM_ELEMENTS_WIDTH-1:0] apcm_ram_wr_index = 0;
reg signed [INPUT_WIDTH-1:0] apcm_ram_rd_data = 0;
reg signed [INPUT_WIDTH-1:0] apcm_ram_wr_data = 0;
reg apcm_ram_wr_enable = 0;
reg apcm_wr_buffer = 0;

// RAM apcm data
localparam NB_APCM_BYTES = 20; // APCM frame size == 160 bits
reg [7:0] apcm_pre_frame[0:NB_APCM_BYTES-1];
reg [4:0] apcm_pre_index = 0;
reg [7:0] apcm_post_frame[0:NB_APCM_BYTES-1];
reg [4:0] apcm_post_index = 0;

/*============================================================================*/
initial begin : frame_init // Initialize apcm frame RAM
/*============================================================================*/
    for ( i = 0; i < NB_APCM_BYTES; i = i + 1 ) begin
        apcm_pre_frame[i] = 0;
        apcm_post_frame[i] = 0;
    end
end // frame_init

reg sb_tvalid0 = 0;
reg sb_tvalid1 = 0;
reg sb_tvalid2 = 0;
reg sb_tvalid3 = 0;
reg [5:0] nb_non_zero_sf_i = 0;
reg [5:0] nb_non_zero_sf = 0;
reg [3:0] non_zero_sf_bits = 0;
reg c_non_zero_sf; // Combinatorial boolean
reg [3:0] sf_0_i = 0;
reg [3:0] sf_1_i = 0;
reg [3:0] sf_2_i = 0;
reg [3:0] sf_3_i = 0;
reg [3:0] sf_0 = 0;
reg [3:0] sf_1 = 0;
reg [3:0] sf_2 = 0;
reg [3:0] sf_3 = 0;
reg [3:0] calculated_sf = 0;
reg [3:0] bits_0 = 0;
reg [3:0] bits_1 = 0;
reg [3:0] bits_2 = 0;
reg [3:0] bits_3 = 0;
wire fit_bitpool_done_c; // Combinatorial data
wire fit_bitpool_fixed_cycles_c; // Combinatorial data
reg store_sf_and_bits = 0;
reg fit_bitpool = 0;
reg [6:0] step_counter = 0; // 128 clock cycle frame
reg [BIT_POOL-1:0] bitpool_c; // Combinatorial bitpool
reg [BIT_POOL-1:0] apcm_out = 0;
reg gen_apcm_out = 0;
reg copy_apcm_frame = 0;
reg copy_apcm_frame_done = 0;
wire copy_apcm_frame_done_c;
reg apcm_out_busy = 0;
reg [3:0] bp_shift_left_c; // Combinatorial shift left
reg [3:0] bp_shift_right_c; // Combinatorial shift right
reg [3:0] bp_mask_shift_right_c; // Combinatorial shift right

reg aes_enable_i = 0;
reg m_aes_tvalid_i = 0;
reg m_aes_tready_i = 0;
reg s_aes_tready_i = 0;

assign fit_bitpool_done_c = (( bits_0 + bits_1 + bits_2 + bits_3 ) > ( BIT_POOL - nb_non_zero_sf )) ? 0 : 1;
assign fit_bitpool_fixed_cycles_c = step_counter[5] & step_counter[4]; // step_counter[5:4] == 2'b11, step_counter == 48

assign m_aes_tdata = {
    apcm_pre_frame[17], apcm_pre_frame[16], apcm_pre_frame[15], apcm_pre_frame[14],
    apcm_pre_frame[13], apcm_pre_frame[12], apcm_pre_frame[11], apcm_pre_frame[10],
    apcm_pre_frame[9], apcm_pre_frame[8], apcm_pre_frame[7], apcm_pre_frame[6],
    apcm_pre_frame[5], apcm_pre_frame[4], apcm_pre_frame[3], apcm_pre_frame[2] };
assign m_aes_tid = m_apcm_tid_i;
assign m_aes_tvalid = m_aes_tvalid_i;
assign s_aes_tready = s_aes_tready_i;
assign copy_apcm_frame_done_c = !aes_enable || ( aes_enable && s_aes_tvalid );

/*============================================================================*/
always @(posedge clk) begin : apcm_block_ram
/*============================================================================*/
    if ( apcm_ram_wr_enable ) begin
        apcm_ram_data[{apcm_wr_tid, apcm_ram_wr_index}] <= apcm_ram_wr_data;
    end
    // Read-first mode
    apcm_ram_rd_data <= apcm_ram_data[{apcm_rd_tid, apcm_ram_rd_index}];
end // apcm_block_ram

/*============================================================================*/
always @(posedge clk) begin : sbc4_bitpool_enc
/*============================================================================*/
    apcm_ram_wr_enable <= 0; // RAM write pulse
    sb_tvalid0 <= sb_tvalid;
    sb_tvalid1 <= 0;
    sb_tvalid2 <= 0;
    sb_tvalid3 <= 0;
    if ( sb_tvalid ) begin
        apcm_wr_tid <= sb_tid;
        aes_enable_i <= aes_enable;
    end
    if ( sb_tvalid0 || sb_tvalid1 || sb_tvalid2 || sb_tvalid3 ) begin
        case ( apcm_ram_wr_index[1:0] )
            2'b00 : apcm_ram_wr_data <= sb_0;
            2'b01 : apcm_ram_wr_data <= sb_1;
            2'b10 : apcm_ram_wr_data <= sb_2;
            2'b11 : apcm_ram_wr_data <= sb_3;
        endcase
        apcm_ram_wr_enable <= 1;
    end
    // Extra clock cycle for combinatorial sf calculation
    store_sf_and_bits <= apcm_ram_wr_enable;
    if ( store_sf_and_bits ) begin
        c_non_zero_sf = 0;
        case ( apcm_ram_wr_index[1:0] )
            2'b00 : begin
                if ( calculated_sf > sf_0_i ) begin
                    sf_0_i <= calculated_sf;
                    if ( !non_zero_sf_bits[0] ) begin
                        non_zero_sf_bits[0] <= 1;
                        c_non_zero_sf = 1;
                    end
                end
                sb_tvalid1 <= 1;
            end
            2'b01 : begin
                if ( calculated_sf > sf_1_i ) begin
                    sf_1_i <= calculated_sf;
                    if ( !non_zero_sf_bits[1] ) begin
                        non_zero_sf_bits[1] <= 1;
                        c_non_zero_sf = 1;
                    end
                end
                sb_tvalid2 <= 1;
            end
            2'b10 : begin
                if ( calculated_sf > sf_2_i ) begin
                    sf_2_i <= calculated_sf;
                    if ( !non_zero_sf_bits[2] ) begin
                        non_zero_sf_bits[2] <= 1;
                        c_non_zero_sf = 1;
                    end
                end
                sb_tvalid3 <= 1;
            end
            2'b11 : begin
                if ( calculated_sf > sf_3_i ) begin
                    sf_3_i <= calculated_sf;
                    if ( !non_zero_sf_bits[3] ) begin
                        non_zero_sf_bits[3] <= 1;
                        c_non_zero_sf = 1;
                    end
                end
            end
        endcase
        if ( c_non_zero_sf ) begin
            nb_non_zero_sf_i <= nb_non_zero_sf_i + 1; // Max. 4 for each subband
        end
        apcm_ram_wr_index <= apcm_ram_wr_index + 1;
    end
    step_counter <= step_counter + 1;
    apcm_wr_buffer <= apcm_ram_wr_index[5]; // Store MSB write index
    if ( apcm_wr_buffer != apcm_ram_wr_index[5] ) begin // Alternate buffer
        sf_0 <= sf_0_i;
        bits_0 <= sf_0_i;
        sf_1 <= sf_1_i;
        bits_1 <= sf_1_i;
        sf_2 <= sf_2_i;
        bits_2 <= sf_2_i;
        sf_3 <= sf_3_i;
        bits_3 <= sf_3_i;
        nb_non_zero_sf <= nb_non_zero_sf_i; // See assignment fit_bitpool_done
        // Reset scale factors and counter
        sf_0_i <= 0;
        sf_1_i <= 0;
        sf_2_i <= 0;
        sf_3_i <= 0;
        nb_non_zero_sf_i <= 0; // Reset non zero scale factor counter and flags
        non_zero_sf_bits <= 0;
        // Set next stage to process eight samples of four subbands
        fit_bitpool <= 1;
        step_counter <= 0;
        apcm_rd_tid <= apcm_wr_tid;
    end
    d_apcm_ram_rd_index <= apcm_ram_rd_index;
    if ( fit_bitpool ) begin
        if ( fit_bitpool_done_c & fit_bitpool_fixed_cycles_c ) begin
            apcm_ram_rd_index <= apcm_ram_rd_index + 1;
            gen_apcm_out <= 1;
            apcm_pre_frame[0] <= ( sf_1 << 4 ) | sf_0; // Little endian, low byte first
            apcm_pre_frame[1] <= ( sf_3 << 4 ) | sf_2;
            apcm_pre_index <= 2;
            apcm_out <= 0;
            fit_bitpool <= 0;
        end
        if ( !fit_bitpool_done_c ) begin
            case (step_counter[1:0])
                2'b00 : if ( bits_3 > 1 ) bits_3 <= bits_3 - 1;
                2'b01 : if ( bits_2 > 1 ) bits_2 <= bits_2 - 1;
                2'b10 : if ( bits_1 > 1 ) bits_1 <= bits_1 - 1;
                2'b11 : if ( bits_0 > 1 ) bits_0 <= bits_0 - 1;
            endcase
        end
    end
    m_aes_tready_i <= m_aes_tready; // Synchronize
    m_aes_tvalid_i <= m_aes_tvalid_i & ~( m_aes_tready_i | m_aes_tready );
    copy_apcm_frame <= 0; // Pulse
    if ( gen_apcm_out ) begin
        if ( d_apcm_ram_rd_index[APCM_CH_NR_RAM_ELEMENTS_WIDTH-1] == apcm_ram_rd_index[APCM_CH_NR_RAM_ELEMENTS_WIDTH-1] ) begin
            apcm_ram_rd_index <= apcm_ram_rd_index + 1;
        end
        else begin
            apcm_pre_frame[NB_APCM_BYTES-2] <= auth_crc[7:0]; // Initalize last two bytes apcm frame
            apcm_pre_frame[NB_APCM_BYTES-1] <= auth_crc[15:8];
            gen_apcm_out <= 0; // Stop generating apcm output!
            copy_apcm_frame <= 1;
            m_aes_tvalid_i <= 1;
            m_apcm_tid_i <= apcm_rd_tid;
        end
        apcm_out <= bitpool_c;
        if ( 2'b11 == d_apcm_ram_rd_index[1:0] ) begin // 4th subband processed
            apcm_pre_frame[apcm_pre_index] <= bitpool_c[7:0]; // Little endian, low byte first
            apcm_pre_frame[apcm_pre_index+1] <= bitpool_c[15:8];
            apcm_pre_index <= apcm_pre_index + 2;
            apcm_out <= 0;
        end
    end
    copy_apcm_frame_done <= 0; // Pulse
    if ( copy_apcm_frame ) begin
        if ( apcm_out_busy ) begin
            copy_apcm_frame <= 1; // Stay in this stage
        end
        else begin
            s_aes_tready_i <= 1;
            if ( aes_enable_i ) begin // Copy encrypted apcm data
                if ( s_aes_tvalid ) begin
                    apcm_post_frame[17] <= apcm_pre_frame[19];
                    apcm_post_frame[16] <= apcm_pre_frame[18];
                    {
                    apcm_post_frame[15], apcm_post_frame[14],
                    apcm_post_frame[13], apcm_post_frame[12],
                    apcm_post_frame[11], apcm_post_frame[10],
                    apcm_post_frame[9], apcm_post_frame[8],
                    apcm_post_frame[7], apcm_post_frame[6],
                    apcm_post_frame[5], apcm_post_frame[4],
                    apcm_post_frame[3], apcm_post_frame[2],
                    apcm_post_frame[1], apcm_post_frame[0]
                    } <= s_aes_tdata;
                    s_aes_tready_i <= 0;
                end
            end
            else begin
                for ( i = 0; i < NB_APCM_BYTES; i = i + 1 ) begin
                    apcm_post_frame[i] <= apcm_pre_frame[i];
                end
            end
            copy_apcm_frame_done <= copy_apcm_frame_done_c;
        end
        copy_apcm_frame <= !copy_apcm_frame_done_c; // Stay in this stage?
    end
    if ( !rst_n ) begin // Reset
        apcm_rd_tid <= 0;
        apcm_wr_tid <= 0;
        m_apcm_tid_i <= 0;
        aes_enable_i <= 0;
        apcm_ram_wr_index <= 0;
        apcm_ram_rd_index <= 0;
        apcm_ram_wr_enable <= 0;
        store_sf_and_bits <= 0;
        fit_bitpool <= 0;
        gen_apcm_out <= 0;
        m_aes_tvalid_i <= 0;
        s_aes_tready_i <= 0;
        copy_apcm_frame <= 0;
        copy_apcm_frame_done <= 0;
    end
end // sbc4_bitpool_enc

/*============================================================================*/
always @(posedge clk) begin : sbc4_apcm_frame_out
/*============================================================================*/
    m_apcm_tready_i <= m_apcm_tready; // Synchronize
    m_apcm_tvalid_i <= m_apcm_tvalid_i & ~( m_apcm_tready_i | m_apcm_tready );
    if ( copy_apcm_frame_done ) begin
        apcm_post_index <= 0;
        apcm_out_busy <= 1;
        m_apcm_tvalid_i <= 1;
    end
    if ( apcm_out_busy ) begin
        if ( m_apcm_tvalid_i & m_apcm_tready_i ) begin
            if (( NB_APCM_BYTES - 1 ) != apcm_post_index ) begin
                apcm_post_index <= apcm_post_index + 1;
                m_apcm_tvalid_i <= 1;
            end
            else begin
                apcm_out_busy <= 0;
            end
        end
    end
    if ( !rst_n ) begin
        apcm_out_busy <= 0;
    end
end // sbc4_apcm_frame_out

/*============================================================================*/
always @(*) begin : sbc4_calculate_sf
/*============================================================================*/
    if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-2] ) begin
        calculated_sf = 15;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-3] ) begin
        calculated_sf = 14;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-4] ) begin
        calculated_sf = 13;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-5] ) begin
        calculated_sf = 12;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-6] ) begin
        calculated_sf = 11;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-7] ) begin
        calculated_sf = 10;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-8] ) begin
        calculated_sf = 9;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-9] ) begin
        calculated_sf = 8;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-10] ) begin
        calculated_sf = 7;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-11] ) begin
        calculated_sf = 6;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-12] ) begin
        calculated_sf = 5;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-13] ) begin
        calculated_sf = 4;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-14] ) begin
        calculated_sf = 3;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-15] ) begin
        calculated_sf = 2;
    end
    else if ( ~apcm_ram_wr_data[INPUT_WIDTH-1] == apcm_ram_wr_data[INPUT_WIDTH-16] ) begin
        calculated_sf = 1;
    end
    else begin
        calculated_sf = {3'b000, apcm_ram_wr_data[INPUT_WIDTH-1]}; // -1!
    end
end // sbc4_calculate_sf

/*============================================================================*/
always @(*) begin : sbc4_gen_apcm_out
/*============================================================================*/
    case ( d_apcm_ram_rd_index[1:0] )
        2'b00 : begin
            bp_shift_left_c = bits_0;
            bp_shift_right_c = sf_0 - bits_0;
            bp_mask_shift_right_c = ( BIT_POOL - 1 ) - bits_0;
        end
        2'b01 : begin
            bp_shift_left_c = bits_1;
            bp_shift_right_c = sf_1 - bits_1;
            bp_mask_shift_right_c = ( BIT_POOL - 1 ) - bits_1;
        end
        2'b10 : begin
            bp_shift_left_c = bits_2;
            bp_shift_right_c = sf_2 - bits_2;
            bp_mask_shift_right_c = ( BIT_POOL - 1 ) - bits_2;
        end
        2'b11 : begin
            bp_shift_left_c = bits_3;
            bp_shift_right_c = sf_3 - bits_3;
            bp_mask_shift_right_c = ( BIT_POOL - 1 ) - bits_3;
        end
    endcase
    if ( bp_shift_left_c ) begin
        bitpool_c = ( {apcm_out[BIT_POOL-2:0], apcm_ram_rd_data[INPUT_WIDTH-1] } << bp_shift_left_c ) // Copy sign
            | ( {1'b0, ( apcm_ram_rd_data[INPUT_WIDTH-2:( INPUT_WIDTH - BIT_POOL )] >> bp_shift_right_c )}
            & {1'b0, ( {( BIT_POOL - 1 ){1'b1}} >> bp_mask_shift_right_c )} );
    end
    else begin
        bitpool_c = apcm_out;
    end
end // sbc4_gen_apcm_out

// Outputs
assign apcm_sop = copy_apcm_frame_done;
assign m_apcm_tdata = apcm_post_frame[apcm_post_index];
assign m_apcm_tid = m_apcm_tid_i;
assign m_apcm_tvalid = m_apcm_tvalid_i;

endmodule
