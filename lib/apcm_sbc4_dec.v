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
 *  APCM SCB4 decoder to process a 20 byte (160 bit) APCM packet into 32 16-bit
 *  samples (eight sets of four). The first two packet bytes (16-bit word)
 *  contain the four 4-bit scale factors (S0/S1/S2/S3). The last two packet
 *  bytes are reserved for an authentication/CRC 16-bit input and is ignored.
 *
 *  The channel number (s_apcm_tid) is not included in the APCM packet! The
 *  number of channels supported depends on the clock speed (clk) and synthesis
 *  of the configured single block RAM size (E.g. 256x36 -> 512x18), which could
 *  be extended to multiple block RAMs (by modification).
 *  The verification of the authentication/CRC 16-bit value is not part of this
 *  module. AES-128 external decryption is optional (aes_enable = 1) and
 *  required when the eight 16-bit SBC4/APCM processed samples are AES encrypted.
 *
 *  APCM/SBC4 decoding is described in the Bluetooth A2DP specification:
 *  https://www.bluetooth.com/specifications/specs/. A software implementation
 *  can be found in the ffmpeg library (libavcodec\sbc*): https://ffmpeg.org/
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module apcm_sbc4_dec #(
/*============================================================================*/
    parameter NR_CHANNELS = 3,
    parameter COEFF_WIDTH = 18,
    parameter BLOCK_RAM_SIZE = 512 )
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    s_apcm_tdata, s_apcm_tid, s_apcm_tvalid, s_apcm_tready, // APCM packet input
    apcm_sop, // APCM start of packet input, s_apcm_tid should be valid!
    auth_crc, // Authentication/CRC output
    aes_enable, // AES-128 decryption enable input
    m_aes_tdata, m_aes_tid, m_aes_tvalid, m_aes_tready, // 128-bit encrypted output
    s_aes_tdata, s_aes_tvalid, s_aes_tready, // 128-bit SBC4/APCM processed samples decrypted input
    m_tdata0, m_tdata1, m_tdata2, m_tdata3, m_tid, m_tvalid, m_tready, // Samples output
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

localparam CHANNEL_WIDTH = clog2(NR_CHANNELS);
localparam INPUT_WIDTH = 16;
localparam [5:0] BIT_POOL = 16;

input  wire clk;
input  wire rst_n;
input  wire [7:0] s_apcm_tdata; // Byte input
input  wire [CHANNEL_WIDTH-1:0] s_apcm_tid;
input  wire s_apcm_tvalid;
output wire s_apcm_tready;
input  wire apcm_sop; // Start of APCM packet
output wire [INPUT_WIDTH-1:0] auth_crc;
input  wire aes_enable;
output wire [127:0] m_aes_tdata;
output wire [CHANNEL_WIDTH-1:0] m_aes_tid;
output wire m_aes_tvalid;
input  wire m_aes_tready;
input  wire [127:0] s_aes_tdata;
input  wire s_aes_tvalid;
output wire s_aes_tready;
output wire [INPUT_WIDTH-1:0] m_tdata0;
output wire [INPUT_WIDTH-1:0] m_tdata1;
output wire [INPUT_WIDTH-1:0] m_tdata2;
output wire [INPUT_WIDTH-1:0] m_tdata3;
output wire [CHANNEL_WIDTH-1:0] m_tid;
output wire m_tvalid;
input  wire m_tready;
output wire overflow;

reg s_tready_i = 1;
reg sb_tvalid_i = 0;
wire sb_tready;

reg [INPUT_WIDTH-1:0] auth_crc_i = 0;
reg [INPUT_WIDTH-1:0] sb_0_i = 0;
reg [INPUT_WIDTH-1:0] sb_1_i = 0;
reg [INPUT_WIDTH-1:0] sb_2_i = 0;
reg [INPUT_WIDTH-1:0] sb_3_i = 0;
reg [CHANNEL_WIDTH-1:0] sb_tid_i = 0;
reg [INPUT_WIDTH-1:0] sb_out = 0;

/*============================================================================*/
initial begin : apcm_param_check
/*============================================================================*/
    if (( INPUT_WIDTH != 16 ) || ( BIT_POOL != 16 )) begin
        $display( "Only INPUT_WIDTH/BIT_POOL = 16 supported!" );
        $finish;
    end
end // apcm_param_check

// RAM apcm data
localparam NB_APCM_BYTES = 20; // APCM frame size == 160 bits
localparam APCM_FRAME_SIZE = NB_APCM_BYTES * 8;
reg [APCM_FRAME_SIZE-1:0] apcm_pre_frame[0:NR_CHANNELS-1];
reg [4:0] apcm_pre_index[0:NR_CHANNELS-1];
wire [4:0] apcm_pre_index_c;
reg [7:0] apcm_post_frame[0:NB_APCM_BYTES-5];
reg [4:0] apcm_post_index = 0;
integer i;
/*============================================================================*/
initial begin : frame_init // Initialize apcm frame RAM
/*============================================================================*/
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        apcm_pre_index[i] = 0;
        apcm_pre_frame[i] = 0;
    end
    for ( i = 0; i < ( NB_APCM_BYTES - 4 ); i = i + 1 ) begin
        apcm_post_frame[i] = 0;
    end
end // frame_init

reg aes_enable_i = 0;
reg m_aes_tvalid_i = 0;
reg m_aes_tready_i = 0;
reg s_aes_tready_i = 0;

assign apcm_pre_index_c = apcm_pre_index[s_apcm_tid];
assign m_aes_tdata = apcm_pre_frame[s_apcm_tid][143:16];
assign m_aes_tid = sb_tid_i;
assign m_aes_tvalid = m_aes_tvalid_i;
assign s_aes_tready = s_aes_tready_i;

reg copy_apcm_frame = 0;
reg fit_bitpool = 0;
wire fit_bitpool_c; // Combinatorial data
reg gen_subband_init = 0;
reg gen_subband_shift = 0;
reg gen_subband_out = 0;
reg [3:0] sf_0_i = 0;
reg [3:0] sf_1_i = 0;
reg [3:0] sf_2_i = 0;
reg [3:0] sf_3_i = 0;
reg [3:0] sf_0 = 0;
reg [3:0] sf_1 = 0;
reg [3:0] sf_2 = 0;
reg [3:0] sf_3 = 0;
reg [3:0] bits_0 = 0;
reg [3:0] bits_1 = 0;
reg [3:0] bits_2 = 0;
reg [3:0] bits_3 = 0;
reg [6:0] step_counter = 0; // 128 clock cycle frame
wire fit_bitpool_done_c; // Combinatorial data
wire fit_bitpool_fixed_cycles_c; // Combinatorial data
reg [BIT_POOL-1:0] apcm_in = 0;
reg [BIT_POOL-1:0] apcm_in_c; // Combinatorial data
reg [5:0] nb_non_zero_sf_i = 0;
reg [5:0] nb_non_zero_sf = 0;
reg non_zero_sf_c; // Combinatorial boolean
reg [3:0] bp_shift_left = 0;
reg [3:0] bp_shift_right = 0;
reg [3:0] sb_shift_right = 0;

assign fit_bitpool_c = !aes_enable || ( aes_enable && s_aes_tvalid );

/*============================================================================*/
always @(posedge clk) begin : sbc4_bitpool_dec
/*============================================================================*/
    m_aes_tready_i <= m_aes_tready; // Synchronize
    m_aes_tvalid_i <= m_aes_tvalid_i & ~( m_aes_tready_i | m_aes_tready );
    if ( apcm_sop ) begin
        apcm_pre_index[s_apcm_tid] <= 0;
    end
    if ( s_apcm_tvalid && s_tready_i && ( s_apcm_tid < NR_CHANNELS )) begin
        apcm_pre_frame[s_apcm_tid] <= {s_apcm_tdata, apcm_pre_frame[s_apcm_tid][159:8]};
        if (( NB_APCM_BYTES - 1 ) == apcm_pre_index_c ) begin
            nb_non_zero_sf <= nb_non_zero_sf_i; // See assignment fit_bitpool_done_c
            nb_non_zero_sf_i <= 0;
            apcm_pre_index[s_apcm_tid] <= 0;
            copy_apcm_frame <= 1;
            s_tready_i <= 0;
            sb_tid_i <= s_apcm_tid;
            aes_enable_i <= aes_enable;
            m_aes_tvalid_i <= 1;
        end
        else begin
            non_zero_sf_c = 0;
            apcm_pre_index[s_apcm_tid] = apcm_pre_index_c + 1;
            if ( 0 == apcm_pre_index_c ) begin
                sf_0_i <= s_apcm_tdata[3:0];
                sf_1_i <= s_apcm_tdata[7:4];
            end
            if ( 1 == apcm_pre_index_c ) begin
                sf_2_i <= s_apcm_tdata[3:0];
                sf_3_i <= s_apcm_tdata[7:4];
            end
            if ( 2 == apcm_pre_index_c ) non_zero_sf_c = ( 0 == sf_0_i ) ? 0 : 1;
            if ( 3 == apcm_pre_index_c ) non_zero_sf_c = ( 0 == sf_1_i ) ? 0 : 1;
            if ( 4 == apcm_pre_index_c ) non_zero_sf_c = ( 0 == sf_2_i ) ? 0 : 1;
            if ( 5 == apcm_pre_index_c ) non_zero_sf_c = ( 0 == sf_3_i ) ? 0 : 1;
            if ( non_zero_sf_c ) nb_non_zero_sf_i <= nb_non_zero_sf_i + 1; // Max. 4 for each subband
        end
    end
    if ( copy_apcm_frame && !( fit_bitpool | gen_subband_init | gen_subband_shift | gen_subband_out )) begin
        s_aes_tready_i <= 1;
        auth_crc_i <= apcm_pre_frame[sb_tid_i][159:144];
        if ( aes_enable_i ) begin // Copy decrypted apcm data
            if ( s_aes_tvalid ) begin
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
            apcm_post_frame[0] <= apcm_pre_frame[sb_tid_i][23:16];
            apcm_post_frame[1] <= apcm_pre_frame[sb_tid_i][31:24];
            apcm_post_frame[2] <= apcm_pre_frame[sb_tid_i][39:32];
            apcm_post_frame[3] <= apcm_pre_frame[sb_tid_i][47:40];
            apcm_post_frame[4] <= apcm_pre_frame[sb_tid_i][55:48];
            apcm_post_frame[5] <= apcm_pre_frame[sb_tid_i][63:56];
            apcm_post_frame[6] <= apcm_pre_frame[sb_tid_i][71:64];
            apcm_post_frame[7] <= apcm_pre_frame[sb_tid_i][79:72];
            apcm_post_frame[8] <= apcm_pre_frame[sb_tid_i][87:80];
            apcm_post_frame[9] <= apcm_pre_frame[sb_tid_i][95:88];
            apcm_post_frame[10] <= apcm_pre_frame[sb_tid_i][103:96];
            apcm_post_frame[11] <= apcm_pre_frame[sb_tid_i][111:104];
            apcm_post_frame[12] <= apcm_pre_frame[sb_tid_i][119:112];
            apcm_post_frame[13] <= apcm_pre_frame[sb_tid_i][127:120];
            apcm_post_frame[14] <= apcm_pre_frame[sb_tid_i][135:128];
            apcm_post_frame[15] <= apcm_pre_frame[sb_tid_i][143:136];
        end
        step_counter <= 0;
        sf_0 <= sf_0_i;
        bits_0 <= sf_0_i;
        sf_1 <= sf_1_i;
        bits_1 <= sf_1_i;
        sf_2 <= sf_2_i;
        bits_2 <= sf_2_i;
        sf_3 <= sf_3_i;
        bits_3 <= sf_3_i;
        s_tready_i <= fit_bitpool_c;
        fit_bitpool <= fit_bitpool_c;
        copy_apcm_frame <= !fit_bitpool_c;
    end
    if ( !( gen_subband_init || gen_subband_shift )) begin
        step_counter <= step_counter + 1;
    end
    gen_subband_init <= 0; // Pulse
    if ( fit_bitpool ) begin
        if ( fit_bitpool_done_c && fit_bitpool_fixed_cycles_c ) begin
            fit_bitpool <= 0;
            step_counter[1:0] <= 0; // Start at modula 4!
            apcm_post_index <= 0;
            gen_subband_init <= 1;
        end
        if ( !fit_bitpool_done_c ) begin
            case ( step_counter[1:0] )
                2'b00 : if ( bits_3 > 1 ) bits_3 <= bits_3 - 1;
                2'b01 : if ( bits_2 > 1 ) bits_2 <= bits_2 - 1;
                2'b10 : if ( bits_1 > 1 ) bits_1 <= bits_1 - 1;
                2'b11 : if ( bits_0 > 1 ) bits_0 <= bits_0 - 1;
            endcase
        end
    end
    gen_subband_shift <= 0; // Pulse
    if ( gen_subband_init ) begin
        case (step_counter[1:0])
            2'b00 : begin
                bp_shift_left <= ( BIT_POOL - 1 ) - bits_3;
                bp_shift_right <= bits_3;
                sb_shift_right <= ( BIT_POOL - 1 ) - sf_3;
                apcm_in <= {apcm_post_frame[apcm_post_index+1], apcm_post_frame[apcm_post_index]};
            end
            2'b01 : begin
                bp_shift_left <= ( BIT_POOL - 1 ) - bits_2;
                bp_shift_right <= bits_2;
                sb_shift_right <= ( BIT_POOL - 1 ) - sf_2;
            end
            2'b10 : begin
                bp_shift_left <= ( BIT_POOL - 1 ) - bits_1;
                bp_shift_right <= bits_1;
                sb_shift_right <= ( BIT_POOL - 1 ) - sf_1;
            end
            2'b11 : begin
                bp_shift_left <= ( BIT_POOL - 1 ) - bits_0;
                bp_shift_right <= bits_0;
                sb_shift_right <= ( BIT_POOL - 1 ) - sf_0;
            end
        endcase
        gen_subband_shift <= 1;
    end
    sb_tvalid_i <= sb_tvalid_i & ~sb_tready;
    gen_subband_out <= 0; // Pulse
    if ( gen_subband_shift ) begin
        if ( 0 == bp_shift_right ) begin
            sb_out <= 0;
        end
        else if ( 0 == sb_shift_right ) begin
            if ( INPUT_WIDTH-BIT_POOL == 0 ) begin // Conditional synthesis!
                sb_out <= apcm_in_c;
            end
            else begin
                sb_out <= { apcm_in_c, {( INPUT_WIDTH - BIT_POOL ){1'b0}} };
            end
        end
        else begin
            if ( INPUT_WIDTH-BIT_POOL == 0 ) begin // Conditional synthesis!
                sb_out <= $signed( apcm_in_c ) >>> sb_shift_right;
            end
            else begin
                sb_out <= { ($signed( apcm_in_c ) >>> sb_shift_right ), {(INPUT_WIDTH-BIT_POOL){1'b0}} };
            end
        end
        gen_subband_shift <= sb_tvalid_i; // Keep state during sb_tvalid
        gen_subband_out <= ~sb_tvalid_i;
    end
    if ( gen_subband_out ) begin
        gen_subband_init <= 1;
        case ( step_counter[1:0] )
            2'b00 : if ( bits_3 ) sb_3_i <= sb_out;
            2'b01 : if ( bits_2 ) sb_2_i <= sb_out;
            2'b10 : if ( bits_1 ) sb_1_i <= sb_out;
            2'b11 : begin
                if ( bits_0 ) begin
                    sb_0_i <= sb_out;
                end
                if (( NB_APCM_BYTES - 6 ) == apcm_post_index ) begin
                    gen_subband_init <= 0; // Stop subband generation
                end
                else begin
                    apcm_post_index <= apcm_post_index + 2;
                end
                sb_tvalid_i <= 1; // All four subbands are valid
            end
        endcase
        if (( bp_shift_left != 0 ) && ( bp_shift_right != 0 )) begin
            apcm_in <= apcm_in >> ( bp_shift_right + 1 );
        end
        sb_out <= 0;
    end
    if ( !rst_n ) begin // Reset
        m_aes_tvalid_i <= 0;
        s_aes_tready_i <= 0;
        s_tready_i <= 1;
        copy_apcm_frame <= 0;
        fit_bitpool <= 0;
        gen_subband_init <= 0;
        gen_subband_shift <= 0;
        gen_subband_out <= 0;
    end
end // sbc4_bitpool_dec

/*============================================================================*/
always @(*) begin : sbc4_c_apcm_in
/*============================================================================*/
    if ( 0 == bp_shift_left ) begin
        apcm_in_c = apcm_in;
    end
    else begin
        apcm_in_c = apcm_in << bp_shift_left;
    end
end // sbc4_c_apcm_in

wire [INPUT_WIDTH-1:0] sb_0;
wire [INPUT_WIDTH-1:0] sb_1;
wire [INPUT_WIDTH-1:0] sb_2;
wire [INPUT_WIDTH-1:0] sb_3;
wire [CHANNEL_WIDTH-1:0] sb_tid;
wire sb_tvalid;

assign auth_crc = auth_crc_i;
assign fit_bitpool_done_c = (( bits_0 + bits_1 + bits_2 + bits_3 ) > ( BIT_POOL - nb_non_zero_sf )) ? 0 : 1;
assign fit_bitpool_fixed_cycles_c = step_counter[5] & step_counter[4]; // step_counter[5:4] == 2'b11, step_counter == 48
assign s_apcm_tready = s_tready_i;
assign sb_0 = sb_0_i;
assign sb_1 = sb_1_i;
assign sb_2 = sb_2_i;
assign sb_3 = sb_3_i;
assign sb_tid = sb_tid_i;
assign sb_tvalid = sb_tvalid_i;

localparam real FACTOR_1 = ( 2.0 ** ( COEFF_WIDTH - 1 )) - 1;
// Prototype filter coefficients
localparam real PTC1  = ( 5.3654897628474e-04 * FACTOR_1 );
localparam real PTC2  = ( 1.4918835706273e-03 * FACTOR_1 );
localparam real PTC3  = ( 2.7337090367926e-03 * FACTOR_1 );
localparam real PTC4  = ( 3.8372019280091e-03 * FACTOR_1 );
localparam real PTC5  = ( 3.8920514850040e-03 * FACTOR_1 );
localparam real PTC6  = ( 1.8658169061497e-03 * FACTOR_1 );
localparam real PTC7  = ( -3.0601228600951e-03 * FACTOR_1 );
localparam real PTC8  = ( -1.0913762016690e-02 * FACTOR_1 );
localparam real PTC9  = ( -2.0438508719161e-02 * FACTOR_1 );
localparam real PTC10 = ( -2.8875739180821e-02 * FACTOR_1 );
localparam real PTC11 = ( -3.2193928982763e-02 * FACTOR_1 );
localparam real PTC12 = ( -2.5876781146790e-02 * FACTOR_1 );
localparam real PTC13 = ( -6.1324518594809e-03 * FACTOR_1 );
localparam real PTC14 = ( 2.8821727426597e-02 * FACTOR_1 );
localparam real PTC15 = ( 7.7646349365466e-02 * FACTOR_1 );
localparam real PTC16 = ( 1.3559327369645e-01 * FACTOR_1 );
localparam real PTC17 = ( 1.9498784104769e-01 * FACTOR_1 );
localparam real PTC18 = ( 2.4663666230909e-01 * FACTOR_1 );
localparam real PTC19 = ( 2.8182820289485e-01 * FACTOR_1 );
localparam real PTC20 = ( 2.9431533161836e-01 * FACTOR_1 );

localparam NR_COEFF = 40;
localparam real COS_45 = ( 7.0710678118655e-01 * FACTOR_1 );
localparam COS_A = NR_COEFF;
localparam real COS_22_5 = ( 9.2387953251129e-01 * FACTOR_1 );
localparam COS_B = NR_COEFF + 1;
localparam real COS_67_5 = ( 3.8268343236509e-01 * FACTOR_1 );
localparam COS_C = NR_COEFF + 2;
localparam real COS_0 = FACTOR_1;
localparam signed [COEFF_WIDTH-1:0] cosine_d = COS_0; // Not used!
localparam real COS_90 = 0;
localparam signed [COEFF_WIDTH-1:0] cosine_e = COS_90; // Not used!

// FIR and cosine filter coefficients
(* rom_style = "block" *) // Synthesis likely will select "distributed"
reg signed [COEFF_WIDTH-1:0] filter[0:NR_COEFF+2];
/*============================================================================*/
initial begin
/*============================================================================*/
    filter[0]  = 0;
    filter[1]  = PTC1;
    filter[2]  = PTC2;
    filter[3]  = -PTC3;
    filter[4]  = -PTC4;
    filter[5]  = PTC5;
    filter[6]  = PTC6;
    filter[7]  = PTC7;
    filter[8]  = -PTC8;
    filter[9]  = -PTC9;
    filter[10] = -PTC10;
    filter[11] = PTC11;
    filter[12] = PTC12;
    filter[13] = -PTC13;
    filter[14] = -PTC14;
    filter[15] = -PTC15;
    filter[16] = PTC16;
    filter[17] = PTC17;
    filter[18] = PTC18;
    filter[19] = -PTC19;
    filter[20] = -PTC20;
    filter[21] = PTC19;
    filter[22] = PTC18;
    filter[23] = PTC17;
    filter[24] = -PTC16;
    filter[25] = -PTC15;
    filter[26] = -PTC14;
    filter[27] = PTC13;
    filter[28] = PTC12;
    filter[29] = -PTC11;
    filter[30] = -PTC10;
    filter[31] = -PTC9;
    filter[32] = PTC8;
    filter[33] = PTC7;
    filter[34] = PTC6;
    filter[35] = -PTC5;
    filter[36] = -PTC4;
    filter[37] = PTC3;
    filter[38] = PTC2;
    filter[39] = PTC1;
    filter[COS_A] = COS_45;
    filter[COS_B] = COS_22_5;
    filter[COS_C] = COS_67_5;
end

// Intermediate registers
reg [CHANNEL_WIDTH-1:0] data_tid_i = 0;
reg sb_tready_i = 1;
reg [CHANNEL_WIDTH-1:0] m_tid_i = 0;
reg m_tvalid_i = 0;
reg m_tready_i = 0;
reg signed [INPUT_WIDTH:0] sum0 = 0;
reg signed [INPUT_WIDTH:0] dif0 = 0;
reg signed [INPUT_WIDTH:0] sum1 = 0;
reg signed [INPUT_WIDTH:0] dif1 = 0;

localparam CALC_WIDTH = INPUT_WIDTH + 2; // Add 2 bits for rescaling
reg signed [CALC_WIDTH-1:0] y0y4 = 0;
reg signed [CALC_WIDTH-1:0] y1y5 = 0;
reg signed [CALC_WIDTH-1:0] y6 = 0;
reg signed [CALC_WIDTH-1:0] y3y7 = 0;
reg signed [CALC_WIDTH-1:0] r0_0 = 0;
reg signed [CALC_WIDTH-1:0] r0_1 = 0;
reg signed [CALC_WIDTH-1:0] r1_1 = 0;
reg signed [CALC_WIDTH-1:0] r1_2 = 0;
reg signed [CALC_WIDTH-1:0] r1_3 = 0; // Temporarily r1_1 copy!
reg signed [CALC_WIDTH-1:0] p_arg = 0;

// Boolean states
reg s0 = 0; // Seven zero one hot stages s0-s6
reg s1 = 0;
reg s2 = 0;
reg s3 = 0;
reg s4 = 0;
reg s5 = 0;
reg s6 = 0;
reg fir_processing = 0;
reg output_valid = 0;

// Registers
localparam NR_COEFF_WIDTH = clog2( NR_COEFF );
reg [NR_COEFF_WIDTH-1:0] coeff_index = 0;
// RAM data
localparam NR_RAM_ELEMENTS = NR_CHANNELS * NR_COEFF;
localparam NR_RAM_ELEMENTS_WIDTH = clog2( NR_RAM_ELEMENTS );

 // Block ram has intermediate registers width, not audio samples width!
(* ram_style = "block" *) // AMD-Xilinx synthesis attribute
reg signed [CALC_WIDTH-1:0] ram_data[0:NR_RAM_ELEMENTS-1];

/*============================================================================*/
initial begin : ram_init // Initialize block RAM
/*============================================================================*/
    for (i = 0; i < NR_RAM_ELEMENTS; i = i + 1) begin
        ram_data[i] = 0;
    end
end // ram_init

reg [NR_RAM_ELEMENTS_WIDTH-1:0] ram_rd_index = 0;
reg [NR_RAM_ELEMENTS_WIDTH-1:0] ram_rd_index_d = 0; // Delayed index!
reg [NR_RAM_ELEMENTS_WIDTH-1:0] ram_wr_index = 0;

// Block ram has intermediate registers width, not audio samples width!
reg signed [CALC_WIDTH-1:0] ram_rd_data = 0;
reg signed [CALC_WIDTH-1:0] ram_wr_data = 0;
reg inc_rd_index = 0;
reg inc_rd_index_d = 0;
reg ram_wr_enable = 0;

// Test signals
wire overflow_fir;
wire overflow_multiplication;

/*============================================================================*/
initial begin : sbc4_param_check
/*============================================================================*/
    if ( NR_RAM_ELEMENTS > BLOCK_RAM_SIZE ) begin
        $display( "NR_RAM_ELEMENTS exceeds %d (block RAM size)", BLOCK_RAM_SIZE );
        $finish;
    end
    if ( NR_COEFF % 2 != 0 ) begin
        $display( "NR_COEFF should be an even number" );
        $finish;
    end
end // sbc4_param_check

// Combinatorial registers
reg signed [INPUT_WIDTH:0] sum_sb;
reg fir_r2z;
reg signed [CALC_WIDTH+COEFF_WIDTH-1:0] fir_product;
reg [2:0] modula_index;

/*============================================================================*/
always @(posedge clk) begin : sbc4_synthesis
/*============================================================================*/
    m_tready_i <= m_tready; // Synchronize
    m_tvalid_i <= m_tvalid_i & ~( m_tready_i | m_tready );
    s0 <= 0; // Clocked pulse
    output_valid <= 0; // Clocked pulse
    if ( sb_tvalid && sb_tready_i ) begin
        data_tid_i <= sb_tid;
        sb_tready_i <= 0;
        sum_sb = $signed( {sb_0[INPUT_WIDTH-1], sb_0} ) + $signed( {sb_3[INPUT_WIDTH-1], sb_3} );
        sum0 <= sum_sb;
        dif0 <= $signed( {sb_0[INPUT_WIDTH-1], sb_0} ) - $signed( {sb_3[INPUT_WIDTH-1], sb_3} );
        sum1 <= $signed( {sb_1[INPUT_WIDTH-1], sb_1} ) + $signed( {sb_2[INPUT_WIDTH-1], sb_2} );
        dif1 <= $signed( {sb_1[INPUT_WIDTH-1], sb_1} ) - $signed( {sb_2[INPUT_WIDTH-1], sb_2} );
        p_arg <= {sum_sb, 1'b0}; // sum0
        coeff_index <= COS_A;
        s0 <= 1;
    end
    if ( s0 ) begin
        r0_0 <= fir_product[CALC_WIDTH+COEFF_WIDTH-2:COEFF_WIDTH-1];
        r1_2 <= {(-sum0 - sum1), 1'b0};
        p_arg <= {sum1, 1'b0};
    end
    s1 <= s0;
    if ( s1 ) begin
        r0_0 <= r0_0 - fir_product[CALC_WIDTH+COEFF_WIDTH-2:COEFF_WIDTH-1];
        p_arg <= {dif1, 1'b0};
        coeff_index <= COS_B;
    end
    s2 <= s1;
    if ( s2 ) begin
        r0_1 <= -fir_product[CALC_WIDTH+COEFF_WIDTH-2:COEFF_WIDTH-1];
        coeff_index <= COS_C;
        for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
            if ( i == data_tid_i ) begin
                ram_rd_index <= NR_COEFF * i;
            end
        end
        inc_rd_index <= 1;
    end
    s3 <= s2;
    if ( s3 ) begin
        r1_1 <= -fir_product[CALC_WIDTH+COEFF_WIDTH-2:COEFF_WIDTH-1];
        p_arg <= {dif0, 1'b0};
    end
    s4 <= s3;
    if ( s4 ) begin
        r0_1 <= r0_1 + fir_product[CALC_WIDTH+COEFF_WIDTH-2:COEFF_WIDTH-1];
        coeff_index <= COS_B;
    end
    s5 <= s4;
    if ( s5 ) begin
        r1_1 <= r1_1 - fir_product[CALC_WIDTH+COEFF_WIDTH-2:COEFF_WIDTH-1];
    end
    s6 <= s5;
    if ( s6 ) begin
        fir_processing <= 1;
        coeff_index <= 0; // Start at 0 for correct p_arg assignment, see (0 == modula_index)
        m_tvalid_i <= 0;
        y0y4 <= 0; // Reset y0y4
        y1y5 <= 0; // Reset y1y5
        y6 <= 0; // Reset y6
        y3y7 <= 0; // Reset y3y7
    end
    // R/W block ram
    ram_rd_index_d <= ram_rd_index;
    ram_wr_index <= ram_rd_index_d;
    inc_rd_index_d <= inc_rd_index;
    ram_wr_enable <= inc_rd_index_d;
    // RAM increment read index
    if ( inc_rd_index && ( ram_rd_index < ( NR_RAM_ELEMENTS - 1 ))) begin
        ram_rd_index <= ram_rd_index + 1;
    end
    if ( inc_rd_index_d ) begin
        case ( ram_rd_index_d[1:0] )
            2'b00 : ram_wr_data <= r0_0;
            2'b01 : ram_wr_data <= r0_1;
            2'b10 : ram_wr_data <= r1_1;
            2'b11 : ram_wr_data <= r1_2;
        endcase
        case ( ram_rd_index_d[1:0] )
            2'b00 : r0_0 <= ram_rd_data;
            2'b01 : r0_1 <= ram_rd_data;
            2'b10 : r1_1 <= ram_rd_data;
            2'b11 : r1_2 <= ram_rd_data;
        endcase
    end
    // FIR processing
    if ( fir_processing ) begin
        if (( NR_COEFF - 5 ) == coeff_index ) begin
            inc_rd_index <= 0;
        end
        if (( NR_COEFF - 1 ) == coeff_index ) begin
            fir_processing <= 0; // Stop FIR processing
            output_valid <= 1; // Next clock cycle all coefficients done
        end else begin
            coeff_index <= coeff_index + 1;
        end
        if ( 0 == modula_index || 4 == modula_index ) begin
            y0y4 <= y0y4 - fir_product[CALC_WIDTH+COEFF_WIDTH-3:COEFF_WIDTH-2];
        end
        if ( 1 == modula_index || 5 == modula_index ) begin
            y1y5 <= y1y5 - fir_product[CALC_WIDTH+COEFF_WIDTH-3:COEFF_WIDTH-2];
        end
        if ( 6 == modula_index ) begin
            y6 <= y6 - fir_product[CALC_WIDTH+COEFF_WIDTH-3:COEFF_WIDTH-2];
        end
        if ( 3 == modula_index || 7 == modula_index ) begin
            y3y7 <= y3y7 - fir_product[CALC_WIDTH+COEFF_WIDTH-3:COEFF_WIDTH-2];
        end
        // Next fir_processing
        if ( 0 == modula_index ) begin
            p_arg <= r0_1;
        end
        if ( 3 == modula_index ) begin
            p_arg <= r0_0;
        end
        if ( 4 == modula_index ) begin
            p_arg <= r1_1;
            r1_3 <= r1_1; // Copy r1_1, will be overwritten next clock!
        end
        if ( 5 == modula_index ) begin
            p_arg <= r1_2;
        end
        if ( 6 == modula_index ) begin
            p_arg <= r1_3;
        end
        if ( 7 == modula_index ) begin
            p_arg <= r0_0;
        end
    end
    if ( output_valid ) begin
        m_tid_i <= data_tid_i;
        m_tvalid_i <= 1;
        sb_tready_i <= 1;
    end
    if ( !rst_n ) begin
        sb_tready_i <= 1;
        ram_rd_index <= 0;
        ram_wr_index <= 0;
        inc_rd_index <= 0;
        inc_rd_index_d <= 0;
        ram_wr_enable <= 0;
        s0 <= 0;
        s1 <= 0;
        s2 <= 0;
        s3 <= 0;
        s4 <= 0;
        s5 <= 0;
        s6 <= 0;
        fir_processing <= 0;
        output_valid <= 0;
    end
end // sbc4_synthesis

/*============================================================================*/
always @(*) begin : sbc4_synthesis_combinatorial
/*============================================================================*/
    fir_r2z = p_arg[CALC_WIDTH-1] ^ filter[coeff_index][COEFF_WIDTH-1]; // Sign of fir_product
    fir_product = ( p_arg * filter[coeff_index]) + // Round to zero fir_product
        $signed( {{( CALC_WIDTH + 1 ){1'b0}}, {( COEFF_WIDTH - 1 ){fir_r2z}}} );
    modula_index = coeff_index % 8;
end // sbc4_synthesis_combinatorial

/*============================================================================*/
always @(posedge clk) begin : block_ram
/*============================================================================*/
    if ( ram_wr_enable ) begin
        ram_data[ram_wr_index] <= ram_wr_data;
    end
    // Read-first mode
    ram_rd_data <= ram_data[ram_rd_index];
end // block_ram

localparam [INPUT_WIDTH-2:0] ALL_ZERO = 0; // 00000...
localparam [INPUT_WIDTH-2:0] ALL_ONES = -1; // 11111...

// Signals out
assign sb_tready = sb_tready_i;
assign m_tdata0[INPUT_WIDTH-1] = y0y4[CALC_WIDTH-1]; // Copy sign
// Check for positive and negative overflow
assign m_tdata0[INPUT_WIDTH-2:0] =
    (( 1 == y0y4[CALC_WIDTH-1] ) && ( 2'b11 != y0y4[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ZERO : // Maximum negative
    (( 0 == y0y4[CALC_WIDTH-1] ) && ( 2'b00 != y0y4[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ONES : // Maximum positive
    y0y4[INPUT_WIDTH-2:0];
assign m_tdata1[INPUT_WIDTH-1] = y1y5[CALC_WIDTH-1]; // Copy sign
// Check for positive and negative overflow
assign m_tdata1[INPUT_WIDTH-2:0] =
    (( 1 == y1y5[CALC_WIDTH-1] ) && ( 2'b11 != y1y5[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ZERO : // Maximum negative
    (( 0 == y1y5[CALC_WIDTH-1] ) && ( 2'b00 != y1y5[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ONES : // Maximum positive
    y1y5[INPUT_WIDTH-2:0];
assign m_tdata2[INPUT_WIDTH-1] = y6[CALC_WIDTH-1]; // Copy sign
// Check for positive and negative overflow
assign m_tdata2[INPUT_WIDTH-2:0] =
    (( 1 == y6[CALC_WIDTH-1] ) && ( 2'b11 != y6[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ZERO : // Maximum negative
    (( 0 == y6[CALC_WIDTH-1] ) && ( 2'b00 != y6[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ONES : // Maximum positive
    y6[INPUT_WIDTH-2:0];
assign m_tdata3[INPUT_WIDTH-1] = y3y7[CALC_WIDTH-1]; // Copy sign
// Check for positive and negative overflow
assign m_tdata3[INPUT_WIDTH-2:0] =
    (( 1 == y3y7[CALC_WIDTH-1] ) && ( 2'b11 != y3y7[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ZERO : // Maximum negative
    (( 0 == y3y7[CALC_WIDTH-1] ) && ( 2'b00 != y3y7[CALC_WIDTH-2:CALC_WIDTH-3] )) ? ALL_ONES : // Maximum positive
    y3y7[INPUT_WIDTH-2:0];
assign m_tid = m_tid_i;
assign m_tvalid = m_tvalid_i;

// Test signals for simulation
assign overflow_fir =
    (( 1 == y0y4[CALC_WIDTH-1] ) && ( 2'b11 != y0y4[CALC_WIDTH-2:CALC_WIDTH-3] )) ||
    (( 0 == y0y4[CALC_WIDTH-1] ) && ( 2'b00 != y0y4[CALC_WIDTH-2:CALC_WIDTH-3] )) ||
    (( 1 == y1y5[CALC_WIDTH-1] ) && ( 2'b11 != y1y5[CALC_WIDTH-2:CALC_WIDTH-3] )) ||
    (( 0 == y1y5[CALC_WIDTH-1] ) && ( 2'b00 != y1y5[CALC_WIDTH-2:CALC_WIDTH-3] )) ||
    (( 1 == y6[CALC_WIDTH-1] ) && ( 2'b11 != y6[CALC_WIDTH-2:CALC_WIDTH-3] )) ||
    (( 0 == y6[CALC_WIDTH-1] ) && ( 2'b00 != y6[CALC_WIDTH-2:CALC_WIDTH-3] )) ||
    (( 1 == y3y7[CALC_WIDTH-1] ) && ( 2'b11 != y3y7[CALC_WIDTH-2:CALC_WIDTH-3] )) ||
    (( 0 == y3y7[CALC_WIDTH-1] ) && ( 2'b00 != y3y7[CALC_WIDTH-2:CALC_WIDTH-3] ));
assign overflow_multiplication =
    (( 1 == fir_product[CALC_WIDTH+COEFF_WIDTH-1] ) && ( 2'b11 != fir_product[CALC_WIDTH+COEFF_WIDTH-2:CALC_WIDTH+COEFF_WIDTH-3] )) ||
    (( 0 == fir_product[CALC_WIDTH+COEFF_WIDTH-1] ) && ( 2'b00 != fir_product[CALC_WIDTH+COEFF_WIDTH-2:CALC_WIDTH+COEFF_WIDTH-3] ));
assign overflow = overflow_fir | overflow_multiplication;

endmodule
