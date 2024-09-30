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
 *  Description: Signal compander to/from 16-bit two's complement value.
 *
 *  13-bits significant (including sign) 20-bits value companding to/from
 *  16-bits value. 13 bits ~ 78 dB psychoacoustic masking -> 20 bits ~ 120 dB
 *  dynamic range value to/from 20-bit.
 *
 *  Or 12-bits significant (including sign) 27-bits value companding to/from
 *  16-bits value. 12 bits ~ 72 dB psychoacoustic masking -> 27 bits ~ 163 dB
 *  dynamic range value to/from 27-bit.
 *
 *  https://en.wikipedia.org/wiki/Companding
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module compander #(
/*============================================================================*/
    parameter COMPANDING = "20BIT", // or "27BIT"
    parameter [0:0] ENCODER = 1, // 0 = Decoder
    parameter [0:0] BARREL_SHIFTER = 1 ) // Barrel shifter algorithm based
    (
    clk,
    s_cmpndr_d, s_cmpndr_dv,
    m_cmpndr_d, m_cmpndr_dv
    );

localparam INW = ENCODER ? (( COMPANDING == "20BIT" ) ? 20 : 27 ) : 16;
localparam OUTW = ENCODER ? 16 : (( COMPANDING == "20BIT" ) ? 20 : 27 );

input  wire clk;
input  wire [INW-1:0] s_cmpndr_d; // data in
input  wire s_cmpndr_dv; // data in valid
output reg  [OUTW-1:0] m_cmpndr_d; // data out
output reg  m_cmpndr_dv; // data out valid

localparam CHORDW = (( COMPANDING == "20BIT" ) ? 3 : 4 ); // Chord width
localparam CHORD_LSB = INW - (( COMPANDING == "20BIT" ) ? 4 : 5 );
localparam MAX_CHORD = ( 2 ** CHORDW ) - 1;
localparam SHW = ( COMPANDING == "20BIT" ) ? 12 : 11;

reg  [CHORDW-1:0] chord = 0;
wire [CHORDW-1:0] chord_neg;
reg  [CHORDW-1:0] n_shift = 0;
reg  [INW-1:0] s_cmpndr_d_i;
wire [INW-1:0] s_cmpndr_d_neg;
reg  signed [OUTW-1:0] m_cmpndr_d_i;

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( COMPANDING != "20BIT" &&
         COMPANDING != "27BIT" ) begin
        $display( "Select one of the compander implementations!" );
        $finish;
    end
end // parameter_check

assign chord_neg = ~chord;
assign s_cmpndr_d_neg = ~s_cmpndr_d;

/*============================================================================*/
always @(*) begin : endoder_decoder
/*============================================================================*/
    if ( BARREL_SHIFTER ) begin // Conditional synthesis!
        if ( ENCODER ) begin // Conditional synthesis!
            if ( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-2] ) begin
                chord = s_cmpndr_d[INW-1] ? ~MAX_CHORD : MAX_CHORD;
                n_shift = MAX_CHORD - 1;
            end
            if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-3] ) &&
                ( s_cmpndr_d[INW-1] == s_cmpndr_d[INW-2] )) begin
                chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 1 ) : ( MAX_CHORD - 1 );
                n_shift = MAX_CHORD - 2;
            end
            if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-4] ) &&
                ( {(2){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-3] )) begin
                chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 2 ) : ( MAX_CHORD - 2 );
                n_shift = MAX_CHORD - 3;
            end
            if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-5] ) &&
                ( {(3){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-4] )) begin
                chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 3 ) : ( MAX_CHORD - 3 );
                n_shift = MAX_CHORD - 4;
            end
            if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-6] ) &&
                ( {(4){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-5] )) begin
                chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 4 ) : ( MAX_CHORD - 4 );
                n_shift = MAX_CHORD - 5;
            end
            if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-7] ) &&
                ( {(5){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-6] )) begin
                chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 5 ) : ( MAX_CHORD - 5 );
                n_shift = MAX_CHORD - 6;
            end
            if ( COMPANDING == "20BIT" ) begin // Conditional synthesis!
                if ( {(6){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-7] ) begin
                    if ( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-8] ) begin
                        chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 6 ) : ( MAX_CHORD - 6 );
                    end else begin
                        chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 7 ) : ( MAX_CHORD - 7 );
                    end
                n_shift = 0;
            end
            end else begin // COMPANDING == "27BIT"
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-8] ) &&
                    ( {(6){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-7] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 6 ) : ( MAX_CHORD - 6 );
                    n_shift = MAX_CHORD - 7;
                end
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-9] ) &&
                    ( {(7){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-8] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 7 ) : ( MAX_CHORD - 7 );
                    n_shift = MAX_CHORD - 8;
                end
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-10] ) &&
                    ( {(8){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-9] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 8 ) : ( MAX_CHORD - 8 );
                    n_shift = MAX_CHORD - 9;
                end
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-11] ) &&
                    ( {(9){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-10] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 9 ) : ( MAX_CHORD - 9 );
                    n_shift = MAX_CHORD - 10;
                end
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-12] ) &&
                    ( {(10){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-11] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 10 ) : ( MAX_CHORD - 10 );
                    n_shift = MAX_CHORD - 11;
                end
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-13] ) &&
                    ( {(11){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-12] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 11 ) : ( MAX_CHORD - 11 );
                    n_shift = MAX_CHORD - 12;
                end
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-14] ) &&
                    ( {(12){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-13] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 12 ) : ( MAX_CHORD - 12 );
                    n_shift = MAX_CHORD - 13;
                end
                if (( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-15] ) &&
                    ( {(13){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-14] )) begin
                    chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 13 ) : ( MAX_CHORD - 13 );
                    n_shift = MAX_CHORD - 14;
                end
                if ( {(14){s_cmpndr_d[INW-1]}} == s_cmpndr_d[INW-2:INW-15] ) begin
                    if ( s_cmpndr_d[INW-1] == s_cmpndr_d_neg[INW-8] ) begin
                        chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 14 ) : ( MAX_CHORD - 14 );
                    end else begin
                        chord = s_cmpndr_d[INW-1] ? ~( MAX_CHORD - 15 ) : ( MAX_CHORD - 15 );
                    end
                    n_shift = 0;
                end
            end
        end else begin // Decoder
            chord = s_cmpndr_d[INW-2:CHORD_LSB];
            if ( s_cmpndr_d[INW-1] ) begin
                if ( MAX_CHORD == chord ) begin
                    n_shift = MAX_CHORD - 1;
                end else begin
                    n_shift = chord;
                end
            end else begin
                if ( MAX_CHORD == chord_neg ) begin
                    n_shift = MAX_CHORD - 1;
                end else begin
                    n_shift = chord_neg;
                end
            end
        end
    end else begin // BARREL_SHIFTER = 0
        if ( ENCODER ) begin // Conditional synthesis!
            if ( COMPANDING == "20BIT" ) begin // Conditional synthesis!
                if ( 2'b01 == s_cmpndr_d[19:18] ) begin
                    m_cmpndr_d = {4'b0111, s_cmpndr_d[17:6]};
                end
                if ( 2'b10 == s_cmpndr_d[19:18] ) begin
                    m_cmpndr_d = {4'b1000, s_cmpndr_d[17:6]};
                end
                if ( 3'b001 == s_cmpndr_d[19:17] ) begin
                    m_cmpndr_d = {4'b0110, s_cmpndr_d[16:5]};
                end
                if ( 3'b110 == s_cmpndr_d[19:17] ) begin
                    m_cmpndr_d = {4'b1001, s_cmpndr_d[16:5]};
                end
                if ( 4'b0001 == s_cmpndr_d[19:16] ) begin
                    m_cmpndr_d = {4'b0101, s_cmpndr_d[15:4]};
                end
                if ( 4'b1110 == s_cmpndr_d[19:16] ) begin
                    m_cmpndr_d = {4'b1010, s_cmpndr_d[15:4]};
                end
                if ( 5'b00001 == s_cmpndr_d[19:15] ) begin
                    m_cmpndr_d = {4'b0100, s_cmpndr_d[14:3]};
                end
                if ( 5'b11110 == s_cmpndr_d[19:15] ) begin
                    m_cmpndr_d = {4'b1011, s_cmpndr_d[14:3]};
                end
                if ( 6'b000001 == s_cmpndr_d[19:14] ) begin
                    m_cmpndr_d = {4'b0011, s_cmpndr_d[13:2]};
                end
                if ( 6'b111110 == s_cmpndr_d[19:14] ) begin
                    m_cmpndr_d = {4'b1100, s_cmpndr_d[13:2]};
                end
                if ( 7'b0000001 == s_cmpndr_d[19:13] ) begin
                    m_cmpndr_d = {4'b0010, s_cmpndr_d[12:1]};
                end
                if ( 7'b1111110 == s_cmpndr_d[19:13] ) begin
                    m_cmpndr_d = {4'b1101, s_cmpndr_d[12:1]};
                end
                if ( 7'b0000000 == s_cmpndr_d[19:13] ) begin
                    m_cmpndr_d = {3'b000, s_cmpndr_d[12:0]};
                end
                if ( 7'b1111111 == s_cmpndr_d[19:13] ) begin
                    m_cmpndr_d = {3'b111, s_cmpndr_d[12:0]};
                end
            end else begin // COMPANDING == "27BIT" - conditional synthesis!
                if ( 2'b01 == s_cmpndr_d[26:25] ) begin
                    m_cmpndr_d = {5'b01111, s_cmpndr_d[24:14]};
                end
                if ( 2'b10 == s_cmpndr_d[26:25] ) begin
                    m_cmpndr_d = {5'b10000, s_cmpndr_d[24:14]};
                end
                if ( 3'b001 == s_cmpndr_d[26:24] ) begin
                    m_cmpndr_d = {5'b01110, s_cmpndr_d[23:13]};
                end
                if ( 3'b110 == s_cmpndr_d[26:24] ) begin
                    m_cmpndr_d = {5'b10001, s_cmpndr_d[23:13]};
                end
                if ( 4'b0001 == s_cmpndr_d[26:23] ) begin
                    m_cmpndr_d = {5'b01101, s_cmpndr_d[22:12]};
                end
                if ( 4'b1110 == s_cmpndr_d[26:23] ) begin
                    m_cmpndr_d = {5'b10010, s_cmpndr_d[22:12]};
                end
                if ( 5'b00001 == s_cmpndr_d[26:22] ) begin
                    m_cmpndr_d = {5'b01100, s_cmpndr_d[21:11]};
                end
                if ( 5'b11110 == s_cmpndr_d[26:22] ) begin
                    m_cmpndr_d = {5'b10011, s_cmpndr_d[21:11]};
                end
                if ( 6'b000001 == s_cmpndr_d[26:21] ) begin
                    m_cmpndr_d = {5'b01011, s_cmpndr_d[20:10]};
                end
                if ( 6'b111110 == s_cmpndr_d[26:21] ) begin
                    m_cmpndr_d = {5'b10100, s_cmpndr_d[20:10]};
                end
                if ( 7'b0000001 == s_cmpndr_d[26:20] ) begin
                    m_cmpndr_d = {5'b01010, s_cmpndr_d[19:9]};
                end
                if ( 7'b1111110 == s_cmpndr_d[26:20] ) begin
                    m_cmpndr_d = {5'b10101, s_cmpndr_d[19:9]};
                end
                if ( 8'b00000001 == s_cmpndr_d[26:19] ) begin
                    m_cmpndr_d = {5'b01001, s_cmpndr_d[18:8]};
                end
                if ( 8'b11111110 == s_cmpndr_d[26:19] ) begin
                    m_cmpndr_d = {5'b10110, s_cmpndr_d[18:8]};
                end
                if ( 9'b000000001 == s_cmpndr_d[26:18] ) begin
                    m_cmpndr_d = {5'b01000, s_cmpndr_d[17:7]};
                end
                if ( 9'b111111110 == s_cmpndr_d[26:18] ) begin
                    m_cmpndr_d = {5'b10111, s_cmpndr_d[17:7]};
                end
                if ( 10'b0000000001 == s_cmpndr_d[26:17] ) begin
                    m_cmpndr_d = {5'b00111, s_cmpndr_d[16:6]};
                end
                if ( 10'b1111111110 == s_cmpndr_d[26:17] ) begin
                    m_cmpndr_d = {5'b11000, s_cmpndr_d[16:6]};
                end
                if ( 11'b00000000001 == s_cmpndr_d[26:16] ) begin
                    m_cmpndr_d = {5'b00110, s_cmpndr_d[15:5]};
                end
                if ( 11'b11111111110 == s_cmpndr_d[26:16] ) begin
                    m_cmpndr_d = {5'b11001, s_cmpndr_d[15:5]};
                end
                if ( 12'b000000000001 == s_cmpndr_d[26:15] ) begin
                    m_cmpndr_d = {5'b00101, s_cmpndr_d[14:4]};
                end
                if ( 12'b111111111110 == s_cmpndr_d[26:15] ) begin
                    m_cmpndr_d = {5'b11010, s_cmpndr_d[14:4]};
                end
                if ( 13'b0000000000001 == s_cmpndr_d[26:14] ) begin
                    m_cmpndr_d = {5'b00100, s_cmpndr_d[13:3]};
                end
                if ( 13'b1111111111110 == s_cmpndr_d[26:14] ) begin
                    m_cmpndr_d = {5'b11011, s_cmpndr_d[13:3]};
                end
                if ( 14'b00000000000001 == s_cmpndr_d[26:13] ) begin
                    m_cmpndr_d = {5'b00011, s_cmpndr_d[12:2]};
                end
                if ( 14'b11111111111110 == s_cmpndr_d[26:13] ) begin
                    m_cmpndr_d = {5'b11100, s_cmpndr_d[12:2]};
                end
                if ( 15'b000000000000001 == s_cmpndr_d[26:12] ) begin
                    m_cmpndr_d = {5'b00010, s_cmpndr_d[11:1]};
                end
                if ( 15'b111111111111110 == s_cmpndr_d[26:12] ) begin
                    m_cmpndr_d = {5'b11101, s_cmpndr_d[11:1]};
                end
                if ( 15'b000000000000000 == s_cmpndr_d[26:12] ) begin
                    m_cmpndr_d = {4'b0000, s_cmpndr_d[11:0]};
                end
                if ( 15'b111111111111111 == s_cmpndr_d[26:12] ) begin
                    m_cmpndr_d = {4'b1111, s_cmpndr_d[11:0]};
                end
            end
        end else begin // Decoder
            if ( COMPANDING == "20BIT" ) begin // Conditional synthesis!
                if ( 4'b0111 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {2'b01, s_cmpndr_d[11:0], 6'h0};
                end
                if ( 4'b1000 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {2'b10, s_cmpndr_d[11:0], 6'h3F};
                end
                if ( 4'b0110 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {3'b001, s_cmpndr_d[11:0], 5'h0};
                end
                if ( 4'b1001 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {3'b110, s_cmpndr_d[11:0], 5'h1F};
                end
                if ( 4'b0101 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {4'b0001, s_cmpndr_d[11:0], 4'h0};
                end
                if ( 4'b1010 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {4'b1110, s_cmpndr_d[11:0], 4'hF};
                end
                if ( 4'b0100 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {5'b00001, s_cmpndr_d[11:0], 3'h0};
                end
                if ( 4'b1011 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {5'b11110, s_cmpndr_d[11:0], 3'h7};
                end
                if ( 4'b0011 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {6'b000001, s_cmpndr_d[11:0], 2'h0};
                end
                if ( 4'b1100 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {6'b111110, s_cmpndr_d[11:0], 2'h3};
                end
                if ( 4'b0010 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {7'b0000001, s_cmpndr_d[11:0], 1'b0};
                end
                if ( 4'b1101 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {7'b1111110, s_cmpndr_d[11:0], 1'b1};
                end
                if ( 3'b000 == s_cmpndr_d[15:13] ) begin
                    m_cmpndr_d = {7'b0000000, s_cmpndr_d[12:0]};
                end
                if ( 3'b111 == s_cmpndr_d[15:13] ) begin
                    m_cmpndr_d = {7'b1111111, s_cmpndr_d[12:0]};
                end
            end else begin // COMPANDING == "27BIT" - conditional synthesis!
                if ( 5'b01111 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {2'b01, s_cmpndr_d[10:0], 14'h0};
                end
                if ( 5'b10000 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {2'b10, s_cmpndr_d[10:0], 14'h3FFF};
                end
                if ( 5'b01110 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {3'b001, s_cmpndr_d[10:0], 13'h0};
                end
                if ( 5'b10001 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {3'b110, s_cmpndr_d[10:0], 13'h1FFF};
                end
                if ( 5'b01101 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {4'b0001, s_cmpndr_d[10:0], 12'h0};
                end
                if ( 5'b10010 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {4'b1110, s_cmpndr_d[10:0], 12'hFFF};
                end
                if ( 5'b01100 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {5'b00001, s_cmpndr_d[10:0], 11'h0};
                end
                if ( 5'b10011 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {5'b11110, s_cmpndr_d[10:0], 11'h7FF};
                end
                if ( 5'b01011 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {6'b000001, s_cmpndr_d[10:0], 10'h0};
                end
                if ( 5'b10100 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {6'b111110, s_cmpndr_d[10:0], 10'h3FF};
                end
                if ( 5'b01010 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {7'b0000001, s_cmpndr_d[10:0], 9'h0};
                end
                if ( 5'b10101 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {7'b1111110, s_cmpndr_d[10:0], 9'h1FF};
                end
                if ( 5'b01001 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {8'b00000001, s_cmpndr_d[10:0], 8'h0};
                end
                if ( 5'b10110 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {8'b11111110, s_cmpndr_d[10:0], 8'hFF};
                end
                if ( 5'b01000 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {9'b000000001, s_cmpndr_d[10:0], 7'h0};
                end
                if ( 5'b10111 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {9'b111111110, s_cmpndr_d[10:0], 7'h7F};
                end
                if ( 5'b00111 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {10'b0000000001, s_cmpndr_d[10:0], 6'h0};
                end
                if ( 5'b11000 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {10'b1111111110, s_cmpndr_d[10:0], 6'h3F};
                end
                if ( 5'b00110 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {11'b00000000001, s_cmpndr_d[10:0], 5'h0};
                end
                if ( 5'b11001 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {11'b11111111110, s_cmpndr_d[10:0], 5'h1F};
                end
                if ( 5'b00101 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {12'b000000000001, s_cmpndr_d[10:0], 4'h0};
                end
                if ( 5'b11010 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {12'b111111111110, s_cmpndr_d[10:0], 4'hF};
                end
                if ( 5'b00100 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {13'b0000000000001, s_cmpndr_d[10:0], 3'h0};
                end
                if ( 5'b11011 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {13'b1111111111110, s_cmpndr_d[10:0], 3'h7};
                end
                if ( 5'b00011 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {14'b00000000000001, s_cmpndr_d[10:0], 2'h0};
                end
                if ( 5'b11100 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {14'b11111111111110, s_cmpndr_d[10:0], 2'h3};
                end
                if ( 5'b00010 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {15'b000000000000001, s_cmpndr_d[10:0], 1'b0};
                end
                if ( 5'b11101 == s_cmpndr_d[15:11] ) begin
                    m_cmpndr_d = {15'b111111111111110, s_cmpndr_d[10:0], 1'b1};
                end
                if ( 4'b0000 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {15'b000000000000000, s_cmpndr_d[11:0]};
                end
                if ( 4'b1111 == s_cmpndr_d[15:12] ) begin
                    m_cmpndr_d = {15'b111111111111111, s_cmpndr_d[11:0]};
                end
            end
        end
    end
end // endoder_decoder

/*============================================================================*/
always @(posedge clk) begin : barrel_shift
/*============================================================================*/
    m_cmpndr_dv <= s_cmpndr_dv;
    if ( BARREL_SHIFTER ) begin // Conditional synthesis!
        if ( ENCODER ) begin // Conditional synthesis!
            m_cmpndr_d[OUTW-1] <= s_cmpndr_d[INW-1]; // Copy sign
            m_cmpndr_d[OUTW-2:( OUTW - CHORDW )-1] <= chord;
            s_cmpndr_d_i = s_cmpndr_d >> n_shift;
            m_cmpndr_d[( OUTW - CHORDW )-2:0] <= s_cmpndr_d_i[SHW-1:0];
        end else begin // Decoder
            m_cmpndr_d_i[OUTW-1] = s_cmpndr_d[INW-1]; // Copy sign
            m_cmpndr_d_i[OUTW-2] = s_cmpndr_d_neg[INW-1]; // Copy inverted sign
            m_cmpndr_d_i[OUTW-3:( OUTW - SHW )-2] = s_cmpndr_d[CHORD_LSB-1:0];
            m_cmpndr_d_i[( OUTW - SHW )-3:0] = {( OUTW - SHW - 2 ){s_cmpndr_d[INW-1]}};
            m_cmpndr_d <= m_cmpndr_d_i >>> n_shift;
            if ( s_cmpndr_d[INW-1] ) begin
                if ( MAX_CHORD == chord ) begin
                    m_cmpndr_d[SHW] <= s_cmpndr_d[INW-1];
                end
            end else begin
                if ( MAX_CHORD == chord_neg ) begin
                    m_cmpndr_d[SHW] <= s_cmpndr_d[INW-1];
                end
            end
        end
    end
end // barrel_shift

endmodule // compander
