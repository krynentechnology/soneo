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
 *  Description: Test bench for AES encipher keylength 128. Examples from:
 *
 *  https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38a.pdf
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module aes_enc_tb();
/*============================================================================*/

reg clk = 0;

reg [127:0] s_aes_block = 0;
reg s_aes_enc_valid = 0;
reg s_aes_dec_valid = 0;

wire s_aes_ready0;
wire [127:0] m_aes_block0;
wire [3:0] round0;
wire [127:0] round_key0;

wire s_aes_ready1;
wire [127:0] m_aes_block1;
wire [3:0] round1;
wire [127:0] round_key1;

wire s_aes_ready2;
wire [127:0] m_aes_block2;
wire [3:0] round2;
wire [127:0] round_key2;

wire s_aes_ready3;
wire [127:0] m_aes_block3;
wire [3:0] round3;
wire [127:0] round_key3;

wire s_aes_ready4;
wire [127:0] m_aes_block4;
wire [3:0] round4;
wire [127:0] round_key4;

wire s_aes_ready5;
wire [127:0] m_aes_block5;
wire [3:0] round5;
wire [127:0] round_key5;

reg [127:0] rkey[0:10];

aes_enc aes_enc0(
    .clk(clk),
    .s_aes_key(rkey[0]),
    .s_aes_block(s_aes_block),
    .s_aes_valid(s_aes_enc_valid),
    .s_aes_ready(s_aes_ready0),
    .m_aes_block(m_aes_block0),
    .round(round0),
    .round_key(round_key0)
    );

defparam aes_enc0.CFG_MODE = "DEFAULT";

aes_enc aes_enc1(
    .clk(clk),
    .s_aes_key(rkey[0]),
    .s_aes_block(s_aes_block),
    .s_aes_valid(s_aes_enc_valid),
    .s_aes_ready(s_aes_ready1),
    .m_aes_block(m_aes_block1),
    .round(round1),
    .round_key(round_key1)
    );

defparam aes_enc1.CFG_MODE = "FAST";

aes_enc aes_enc2(
    .clk(clk),
    .s_aes_key(rkey[0]),
    .s_aes_block(s_aes_block),
    .s_aes_valid(s_aes_enc_valid),
    .s_aes_ready(s_aes_ready2),
    .m_aes_block(m_aes_block2),
    .round(round2),
    .round_key(round_key2)
    );

defparam aes_enc2.CFG_MODE = "TINY";

aes_dec aes_dec0(
    .clk(clk),
    .s_aes_key(rkey[10]),
    .s_aes_block(s_aes_block),
    .s_aes_valid(s_aes_dec_valid),
    .s_aes_ready(s_aes_ready3),
    .m_aes_block(m_aes_block3),
    .round(round3),
    .round_key(round_key3)
    );

defparam aes_dec0.CFG_MODE = "DEFAULT";

aes_dec aes_dec1(
    .clk(clk),
    .s_aes_key(rkey[10]),
    .s_aes_block(s_aes_block),
    .s_aes_valid(s_aes_dec_valid),
    .s_aes_ready(s_aes_ready4),
    .m_aes_block(m_aes_block4),
    .round(round4),
    .round_key(round_key4)
    );

defparam aes_dec1.CFG_MODE = "FAST";

aes_dec aes_dec2(
    .clk(clk),
    .s_aes_key(rkey[10]),
    .s_aes_block(s_aes_block),
    .s_aes_valid(s_aes_dec_valid),
    .s_aes_ready(s_aes_ready5),
    .m_aes_block(m_aes_block5),
    .round(round5),
    .round_key(round_key5)
    );

defparam aes_dec2.CFG_MODE = "TINY";

always #5 clk = ~clk; // 100MHz

/*============================================================================*/
initial begin
/*============================================================================*/
    // NIST 128 bit example keys
    rkey[0]  = 128'h2b7e151628aed2a6abf7158809cf4f3c; // Encipher key
    rkey[1]  = 128'ha0fafe1788542cb123a339392a6c7605;
    rkey[2]  = 128'hf2c295f27a96b9435935807a7359f67f;
    rkey[3]  = 128'h3d80477d4716fe3e1e237e446d7a883b;
    rkey[4]  = 128'hef44a541a8525b7fb671253bdb0bad00;
    rkey[5]  = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
    rkey[6]  = 128'h6d88a37a110b3efddbf98641ca0093fd;
    rkey[7]  = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
    rkey[8]  = 128'head27321b58dbad2312bf5607f8d292f;
    rkey[9]  = 128'hac7766f319fadc2128d12941575c006e;
    rkey[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6; // Decipher key
end

reg passed_enc = 0;
/*============================================================================*/
task test_enc( input [127:0] block, input[127:0] block_expected );
/*============================================================================*/
begin
    s_aes_block = block;
    wait ( s_aes_ready0 && s_aes_ready1 && s_aes_ready2 )
    wait ( clk ) @( negedge clk )
    wait ( clk ) @( negedge clk )
    s_aes_enc_valid = 1;
    wait ( clk ) @( negedge clk )
    s_aes_enc_valid = 0;
    wait ( clk ) @( negedge clk )
    wait ( s_aes_ready0 && s_aes_ready1 && s_aes_ready2 )
    passed_enc = ( block_expected == m_aes_block0 ) &&
        ( block_expected == m_aes_block1 ) &&
        ( block_expected == m_aes_block2 );
//    $display( "Block %0x expected", block_expected );
//    $display( "Block %0x m_aes_block0", m_aes_block0 );
//    $display( "Block %0x m_aes_block1", m_aes_block1 );
//    $display( "Block %0x m_aes_block2", m_aes_block2 );
    $display( "Block %0x test %s", block, passed_enc ? "passed" : "failed" );
    wait ( clk ) @( negedge clk );
end
endtask

reg passed_dec = 0;
/*============================================================================*/
task test_dec( input [127:0] block, input[127:0] block_expected );
/*============================================================================*/
begin
    s_aes_block = block;
    wait ( s_aes_ready3 && s_aes_ready4 && s_aes_ready5 )
    wait ( clk ) @( negedge clk )
    wait ( clk ) @( negedge clk )
    s_aes_dec_valid = 1;
    wait ( clk ) @( negedge clk )
    s_aes_dec_valid = 0;
    wait ( clk ) @( negedge clk )
    wait ( s_aes_ready3 && s_aes_ready4 && s_aes_ready5 )
    passed_dec = ( block_expected == m_aes_block3 ) &&
        ( block_expected == m_aes_block4 ) &&
        ( block_expected == m_aes_block5 );
//    $display( "Block %0x expected", block_expected );
//    $display( "Block %0x m_aes_block3", m_aes_block3 );
//    $display( "Block %0x m_aes_block4", m_aes_block4 );
//    $display( "Block %0x m_aes_block5", m_aes_block5 );
    $display( "Block %0x test %s", block, passed_dec ? "passed" : "failed" );
    wait ( clk ) @( negedge clk );
end
endtask

reg passed = 0;
/*============================================================================*/
initial begin : test
/*============================================================================*/
    $display( "AES encipher test started" );
    #100 // 0.1us
    test_enc( 128'h6bc1bee22e409f96e93d7e117393172a, // NIST ECB example vector
        128'h3ad77bb40d7a3660a89ecaf32466ef97 );
    test_enc( 128'hae2d8a571e03ac9c9eb76fac45af8e51, // NIST ECB example vector
        128'hf5d3d58503b9699de785895a96fdbaaf );
    test_enc( 128'h30c81c46a35ce411e5fbc1191a0a52ef, // NIST ECB example vector
        128'h43b1cd7f598ece23881b00e3ed030688 );
    test_enc( 128'hf69f2445df4f9b17ad2b417be66c3710, // NIST ECB example vector
        128'h7b0c785e27e8ad3f8223207104725dd4 );
    passed = ( rkey[10] == round_key0 ) &&
        ( rkey[10] == round_key1 ) &&
        ( rkey[10] == round_key2 );
    $display( "Round [10] key (decipher key) test %s", passed ? "passed" : "failed" );
    #100 // 0.1us
    $display( "AES decipher test started" );
    test_dec( 128'h3ad77bb40d7a3660a89ecaf32466ef97, // NIST ECB example vector
        128'h6bc1bee22e409f96e93d7e117393172a );
    test_dec( 128'hf5d3d58503b9699de785895a96fdbaaf, // NIST ECB example vector
        128'hae2d8a571e03ac9c9eb76fac45af8e51 );
    test_dec( 128'h43b1cd7f598ece23881b00e3ed030688, // NIST ECB example vector
        128'h30c81c46a35ce411e5fbc1191a0a52ef );
    test_dec( 128'h7b0c785e27e8ad3f8223207104725dd4, // NIST ECB example vector
        128'hf69f2445df4f9b17ad2b417be66c3710 );
    passed = ( rkey[0] == round_key3 ) &&
        ( rkey[0] == round_key4 ) &&
        ( rkey[0] == round_key5 );
    $display( "Round [0] key (encipher key) test %s", passed ? "passed" : "failed" );
    $finish;
end // test

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "aes_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule // aes_enc_tb
