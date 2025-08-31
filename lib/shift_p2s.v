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
 *  Description: Parallel in to serial 74HC(T)597 interface.
 *
 *                                   /--->------------------->---\
 *         ---------        + N x    |      ---------            |
 *      D1-|1    16|-VCC             |   D1-|1    16|-VCC        |
 *      D2-|2    15|-D0              |   D2-|2    15|-D0         |
 *      D3-|3    14|-SDATA           |   D3-|3    14|-SDATA -<---/
 *      D4-|4    13|-PLOAD_N         |   D4-|4    13|-PLOAD_N
 *      D5-|5    12|-SCLK            |   D5-|5    12|-SCLK    Cascaded Q
 *      D6-|6    11|-CLK             |   D6-|6    11|-CLK
 *      D7-|7    10|-RST_N           |   D7-|7    10|-RST_N
 *     GND-|8     9|-Q --->----------/  GND-|8    09|-Q --->---...
 *         ---------                        ---------
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module shift_p2s #(
/*============================================================================*/
    parameter SHIFT_P2S_WIDTH = 16,
    parameter SHIFT_P2S_INIT = 16'd0
    )
    (
    input  wire clk2x, // 2 x shift_p2s_clk
    input  wire rst_n, // Synchronous reset, high when shift_clk2x is stable!
    output reg  [SHIFT_P2S_WIDTH-1:0] shift_p2s_pdata = SHIFT_P2S_INIT, // Data serialized.
    // Interface 74HC(T)597
    output reg  shift_p2s_pload_n = 1, // Parallel load, active low.
    output reg  shift_p2s_clk = 0, // Shift register clock (CLK).
    output reg  shift_p2s_sclk = 0, // Storage register clock (SCLK).
    output wire shift_p2s_rst_n, // Reset, active low.
    input  wire shift_p2s_q // Serial data in (Q).
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
    if ( SHIFT_P2S_WIDTH % 8 ) begin // Multiple of 8 bits.
        $display( "SHIFT_P2S_WIDTH modula 8!" );
        $finish;
    end
end // param_check

localparam CW = clog2( SHIFT_P2S_WIDTH ); // Counter width.

reg [CW-1:0] bit_count = 0;
reg [SHIFT_P2S_WIDTH-1:0] shift_p2s_pdata_i = 0;

assign shift_p2s_rst_n = rst_n;

/*============================================================================*/
always @(negedge clk2x ) begin : shift_p2s_process
/*============================================================================*/
    shift_p2s_clk <= ~shift_p2s_clk;
    shift_p2s_pload_n <= 1;
    shift_p2s_sclk <= 0;
    if ( shift_p2s_clk ) begin
        shift_p2s_pload_n <= 0;
        shift_p2s_sclk <= 1;
    end else if ( 0 == bit_count ) begin // D0-D7 inputs to shift register.
        if (( SHIFT_P2S_WIDTH - 1 ) == bit_count ) begin
            bit_count <= 0;
            shift_p2s_pdata <= shift_p2s_pdata_i; // Output before shift operation.
        end else begin
            bit_count <= bit_count + 1;
        end
        shift_p2s_pdata_i <= {shift_p2s_pdata_i[SHIFT_P2S_WIDTH-2:0], shift_p2s_q};
    end
    if ( !rst_n ) begin
        shift_p2s_pdata <= SHIFT_P2S_INIT;
        shift_p2s_pload_n <= 1;
        shift_p2s_clk <= 0;
        shift_p2s_sclk <= 0;
        shift_p2s_pdata_i <= 0;
        bit_count <= 0;
    end
end // shift_p2s_process

endmodule // shift_p2s
