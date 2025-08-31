/**
 *  Copyright (C) 2025, Kees Krijnen.
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
 *  Description: Serial shift in to parallel 74HC(T)595 interface.
 *
 *                                   /--->------------------->---\
 *         ---------        + N x    |      ---------            |
 *      Q1-|1    16|-VCC             |   Q1-|1    16|-VCC        |
 *      Q2-|2    15|-Q0              |   Q2-|2    15|-Q0         |
 *      Q3-|3    14|-SDATA           |   Q3-|3    14|-SDATA -<---/
 *      Q4-|4    13|-OE_N            |   Q4-|4    13|-OE_N
 *      Q5-|5    12|-SCLK            |   Q5-|5    12|-SCLK    Cascaded SDATA
 *      Q6-|6    11|-CLK             |   Q6-|6    11|-CLK
 *      Q7-|7    10|-RST_N           |   Q7-|7    10|-RST_N
 *     GND-|8     9|-Q7S --->--------/  GND-|8    09|-Q7S --->---...
 *         ---------                        ---------
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module shift_s2p #(
/*============================================================================*/
    parameter SHIFT_S2P_WIDTH = 16,
    parameter SHIFT_S2P_INIT = 16'd0
    )
    (
    input  wire clk2x, // 2 x shift_s2p_clk
    input  wire rst_n, // Synchronous reset, high when shift_clk2x is stable!
    input  wire [SHIFT_S2P_WIDTH-1:0] shift_s2p_pdata, // Data to serialize.
    // Interface 74HC(T)595
    output wire shift_s2p_sdata, // Serial data out (SDATA).
    output reg  shift_s2p_oe_n = 1, // Output enable, active low.
    output reg  shift_s2p_clk = 0, // Shift register clock (CLK).
    output reg  shift_s2p_sclk = 0, // Storage register clock (SCLK).
    output wire shift_s2p_rst_n // Reset, active low.
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

// Parameter checks
/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( SHIFT_S2P_WIDTH % 8 ) begin // Multiple of 8 bits.
        $display( "SHIFT_S2P_WIDTH modula 8!" );
        $finish;
    end
end // param_check

localparam CW = clog2( SHIFT_S2P_WIDTH ); // Counter width.

reg [SHIFT_S2P_WIDTH-1:0] shift_s2p_pdata_i = SHIFT_S2P_INIT;
reg [CW-1:0] bit_count = 0;

assign shift_s2p_rst_n = rst_n;
assign shift_s2p_sdata = shift_s2p_pdata_i[SHIFT_S2P_WIDTH-1];

/*============================================================================*/
always @(posedge clk2x ) begin : shift_s2p_process
/*============================================================================*/
    shift_s2p_clk <= ~shift_s2p_clk;
    shift_s2p_sclk <= 0;
    if ( shift_s2p_clk ) begin
        if (( SHIFT_S2P_WIDTH - 1 ) == bit_count ) begin
            bit_count <= 0;
            shift_s2p_oe_n <= 0; // Output enable.
            shift_s2p_sclk <= 1; // Output storage register.
            shift_s2p_pdata_i <= shift_s2p_pdata; // Store before shift operation.
        end else begin
            bit_count <= bit_count + 1;
            shift_s2p_pdata_i <= {shift_s2p_pdata_i[SHIFT_S2P_WIDTH-2:0], 1'b0};
        end
    end
    if ( !rst_n ) begin
        shift_s2p_oe_n <= 1;
        shift_s2p_clk <= 0;
        shift_s2p_pdata_i <= SHIFT_S2P_INIT;
        bit_count <= 0;
    end
end // shift_s2p_process

endmodule // shift_s2p
