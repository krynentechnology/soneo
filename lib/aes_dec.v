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
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module aes_dec #(
/*============================================================================*/
    parameter [0:0] FAST_MODE = 1 ) // 1 == faster at extra logic cost
    (
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
wire [31:0] sbox_rkey3;
reg next_rkey = 0;
reg [7:0] rcon = 0;

/*============================================================================*/
always @(*) begin: inv_key_expansion
/*============================================================================*/
    rkey3 = rkey[31:0] ^ rkey[63:32];
    rkey2 = rkey[63:32] ^ rkey[95:64];
    rkey1 = rkey[95:64] ^ rkey[127:96];
    rkey0 = rkey[127:96] ^ {sbox_rkey3[23:0], sbox_rkey3[31:24]} ^ {rcon, 24'h0};
end // inv_key_expansion

reg [1:0] sbox_word_nb = 0;
reg [3:0] round_count = 0;
reg [127:0] block = 0;
reg next_block = 0;
reg add_rkey = 0;
wire aes_busy;
wire round_gt_0; // Boolean round_count greater than zero

// Registers sbox0 FAST_MODE = 0.
reg  [31:0] sbox_s0;
wire [31:0] sbox_out_s0;
// Registers sbox1-3 FAST_MODE = 1.
reg  [31:0] sbox_s1;
reg  [31:0] sbox_s2;
reg  [31:0] sbox_s3;
wire [31:0] sbox_out_s1;
wire [31:0] sbox_out_s2;
wire [31:0] sbox_out_s3;

reg [127:0] xor_block;
reg [127:0] inv_shift_rows_block;
reg [127:0] inv_mix_columns_block;

/*============================================================================*/
always @(*) begin : inv_pre_block
/*============================================================================*/
    xor_block             = add_round_key( block, rkey );
    inv_mix_columns_block = inv_mix_columns( xor_block );
    inv_shift_rows_block  = inv_shift_rows( inv_mix_columns_block );

    if ( FAST_MODE ) begin // Conditional synthesis!
        sbox_s0 = block[127:96];
        sbox_s1 = block[95:64];
        sbox_s2 = block[63:32];
        sbox_s3 = block[31:0];
    end
    else begin // Conditional synthesis!
        case ( sbox_word_nb )
            0 : sbox_s0 = block[127:96];
            1 : sbox_s0 = block[95:64];
            2 : sbox_s0 = block[63:32];
            3 : sbox_s0 = block[31:0];
        endcase
    end
end // inv_pre_block

assign aes_busy = next_block | add_rkey;
assign round_gt_0 = |round_count;

/*============================================================================*/
always @(posedge clk) begin : decipher
/*============================================================================*/
    add_rkey <= 0; // Pulse
    next_rkey <= 0; // Pulse
    if ( s_aes_valid && !aes_busy ) begin
        rkey <= s_aes_key;
        block <= inv_shift_rows( add_round_key( s_aes_block, s_aes_key ));
        sbox_word_nb <= 0;
        round_count <= 9;
        next_block <= 1;
        next_rkey <= 1;
        rcon <= 8'h36;
    end
    if ( next_block ) begin
        if ( FAST_MODE ) begin // Conditional synthesis!
            block <= {sbox_out_s0, sbox_out_s1, sbox_out_s2, sbox_out_s3};
            next_block <= 0;
            add_rkey <= 1;
            next_rkey <= round_gt_0;
        end
        else begin // Conditional synthesis!
            sbox_word_nb <= sbox_word_nb + 1;
            case ( sbox_word_nb )
                0 : block[127:96] <= sbox_out_s0;
                1 : block[95:64]  <= sbox_out_s0;
                2 : block[63:32]  <= sbox_out_s0;
                3 : begin
                    block[31:0]   <= sbox_out_s0;
                    next_block <= 0;
                    add_rkey <= 1;
                    next_rkey <= round_gt_0;
                end
            endcase
        end
    end
    if ( add_rkey ) begin
        block <= add_round_key( block, rkey );
        if ( round_gt_0 ) begin
            block <= inv_shift_rows_block;
            round_count <= round_count - 1;
            next_block <= 1;
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

reg [7:0] sbox[0:255];
reg [7:0] inv_sbox[0:255];
assign sbox_rkey3[31:24] = sbox[rkey3[31:24]];
assign sbox_rkey3[23:16] = sbox[rkey3[23:16]];
assign sbox_rkey3[15:8]  = sbox[rkey3[15:8]];
assign sbox_rkey3[7:0]   = sbox[rkey3[7:0]];

generate
if ( !FAST_MODE ) begin
    assign sbox_out_s0[31:24] = inv_sbox[sbox_s0[31:24]];
    assign sbox_out_s0[23:16] = inv_sbox[sbox_s0[23:16]];
    assign sbox_out_s0[15:8]  = inv_sbox[sbox_s0[15:8]];
    assign sbox_out_s0[7:0]   = inv_sbox[sbox_s0[7:0]];
end
if ( FAST_MODE ) begin
    assign sbox_out_s0[31:24] = inv_sbox[sbox_s0[31:24]];
    assign sbox_out_s0[23:16] = inv_sbox[sbox_s0[23:16]];
    assign sbox_out_s0[15:8]  = inv_sbox[sbox_s0[15:8]];
    assign sbox_out_s0[7:0]   = inv_sbox[sbox_s0[7:0]];
    assign sbox_out_s1[31:24] = inv_sbox[sbox_s1[31:24]];
    assign sbox_out_s1[23:16] = inv_sbox[sbox_s1[23:16]];
    assign sbox_out_s1[15:8]  = inv_sbox[sbox_s1[15:8]];
    assign sbox_out_s1[7:0]   = inv_sbox[sbox_s1[7:0]];
    assign sbox_out_s2[31:24] = inv_sbox[sbox_s2[31:24]];
    assign sbox_out_s2[23:16] = inv_sbox[sbox_s2[23:16]];
    assign sbox_out_s2[15:8]  = inv_sbox[sbox_s2[15:8]];
    assign sbox_out_s2[7:0]   = inv_sbox[sbox_s2[7:0]];
    assign sbox_out_s3[31:24] = inv_sbox[sbox_s3[31:24]];
    assign sbox_out_s3[23:16] = inv_sbox[sbox_s3[23:16]];
    assign sbox_out_s3[15:8]  = inv_sbox[sbox_s3[15:8]];
    assign sbox_out_s3[7:0]   = inv_sbox[sbox_s3[7:0]];
end
endgenerate

/*============================================================================*/
initial begin : init_sbox // AES substitution box
/*============================================================================*/
    sbox[0]   = 8'h63; sbox[1]   = 8'h7C; sbox[2]   = 8'h77; sbox[3]   = 8'h7B;
    sbox[4]   = 8'hF2; sbox[5]   = 8'h6B; sbox[6]   = 8'h6F; sbox[7]   = 8'hC5;
    sbox[8]   = 8'h30; sbox[9]   = 8'h01; sbox[10]  = 8'h67; sbox[11]  = 8'h2B;
    sbox[12]  = 8'hFE; sbox[13]  = 8'hD7; sbox[14]  = 8'hAB; sbox[15]  = 8'h76;
    sbox[16]  = 8'hCA; sbox[17]  = 8'h82; sbox[18]  = 8'hC9; sbox[19]  = 8'h7D;
    sbox[20]  = 8'hFA; sbox[21]  = 8'h59; sbox[22]  = 8'h47; sbox[23]  = 8'hF0;
    sbox[24]  = 8'hAD; sbox[25]  = 8'hD4; sbox[26]  = 8'hA2; sbox[27]  = 8'hAF;
    sbox[28]  = 8'h9C; sbox[29]  = 8'hA4; sbox[30]  = 8'h72; sbox[31]  = 8'hC0;
    sbox[32]  = 8'hB7; sbox[33]  = 8'hFD; sbox[34]  = 8'h93; sbox[35]  = 8'h26;
    sbox[36]  = 8'h36; sbox[37]  = 8'h3F; sbox[38]  = 8'hF7; sbox[39]  = 8'hCC;
    sbox[40]  = 8'h34; sbox[41]  = 8'hA5; sbox[42]  = 8'hE5; sbox[43]  = 8'hF1;
    sbox[44]  = 8'h71; sbox[45]  = 8'hD8; sbox[46]  = 8'h31; sbox[47]  = 8'h15;
    sbox[48]  = 8'h04; sbox[49]  = 8'hC7; sbox[50]  = 8'h23; sbox[51]  = 8'hC3;
    sbox[52]  = 8'h18; sbox[53]  = 8'h96; sbox[54]  = 8'h05; sbox[55]  = 8'h9A;
    sbox[56]  = 8'h07; sbox[57]  = 8'h12; sbox[58]  = 8'h80; sbox[59]  = 8'hE2;
    sbox[60]  = 8'hEB; sbox[61]  = 8'h27; sbox[62]  = 8'hB2; sbox[63]  = 8'h75;
    sbox[64]  = 8'h09; sbox[65]  = 8'h83; sbox[66]  = 8'h2C; sbox[67]  = 8'h1A;
    sbox[68]  = 8'h1B; sbox[69]  = 8'h6E; sbox[70]  = 8'h5A; sbox[71]  = 8'hA0;
    sbox[72]  = 8'h52; sbox[73]  = 8'h3B; sbox[74]  = 8'hD6; sbox[75]  = 8'hB3;
    sbox[76]  = 8'h29; sbox[77]  = 8'hE3; sbox[78]  = 8'h2F; sbox[79]  = 8'h84;
    sbox[80]  = 8'h53; sbox[81]  = 8'hD1; sbox[82]  = 8'h00; sbox[83]  = 8'hED;
    sbox[84]  = 8'h20; sbox[85]  = 8'hFC; sbox[86]  = 8'hB1; sbox[87]  = 8'h5B;
    sbox[88]  = 8'h6A; sbox[89]  = 8'hCB; sbox[90]  = 8'hBE; sbox[91]  = 8'h39;
    sbox[92]  = 8'h4A; sbox[93]  = 8'h4C; sbox[94]  = 8'h58; sbox[95]  = 8'hCF;
    sbox[96]  = 8'hD0; sbox[97]  = 8'hEF; sbox[98]  = 8'hAA; sbox[99]  = 8'hFB;
    sbox[100] = 8'h43; sbox[101] = 8'h4D; sbox[102] = 8'h33; sbox[103] = 8'h85;
    sbox[104] = 8'h45; sbox[105] = 8'hF9; sbox[106] = 8'h02; sbox[107] = 8'h7F;
    sbox[108] = 8'h50; sbox[109] = 8'h3C; sbox[110] = 8'h9F; sbox[111] = 8'hA8;
    sbox[112] = 8'h51; sbox[113] = 8'hA3; sbox[114] = 8'h40; sbox[115] = 8'h8F;
    sbox[116] = 8'h92; sbox[117] = 8'h9D; sbox[118] = 8'h38; sbox[119] = 8'hF5;
    sbox[120] = 8'hBC; sbox[121] = 8'hB6; sbox[122] = 8'hDA; sbox[123] = 8'h21;
    sbox[124] = 8'h10; sbox[125] = 8'hFF; sbox[126] = 8'hF3; sbox[127] = 8'hD2;
    sbox[128] = 8'hCD; sbox[129] = 8'h0C; sbox[130] = 8'h13; sbox[131] = 8'hEC;
    sbox[132] = 8'h5F; sbox[133] = 8'h97; sbox[134] = 8'h44; sbox[135] = 8'h17;
    sbox[136] = 8'hC4; sbox[137] = 8'hA7; sbox[138] = 8'h7E; sbox[139] = 8'h3D;
    sbox[140] = 8'h64; sbox[141] = 8'h5D; sbox[142] = 8'h19; sbox[143] = 8'h73;
    sbox[144] = 8'h60; sbox[145] = 8'h81; sbox[146] = 8'h4F; sbox[147] = 8'hDC;
    sbox[148] = 8'h22; sbox[149] = 8'h2A; sbox[150] = 8'h90; sbox[151] = 8'h88;
    sbox[152] = 8'h46; sbox[153] = 8'hEE; sbox[154] = 8'hB8; sbox[155] = 8'h14;
    sbox[156] = 8'hDE; sbox[157] = 8'h5E; sbox[158] = 8'h0B; sbox[159] = 8'hDB;
    sbox[160] = 8'hE0; sbox[161] = 8'h32; sbox[162] = 8'h3A; sbox[163] = 8'h0A;
    sbox[164] = 8'h49; sbox[165] = 8'h06; sbox[166] = 8'h24; sbox[167] = 8'h5C;
    sbox[168] = 8'hC2; sbox[169] = 8'hD3; sbox[170] = 8'hAC; sbox[171] = 8'h62;
    sbox[172] = 8'h91; sbox[173] = 8'h95; sbox[174] = 8'hE4; sbox[175] = 8'h79;
    sbox[176] = 8'hE7; sbox[177] = 8'hC8; sbox[178] = 8'h37; sbox[179] = 8'h6D;
    sbox[180] = 8'h8D; sbox[181] = 8'hD5; sbox[182] = 8'h4E; sbox[183] = 8'hA9;
    sbox[184] = 8'h6C; sbox[185] = 8'h56; sbox[186] = 8'hF4; sbox[187] = 8'hEA;
    sbox[188] = 8'h65; sbox[189] = 8'h7A; sbox[190] = 8'hAE; sbox[191] = 8'h08;
    sbox[192] = 8'hBA; sbox[193] = 8'h78; sbox[194] = 8'h25; sbox[195] = 8'h2E;
    sbox[196] = 8'h1C; sbox[197] = 8'hA6; sbox[198] = 8'hB4; sbox[199] = 8'hC6;
    sbox[200] = 8'hE8; sbox[201] = 8'hDD; sbox[202] = 8'h74; sbox[203] = 8'h1F;
    sbox[204] = 8'h4B; sbox[205] = 8'hBD; sbox[206] = 8'h8B; sbox[207] = 8'h8A;
    sbox[208] = 8'h70; sbox[209] = 8'h3E; sbox[210] = 8'hB5; sbox[211] = 8'h66;
    sbox[212] = 8'h48; sbox[213] = 8'h03; sbox[214] = 8'hF6; sbox[215] = 8'h0E;
    sbox[216] = 8'h61; sbox[217] = 8'h35; sbox[218] = 8'h57; sbox[219] = 8'hB9;
    sbox[220] = 8'h86; sbox[221] = 8'hC1; sbox[222] = 8'h1D; sbox[223] = 8'h9E;
    sbox[224] = 8'hE1; sbox[225] = 8'hF8; sbox[226] = 8'h98; sbox[227] = 8'h11;
    sbox[228] = 8'h69; sbox[229] = 8'hD9; sbox[230] = 8'h8E; sbox[231] = 8'h94;
    sbox[232] = 8'h9B; sbox[233] = 8'h1E; sbox[234] = 8'h87; sbox[235] = 8'hE9;
    sbox[236] = 8'hCE; sbox[237] = 8'h55; sbox[238] = 8'h28; sbox[239] = 8'hDF;
    sbox[240] = 8'h8C; sbox[241] = 8'hA1; sbox[242] = 8'h89; sbox[243] = 8'h0D;
    sbox[244] = 8'hBF; sbox[245] = 8'hE6; sbox[246] = 8'h42; sbox[247] = 8'h68;
    sbox[248] = 8'h41; sbox[249] = 8'h99; sbox[250] = 8'h2D; sbox[251] = 8'h0F;
    sbox[252] = 8'hB0; sbox[253] = 8'h54; sbox[254] = 8'hBB; sbox[255] = 8'h16;
end // init_sbox

/*============================================================================*/
initial begin : init_inv_sbox // AES inverse substitution box
/*============================================================================*/
    inv_sbox[0]   = 8'h52; inv_sbox[1]   = 8'h09; inv_sbox[2]   = 8'h6A; inv_sbox[3]   = 8'hD5;
    inv_sbox[4]   = 8'h30; inv_sbox[5]   = 8'h36; inv_sbox[6]   = 8'hA5; inv_sbox[7]   = 8'h38;
    inv_sbox[8]   = 8'hBF; inv_sbox[9]   = 8'h40; inv_sbox[10]  = 8'hA3; inv_sbox[11]  = 8'h9E;
    inv_sbox[12]  = 8'h81; inv_sbox[13]  = 8'hF3; inv_sbox[14]  = 8'hD7; inv_sbox[15]  = 8'hFB;
    inv_sbox[16]  = 8'h7C; inv_sbox[17]  = 8'hE3; inv_sbox[18]  = 8'h39; inv_sbox[19]  = 8'h82;
    inv_sbox[20]  = 8'h9B; inv_sbox[21]  = 8'h2F; inv_sbox[22]  = 8'hFF; inv_sbox[23]  = 8'h87;
    inv_sbox[24]  = 8'h34; inv_sbox[25]  = 8'h8E; inv_sbox[26]  = 8'h43; inv_sbox[27]  = 8'h44;
    inv_sbox[28]  = 8'hC4; inv_sbox[29]  = 8'hDE; inv_sbox[30]  = 8'hE9; inv_sbox[31]  = 8'hCB;
    inv_sbox[32]  = 8'h54; inv_sbox[33]  = 8'h7B; inv_sbox[34]  = 8'h94; inv_sbox[35]  = 8'h32;
    inv_sbox[36]  = 8'hA6; inv_sbox[37]  = 8'hC2; inv_sbox[38]  = 8'h23; inv_sbox[39]  = 8'h3D;
    inv_sbox[40]  = 8'hEE; inv_sbox[41]  = 8'h4C; inv_sbox[42]  = 8'h95; inv_sbox[43]  = 8'h0B;
    inv_sbox[44]  = 8'h42; inv_sbox[45]  = 8'hFA; inv_sbox[46]  = 8'hC3; inv_sbox[47]  = 8'h4E;
    inv_sbox[48]  = 8'h08; inv_sbox[49]  = 8'h2E; inv_sbox[50]  = 8'hA1; inv_sbox[51]  = 8'h66;
    inv_sbox[52]  = 8'h28; inv_sbox[53]  = 8'hD9; inv_sbox[54]  = 8'h24; inv_sbox[55]  = 8'hB2;
    inv_sbox[56]  = 8'h76; inv_sbox[57]  = 8'h5B; inv_sbox[58]  = 8'hA2; inv_sbox[59]  = 8'h49;
    inv_sbox[60]  = 8'h6D; inv_sbox[61]  = 8'h8B; inv_sbox[62]  = 8'hD1; inv_sbox[63]  = 8'h25;
    inv_sbox[64]  = 8'h72; inv_sbox[65]  = 8'hF8; inv_sbox[66]  = 8'hF6; inv_sbox[67]  = 8'h64;
    inv_sbox[68]  = 8'h86; inv_sbox[69]  = 8'h68; inv_sbox[70]  = 8'h98; inv_sbox[71]  = 8'h16;
    inv_sbox[72]  = 8'hD4; inv_sbox[73]  = 8'hA4; inv_sbox[74]  = 8'h5C; inv_sbox[75]  = 8'hCC;
    inv_sbox[76]  = 8'h5D; inv_sbox[77]  = 8'h65; inv_sbox[78]  = 8'hB6; inv_sbox[79]  = 8'h92;
    inv_sbox[80]  = 8'h6C; inv_sbox[81]  = 8'h70; inv_sbox[82]  = 8'h48; inv_sbox[83]  = 8'h50;
    inv_sbox[84]  = 8'hFD; inv_sbox[85]  = 8'hED; inv_sbox[86]  = 8'hB9; inv_sbox[87]  = 8'hDA;
    inv_sbox[88]  = 8'h5E; inv_sbox[89]  = 8'h15; inv_sbox[90]  = 8'h46; inv_sbox[91]  = 8'h57;
    inv_sbox[92]  = 8'hA7; inv_sbox[93]  = 8'h8D; inv_sbox[94]  = 8'h9D; inv_sbox[95]  = 8'h84;
    inv_sbox[96]  = 8'h90; inv_sbox[97]  = 8'hD8; inv_sbox[98]  = 8'hAB; inv_sbox[99]  = 8'h00;
    inv_sbox[100] = 8'h8C; inv_sbox[101] = 8'hBC; inv_sbox[102] = 8'hD3; inv_sbox[103] = 8'h0A;
    inv_sbox[104] = 8'hF7; inv_sbox[105] = 8'hE4; inv_sbox[106] = 8'h58; inv_sbox[107] = 8'h05;
    inv_sbox[108] = 8'hB8; inv_sbox[109] = 8'hB3; inv_sbox[110] = 8'h45; inv_sbox[111] = 8'h06;
    inv_sbox[112] = 8'hD0; inv_sbox[113] = 8'h2C; inv_sbox[114] = 8'h1E; inv_sbox[115] = 8'h8F;
    inv_sbox[116] = 8'hCA; inv_sbox[117] = 8'h3F; inv_sbox[118] = 8'h0F; inv_sbox[119] = 8'h02;
    inv_sbox[120] = 8'hC1; inv_sbox[121] = 8'hAF; inv_sbox[122] = 8'hBD; inv_sbox[123] = 8'h03;
    inv_sbox[124] = 8'h01; inv_sbox[125] = 8'h13; inv_sbox[126] = 8'h8A; inv_sbox[127] = 8'h6B;
    inv_sbox[128] = 8'h3A; inv_sbox[129] = 8'h91; inv_sbox[130] = 8'h11; inv_sbox[131] = 8'h41;
    inv_sbox[132] = 8'h4F; inv_sbox[133] = 8'h67; inv_sbox[134] = 8'hDC; inv_sbox[135] = 8'hEA;
    inv_sbox[136] = 8'h97; inv_sbox[137] = 8'hF2; inv_sbox[138] = 8'hCF; inv_sbox[139] = 8'hCE;
    inv_sbox[140] = 8'hF0; inv_sbox[141] = 8'hB4; inv_sbox[142] = 8'hE6; inv_sbox[143] = 8'h73;
    inv_sbox[144] = 8'h96; inv_sbox[145] = 8'hAC; inv_sbox[146] = 8'h74; inv_sbox[147] = 8'h22;
    inv_sbox[148] = 8'hE7; inv_sbox[149] = 8'hAD; inv_sbox[150] = 8'h35; inv_sbox[151] = 8'h85;
    inv_sbox[152] = 8'hE2; inv_sbox[153] = 8'hF9; inv_sbox[154] = 8'h37; inv_sbox[155] = 8'hE8;
    inv_sbox[156] = 8'h1C; inv_sbox[157] = 8'h75; inv_sbox[158] = 8'hDF; inv_sbox[159] = 8'h6E;
    inv_sbox[160] = 8'h47; inv_sbox[161] = 8'hF1; inv_sbox[162] = 8'h1A; inv_sbox[163] = 8'h71;
    inv_sbox[164] = 8'h1D; inv_sbox[165] = 8'h29; inv_sbox[166] = 8'hC5; inv_sbox[167] = 8'h89;
    inv_sbox[168] = 8'h6F; inv_sbox[169] = 8'hB7; inv_sbox[170] = 8'h62; inv_sbox[171] = 8'h0E;
    inv_sbox[172] = 8'hAA; inv_sbox[173] = 8'h18; inv_sbox[174] = 8'hBE; inv_sbox[175] = 8'h1B;
    inv_sbox[176] = 8'hFC; inv_sbox[177] = 8'h56; inv_sbox[178] = 8'h3E; inv_sbox[179] = 8'h4B;
    inv_sbox[180] = 8'hC6; inv_sbox[181] = 8'hD2; inv_sbox[182] = 8'h79; inv_sbox[183] = 8'h20;
    inv_sbox[184] = 8'h9A; inv_sbox[185] = 8'hDB; inv_sbox[186] = 8'hC0; inv_sbox[187] = 8'hFE;
    inv_sbox[188] = 8'h78; inv_sbox[189] = 8'hCD; inv_sbox[190] = 8'h5A; inv_sbox[191] = 8'hF4;
    inv_sbox[192] = 8'h1F; inv_sbox[193] = 8'hDD; inv_sbox[194] = 8'hA8; inv_sbox[195] = 8'h33;
    inv_sbox[196] = 8'h88; inv_sbox[197] = 8'h07; inv_sbox[198] = 8'hC7; inv_sbox[199] = 8'h31;
    inv_sbox[200] = 8'hB1; inv_sbox[201] = 8'h12; inv_sbox[202] = 8'h10; inv_sbox[203] = 8'h59;
    inv_sbox[204] = 8'h27; inv_sbox[205] = 8'h80; inv_sbox[206] = 8'hEC; inv_sbox[207] = 8'h5F;
    inv_sbox[208] = 8'h60; inv_sbox[209] = 8'h51; inv_sbox[210] = 8'h7F; inv_sbox[211] = 8'hA9;
    inv_sbox[212] = 8'h19; inv_sbox[213] = 8'hB5; inv_sbox[214] = 8'h4A; inv_sbox[215] = 8'h0D;
    inv_sbox[216] = 8'h2D; inv_sbox[217] = 8'hE5; inv_sbox[218] = 8'h7A; inv_sbox[219] = 8'h9F;
    inv_sbox[220] = 8'h93; inv_sbox[221] = 8'hC9; inv_sbox[222] = 8'h9C; inv_sbox[223] = 8'hEF;
    inv_sbox[224] = 8'hA0; inv_sbox[225] = 8'hE0; inv_sbox[226] = 8'h3B; inv_sbox[227] = 8'h4D;
    inv_sbox[228] = 8'hAE; inv_sbox[229] = 8'h2A; inv_sbox[230] = 8'hF5; inv_sbox[231] = 8'hB0;
    inv_sbox[232] = 8'hC8; inv_sbox[233] = 8'hEB; inv_sbox[234] = 8'hBB; inv_sbox[235] = 8'h3C;
    inv_sbox[236] = 8'h83; inv_sbox[237] = 8'h53; inv_sbox[238] = 8'h99; inv_sbox[239] = 8'h61;
    inv_sbox[240] = 8'h17; inv_sbox[241] = 8'h2B; inv_sbox[242] = 8'h04; inv_sbox[243] = 8'h7E;
    inv_sbox[244] = 8'hBA; inv_sbox[245] = 8'h77; inv_sbox[246] = 8'hD6; inv_sbox[247] = 8'h26;
    inv_sbox[248] = 8'hE1; inv_sbox[249] = 8'h69; inv_sbox[250] = 8'h14; inv_sbox[251] = 8'h63;
    inv_sbox[252] = 8'h55; inv_sbox[253] = 8'h21; inv_sbox[254] = 8'h0C; inv_sbox[255] = 8'h7D;
end // init_inv_sbox

endmodule // aes_enc
