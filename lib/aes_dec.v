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
 *  AES decipher module for keylength 128. Specified by the National Institute
 *  of Standards and Technology (NIST) publication Advanced Encryption Standard
 *  FIPS 197 (2001, updated 2023):
 *
 *  https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197-upd1.pdf
 *
 *  Single AES-128 module implementation, supports "DEFAULT", "FAST" and "TINY"
 *  configuration. Configuration "DEFAULT" takes 50 clock cycles to complete,
 *  "FAST" takes 20 clock cycles and "TINY" takes 176 clock cycles.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module aes_dec #(
/*============================================================================*/
    parameter CFG_MODE = "DEFAULT" ) // "FAST", about doubles the logic
    (                                // "TINY", about halves the logic
    input  wire clk,
    input  wire [127:0] s_aes_key, // Decipher key
    input  wire [127:0] s_aes_block, // Encrypted block
    input  wire s_aes_valid,
    output wire s_aes_ready,
    output wire [127:0] m_aes_block, // Decrypted block
    output wire [3:0] round, // For verification
    output wire [127:0] round_key // Last round key = encipher key
    );

/*============================================================================*/
function [7:0] mod_div_2( input [7:0] x );
/*============================================================================*/
begin
    mod_div_2 = {1'b0, x[7:1]} ^ ( 8'h8D & {8{x[0]}} );
end
endfunction // mod_div_2

/*============================================================================*/
function [7:0] mod_x_2( input [7:0] x );
/*============================================================================*/
begin
    mod_x_2 = {x[6:0], 1'b0} ^ ( 8'h1B & {8{x[7]}} );
end
endfunction // mod_x_2

/*============================================================================*/
function [7:0] mod_x_3( input [7:0] x );
/*============================================================================*/
begin
    mod_x_3 = mod_x_2( x ) ^ x;
end
endfunction // mod_x_3

/*============================================================================*/
function [7:0] mod_x_4( input [7:0] x );
/*============================================================================*/
begin
    mod_x_4 = mod_x_2( mod_x_2( x ));
end
endfunction // mod_x_4

/*============================================================================*/
function [7:0] mod_x_8( input [7:0] x );
/*============================================================================*/
begin
    mod_x_8 = mod_x_2( mod_x_4( x ));
end
endfunction // mod_x_8

/*============================================================================*/
function [7:0] mod_x_9( input [7:0] x );
/*============================================================================*/
begin
    mod_x_9 = mod_x_8( x ) ^ x;
end
endfunction // mod_x_9

/*============================================================================*/
function [7:0] mod_x_11( input [7:0] x );
/*============================================================================*/
begin
    mod_x_11 = mod_x_8( x ) ^ mod_x_2( x ) ^ x;
end
endfunction // mod_x_11

/*============================================================================*/
function [7:0] mod_x_13( input [7:0] x );
/*============================================================================*/
begin
    mod_x_13 = mod_x_8( x ) ^ mod_x_4( x ) ^ x;
end
endfunction // mod_x_13

/*============================================================================*/
function [7:0] mod_x_14( input [7:0] x );
/*============================================================================*/
begin
    mod_x_14 = mod_x_8( x ) ^ mod_x_4( x ) ^ mod_x_2( x );
end
endfunction // mod_x_14

/*============================================================================*/
function [7:0] sbox_calc( input [7:0] x );
/*============================================================================*/
    reg [3:0] idx[0:10];
    reg [3:0] idx_c;
    reg [3:0] i;
    reg [7:0] ix[0:11];
    reg [7:0] ix_c;
    reg [7:0] ix_cc;
    reg [7:0] ix_ccc;
    reg [3:0] j;
    reg [7:0] jx[0:8];
    reg [7:0] jy[0:7];
begin
    idx[0] = 4'd0;
    idx[1] = 4'd1;
    idx[2] = 4'd1;
    idx[3] = 4'd3;
    idx[4] = 4'd4;
    idx[5] = 4'd3;
    idx[6] = 4'd6;
    idx[7] = 4'd7;
    idx[8] = 4'd3;
    idx[9] = 4'd9;
    idx[10] = 4'd1;
    ix[0] = x;
    for ( i = 0; i < 4'd11; i = i + 4'd1 ) begin
        jx[0] = 0;
        jy[0] = ix[i];
        for ( j = 0; j < 4'd8; j = j + 4'd1 ) begin
            idx_c = idx[i];
            jx[j+1] = jx[j] ^ ( {(8){ix[idx_c][j]}} & jy[j] );
            if ( j != 7 ) begin
                jy[j+1] = mod_x_2( jy[j] );
            end
        end
        ix[i+1] = jx[8];
    end
    ix_c = {ix[11][6:0], ix[11][7]};
    ix_cc = ix_c ^ {ix_c[6:0], ix_c[7]};
    ix_ccc = ix_cc ^ {ix_cc[5:0], ix_cc[7:6]};
    sbox_calc = ix[11] ^ ix_ccc ^ 8'h63;
end
endfunction // sbox_calc

/*============================================================================*/
function [7:0] sbox_inv_calc( input [7:0] x );
/*============================================================================*/
    reg [3:0] idx[0:10];
    reg [3:0] idx_c;
    reg [3:0] i;
    reg [7:0] ix[0:11];
    reg [7:0] ix_c;
    reg [7:0] ix_cc;
    reg [7:0] ix_ccc;
    reg [3:0] j;
    reg [7:0] jx[0:8];
    reg [7:0] jy[0:7];
begin
    idx[0] = 4'd0;
    idx[1] = 4'd1;
    idx[2] = 4'd1;
    idx[3] = 4'd3;
    idx[4] = 4'd4;
    idx[5] = 4'd3;
    idx[6] = 4'd6;
    idx[7] = 4'd7;
    idx[8] = 4'd3;
    idx[9] = 4'd9;
    idx[10] = 4'd1;
    ix_c = {x[6:0], x[7]};
    ix_cc = ix_c ^ {ix_c[5:0], ix_c[7:6]};
    ix_ccc = {ix_c[2:0], ix_c[7:3]};
    ix[0] = ix_ccc ^ ix_cc ^ 8'h05;
    for ( i = 0; i < 4'd11; i = i + 4'd1 ) begin
        jx[0] = 0;
        jy[0] = ix[i];
        for ( j = 0; j < 4'd8; j = j + 4'd1 ) begin
            idx_c = idx[i];
            jx[j+1] = jx[j] ^ ( {(8){ix[idx_c][j]}} & jy[j] );
            if ( j != 7 ) begin
                jy[j+1] = mod_x_2( jy[j] );
            end
        end
        ix[i+1] = jx[8];
    end
    sbox_inv_calc = ix[11];
end
endfunction // sbox_inv_calc

/*============================================================================*/
function [31:0] inv_pre_mix( input [31:0] x );
/*============================================================================*/
begin
    inv_pre_mix = {
        {mod_x_14( x[31:24] ) ^ mod_x_11( x[23:16] ) ^ mod_x_13( x[15:8] ) ^ mod_x_9( x[7:0] )},
        {mod_x_9( x[31:24] ) ^ mod_x_14( x[23:16] ) ^ mod_x_11( x[15:8] ) ^ mod_x_13( x[7:0] )},
        {mod_x_13( x[31:24] ) ^ mod_x_9( x[23:16] ) ^ mod_x_14( x[15:8] ) ^ mod_x_11( x[7:0] )},
        {mod_x_11( x[31:24] ) ^ mod_x_13( x[23:16] ) ^ mod_x_9( x[15:8] ) ^ mod_x_14( x[7:0] )}
    };
end
endfunction // inv_pre_mix

/*============================================================================*/
function [127:0] inv_mix_columns( input [127:0] state );
/*============================================================================*/
begin
    inv_mix_columns = {
        inv_pre_mix( state[127:96] ),
        inv_pre_mix( state[95:64] ),
        inv_pre_mix( state[63:32] ),
        inv_pre_mix( state[31:0] )
    };
end
endfunction // inv_mix_columns

/*============================================================================*/
function [127:0] inv_shift_rows( input [127:0] state );
/*============================================================================*/
    reg [7:0] r0[0:3];
    reg [7:0] r1[0:3];
    reg [7:0] r2[0:3];
    reg [7:0] r3[0:3];
begin
    {
    r0[0], r0[1], r0[2], r0[3],
    r1[0], r1[1], r1[2], r1[3],
    r2[0], r2[1], r2[2], r2[3],
    r3[0], r3[1], r3[2], r3[3]
    } = state;

    inv_shift_rows = {
        {r0[0], r3[1], r2[2], r1[3]},
        {r1[0], r0[1], r3[2], r2[3]},
        {r2[0], r1[1], r0[2], r3[3]},
        {r3[0], r2[1], r1[2], r0[3]}
    };
end
endfunction // inv_shift_rows

/*============================================================================*/
function [127:0] add_round_key( input [127:0] state, input [127:0] round_key );
/*============================================================================*/
begin
    add_round_key = state ^ round_key;
end
endfunction // add_round_key

reg [127:0] rkey = 0;
reg [31:0] rkey0;
reg [31:0] rkey1;
reg [31:0] rkey2;
reg [31:0] rkey3;
reg [7:0] rkey3_b = 0;
reg [7:0] sbox_rkey3_b0 = 0;
reg [7:0] sbox_rkey3_b1 = 0;
reg [7:0] sbox_rkey3_b2 = 0;
reg [7:0] sbox_rkey3_b3 = 0;
reg [7:0] rcon = 0;

wire [7:0] sbox_rkey3_b;
wire [31:0] sbox_rkey3;

/*============================================================================*/
always @(*) begin: inv_key_expansion
/*============================================================================*/
    rkey3 = rkey[31:0] ^ rkey[63:32];
    rkey2 = rkey[63:32] ^ rkey[95:64];
    rkey1 = rkey[95:64] ^ rkey[127:96];
    if ( CFG_MODE == "TINY" ) begin // Conditional synthesis!
        rkey0 = rkey[127:96] ^
            {sbox_rkey3_b2, sbox_rkey3_b1, sbox_rkey3_b0, sbox_rkey3_b3} ^
                {rcon, 24'h0};
    end
    else begin // Conditional synthesis!
        rkey0 = rkey[127:96] ^ {sbox_rkey3[23:0], sbox_rkey3[31:24]} ^
            {rcon, 24'h0};
    end
end // inv_key_expansion

reg aes_busy = 0;
reg [1:0] sbox_word_nb = 0;
reg [3:0] sbox_byte_nb = 0;
reg [3:0] round_count = 0;
reg [127:0] block = 0;
reg next_block = 0;
reg pre_rkey = 0;
reg add_rkey = 0;
reg next_rkey = 0;

wire round_gt_0; // Boolean round_count greater than zero

// Registers sbox0 CFG_MODE == "DEFAULT".
reg  [31:0] sbox_s0;
wire [31:0] sbox_out_s0;
// Registers sbox1-3 CFG_MODE == "FAST".
reg  [31:0] sbox_s1;
reg  [31:0] sbox_s2;
reg  [31:0] sbox_s3;
wire [31:0] sbox_out_s1;
wire [31:0] sbox_out_s2;
wire [31:0] sbox_out_s3;
// Registers sbox0 CFG_MODE == "TINY".
reg  [31:0] sbox_s_b;
wire [31:0] sbox_out_s_b;

reg [127:0] xor_block;
reg [127:0] inv_shift_rows_block;
reg [127:0] inv_mix_columns_block;

/*============================================================================*/
always @(*) begin : inv_pre_block
/*============================================================================*/
    xor_block             = add_round_key( block, rkey );
    inv_mix_columns_block = inv_mix_columns( xor_block );
    inv_shift_rows_block  = inv_shift_rows( inv_mix_columns_block );

    if ( CFG_MODE == "DEFAULT" ) begin // Conditional synthesis!
        case ( sbox_word_nb )
            2'd0 : sbox_s0 = block[127:96];
            2'd1 : sbox_s0 = block[95:64];
            2'd2 : sbox_s0 = block[63:32];
            2'd3 : sbox_s0 = block[31:0];
        endcase
    end
    if ( CFG_MODE == "FAST" ) begin // Conditional synthesis!
        sbox_s0 = block[127:96];
        sbox_s1 = block[95:64];
        sbox_s2 = block[63:32];
        sbox_s3 = block[31:0];
    end
    if ( CFG_MODE == "TINY" ) begin // Conditional synthesis!
        case ( sbox_byte_nb )
            4'd0  : sbox_s_b = block[127:120];
            4'd1  : sbox_s_b = block[119:112];
            4'd2  : sbox_s_b = block[111:104];
            4'd3  : sbox_s_b = block[103:96];
            4'd4  : sbox_s_b = block[95:88];
            4'd5  : sbox_s_b = block[87:80];
            4'd6  : sbox_s_b = block[79:72];
            4'd7  : sbox_s_b = block[71:64];
            4'd8  : sbox_s_b = block[63:56];
            4'd9  : sbox_s_b = block[55:48];
            4'd10 : sbox_s_b = block[47:40];
            4'd11 : sbox_s_b = block[39:32];
            4'd12 : sbox_s_b = block[31:24];
            4'd13 : sbox_s_b = block[23:16];
            4'd14 : sbox_s_b = block[15:8];
            4'd15 : sbox_s_b = block[7:0];
        endcase
    end
end // inv_pre_block

assign round_gt_0 = |round_count;

/*============================================================================*/
always @(posedge clk) begin : decipher
/*============================================================================*/
    add_rkey <= 0; // Pulse
    next_rkey <= 0; // Pulse
    if ( s_aes_valid && !aes_busy ) begin
        aes_busy <= 1;
        rkey <= s_aes_key;
        block <= inv_shift_rows( add_round_key( s_aes_block, s_aes_key ));
        sbox_word_nb <= 0;
        rcon <= 8'h36;
        if ( CFG_MODE == "TINY" ) begin // Conditional synthesis!
            round_count <= 4'd10;
            next_block <= 0;
            next_rkey <= 0;
            pre_rkey <= 1;
        end
        else begin
            round_count <= 4'd9;
            next_block <= 1;
            next_rkey <= 1;
        end
    end
    if ( next_block ) begin
        if ( CFG_MODE == "DEFAULT" ) begin // Conditional synthesis!
            sbox_word_nb <= sbox_word_nb + 2'd1;
            case ( sbox_word_nb )
                2'd0 : block[127:96] <= sbox_out_s0;
                2'd1 : block[95:64] <= sbox_out_s0;
                2'd2 : block[63:32] <= sbox_out_s0;
                2'd3 : begin
                    block[31:0] <= sbox_out_s0;
                    next_block <= 0;
                    add_rkey <= 1;
                    next_rkey <= round_gt_0;
                end
            endcase
        end
        if ( CFG_MODE == "FAST" ) begin // Conditional synthesis!
            block <= {sbox_out_s0, sbox_out_s1, sbox_out_s2, sbox_out_s3};
            next_block <= 0;
            add_rkey <= 1;
            next_rkey <= round_gt_0;
        end
        if ( CFG_MODE == "TINY" ) begin // Conditional synthesis!
            case ( sbox_byte_nb )
                4'd0  : block[127:120] <= sbox_out_s_b;
                4'd1  : block[119:112] <= sbox_out_s_b;
                4'd2  : block[111:104] <= sbox_out_s_b;
                4'd3  : block[103:96] <= sbox_out_s_b;
                4'd4  : block[95:88] <= sbox_out_s_b;
                4'd5  : block[87:80] <= sbox_out_s_b;
                4'd6  : block[79:72] <= sbox_out_s_b;
                4'd7  : block[71:64] <= sbox_out_s_b;
                4'd8  : block[63:56] <= sbox_out_s_b;
                4'd9  : block[55:48] <= sbox_out_s_b;
                4'd10 : block[47:40] <= sbox_out_s_b;
                4'd11 : block[39:32] <= sbox_out_s_b;
                4'd12 : block[31:24] <= sbox_out_s_b;
                4'd13 : block[23:16] <= sbox_out_s_b;
                4'd14 : block[15:8] <= sbox_out_s_b;
                4'd15 : begin
                    block[7:0] <= sbox_out_s_b;
                    next_block <= 0;
                    add_rkey <= 1;
                    next_rkey <= round_gt_0;
                end
            endcase
        end
    end
    if (( CFG_MODE == "TINY" ) && pre_rkey ) begin // Conditional synthesis!
        sbox_byte_nb <= sbox_byte_nb + 4'd1;
        case ( sbox_byte_nb )
            // Skip 0, because rkey is not valid yet when next_key = 1!
            4'd1  : rkey3_b <= rkey3[7:0];
            4'd2  : begin
                sbox_rkey3_b0 <= sbox_rkey3_b;
                rkey3_b <= rkey3[15:8];
            end
            4'd3  : begin
                sbox_rkey3_b1 <= sbox_rkey3_b;
                rkey3_b <= rkey3[23:16];
            end
            4'd4  : begin
                sbox_rkey3_b2 <= sbox_rkey3_b;
                rkey3_b <= rkey3[31:24];
            end
            4'd5  : begin
                sbox_rkey3_b3 <= sbox_rkey3_b;
                if ( 4'd10 == round_count ) begin
                    sbox_byte_nb <= 4'd0;
                    round_count <= 4'd9;
                    next_block <= 1;
                    next_rkey <= 1;
                end
            end
            4'd15 : pre_rkey <= 0;
        endcase
    end
    if ( add_rkey ) begin
        block <= add_round_key( block, rkey );
        aes_busy <= 0;
        if ( round_gt_0 ) begin
            block <= inv_shift_rows_block;
            round_count <= round_count - 4'd1;
            next_block <= 1;
            aes_busy <= 1;
            if ( CFG_MODE == "TINY" ) begin // Conditional synthesis!
                pre_rkey <= round_gt_0;
            end
        end
    end
    if ( next_rkey ) begin
        rkey <= {rkey0, rkey1, rkey2, rkey3};
        rcon <= mod_div_2( rcon );
    end
end // decipher

// Assignment outputs.
assign s_aes_ready = ~( s_aes_valid | aes_busy  );
assign m_aes_block = block;
assign round = round_count;
assign round_key = rkey;

localparam SBOX_TBL_SIZE = 256;
reg [7:0] sbox[0:SBOX_TBL_SIZE-1];
reg [7:0] sbox_inv[0:SBOX_TBL_SIZE-1];

generate
if ( CFG_MODE == "DEFAULT" ) begin
    assign sbox_rkey3[31:24] = sbox[rkey3[31:24]];
    assign sbox_rkey3[23:16] = sbox[rkey3[23:16]];
    assign sbox_rkey3[15:8]  = sbox[rkey3[15:8]];
    assign sbox_rkey3[7:0]   = sbox[rkey3[7:0]];

    assign sbox_out_s0[31:24] = sbox_inv[sbox_s0[31:24]];
    assign sbox_out_s0[23:16] = sbox_inv[sbox_s0[23:16]];
    assign sbox_out_s0[15:8]  = sbox_inv[sbox_s0[15:8]];
    assign sbox_out_s0[7:0]   = sbox_inv[sbox_s0[7:0]];
end
if ( CFG_MODE == "FAST" ) begin
    assign sbox_rkey3[31:24] = sbox[rkey3[31:24]];
    assign sbox_rkey3[23:16] = sbox[rkey3[23:16]];
    assign sbox_rkey3[15:8]  = sbox[rkey3[15:8]];
    assign sbox_rkey3[7:0]   = sbox[rkey3[7:0]];

    assign sbox_out_s0[31:24] = sbox_inv[sbox_s0[31:24]];
    assign sbox_out_s0[23:16] = sbox_inv[sbox_s0[23:16]];
    assign sbox_out_s0[15:8]  = sbox_inv[sbox_s0[15:8]];
    assign sbox_out_s0[7:0]   = sbox_inv[sbox_s0[7:0]];
    assign sbox_out_s1[31:24] = sbox_inv[sbox_s1[31:24]];
    assign sbox_out_s1[23:16] = sbox_inv[sbox_s1[23:16]];
    assign sbox_out_s1[15:8]  = sbox_inv[sbox_s1[15:8]];
    assign sbox_out_s1[7:0]   = sbox_inv[sbox_s1[7:0]];
    assign sbox_out_s2[31:24] = sbox_inv[sbox_s2[31:24]];
    assign sbox_out_s2[23:16] = sbox_inv[sbox_s2[23:16]];
    assign sbox_out_s2[15:8]  = sbox_inv[sbox_s2[15:8]];
    assign sbox_out_s2[7:0]   = sbox_inv[sbox_s2[7:0]];
    assign sbox_out_s3[31:24] = sbox_inv[sbox_s3[31:24]];
    assign sbox_out_s3[23:16] = sbox_inv[sbox_s3[23:16]];
    assign sbox_out_s3[15:8]  = sbox_inv[sbox_s3[15:8]];
    assign sbox_out_s3[7:0]   = sbox_inv[sbox_s3[7:0]];
end
if ( CFG_MODE == "TINY" ) begin
    assign sbox_rkey3_b = sbox[rkey3_b];
    assign sbox_out_s_b = sbox_inv[sbox_s_b];
end
endgenerate

integer m;
/*============================================================================*/
initial begin : init_sbox // AES (inverse) substitution box
/*============================================================================*/
    for ( m = 0; m < SBOX_TBL_SIZE; m = m + 1 ) begin
        sbox[m] = sbox_calc( m );
        sbox_inv[m] = sbox_inv_calc( m );
    end
end // init_sbox

endmodule // aes_enc
