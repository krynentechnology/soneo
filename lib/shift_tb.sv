/**
 *  Copyright (C) 2025, Kees Krijnen.
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
 *  Description: Parallel to serial to parallel test bench.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

// Dependencies:
// `include "shift_p2s.v"
// `include "shift_s2p.v"

/*============================================================================*/
module shift_tb;
/*============================================================================*/

localparam SHIFT_WIDTH = 16;
localparam SHIFT_INIT = 16'h8241;

reg clk = 0;
reg rst_n = 0;

reg  [SHIFT_WIDTH-1:0] shift_s2p_pdata = 0;
wire shift_s2p_sdata;
wire shift_s2p_oe_n;
wire shift_s2p_clk;
wire shift_s2p_sclk;
wire shift_s2p_rst_n;

shift_s2p #(
    .SHIFT_S2P_WIDTH( SHIFT_WIDTH ),
    .SHIFT_S2P_INIT( SHIFT_INIT )
    )
shift_s2p1 (
    .clk2x(clk),
    .rst_n(rst_n),
    .shift_s2p_pdata(shift_s2p_pdata),
    .shift_s2p_sdata(shift_s2p_sdata),
    .shift_s2p_oe_n(shift_s2p_oe_n),
    .shift_s2p_clk(shift_s2p_clk),
    .shift_s2p_sclk(shift_s2p_sclk),
    .shift_s2p_rst_n(shift_s2p_rst_n)
    );

wire [SHIFT_WIDTH-1:0] shift_p2s_pdata;
wire shift_p2s_pload_n;
wire shift_p2s_clk;
wire shift_p2s_sclk;
wire shift_p2s_rst_n;
wire shift_p2s_q;

shift_p2s #(
    .SHIFT_P2S_WIDTH( SHIFT_WIDTH ),
    .SHIFT_P2S_INIT( SHIFT_INIT )
    )
shift_p2s1 (
    .clk2x(clk),
    .rst_n(rst_n),
    .shift_p2s_pdata(shift_p2s_pdata),
    .shift_p2s_pload_n(shift_p2s_pload_n),
    .shift_p2s_clk(shift_p2s_clk),
    .shift_p2s_sclk(shift_p2s_sclk),
    .shift_p2s_rst_n(shift_p2s_rst_n),
    .shift_p2s_q(shift_p2s_q)
    );

wire [7:0] q1;
wire q7s1;

SN74HC595 s2p1(
    .SDATA(shift_s2p_sdata),
    .OE_N(shift_s2p_oe_n),
    .SHCP(shift_s2p_clk),
    .STCP(shift_s2p_sclk),
    .Q(q1),
    .Q7S(q7s1)
    );

wire [7:0] q2;

SN74HC595 s2p2(
    .SDATA(q7s1),
    .OE_N(shift_s2p_oe_n),
    .SHCP(shift_s2p_clk),
    .STCP(shift_s2p_sclk),
    .Q(q2),
    .Q7S()
    );

wire sdata;

SN74HC597 p2s1(
    .SDATA(1'b0),
    .PL_N(shift_p2s_pload_n),
    .SHCP(shift_p2s_clk),
    .STCP(shift_p2s_sclk),
    .D(q1),
    .Q(sdata)
    );

SN74HC597 p2s2(
    .SDATA(sdata),
    .PL_N(shift_p2s_pload_n),
    .SHCP(shift_p2s_clk),
    .STCP(shift_p2s_sclk),
    .D(q2),
    .Q(shift_p2s_q)
    );

always #5 clk = ~clk; // 100 MHz clock

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    #100 // 0.1us
    rst_n  = 1;
    $display( "Shift IO simulation started" );
    shift_s2p_pdata = SHIFT_INIT;
    #10000 // 10us
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "shift_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule // shift_tb

module SN74HC595 (
    input  wire SDATA,
    input  wire OE_N,
    input  wire SHCP,
    input  wire STCP,
    output wire [7:0] Q,
    output wire Q7S
    );

wire shcp_i;
wire stcp_i;
reg  [7:0] Q_i = 0;
reg  [7:0] Q_ii = 0;

assign #1 shcp_i = SHCP;
assign #1 stcp_i = STCP;
assign Q = OE_N ? 8'bZ : Q_i;
assign #1 Q7S = Q_ii[7];

/*============================================================================*/
always @(*) begin : SN74HC595_process
/*============================================================================*/
    Q_i = Q_i; // Latch.
    Q_ii = Q_ii;
    if ( SHCP && STCP ) begin
        $display( "SHCP && STCP" );
        $finish;
    end
    if ( SHCP && !shcp_i && !STCP ) begin // Rising edge SHCP!
        Q_ii = {Q_ii[6:0], SDATA};
    end
    if ( STCP && !stcp_i && !SHCP ) begin // Rising edge STCP!
        Q_i = Q_ii;
    end
end // SN74HC595_process

endmodule // SN74HC595

module SN74HC597 (
    input  wire SDATA,
    input  wire PL_N,
    input  wire SHCP,
    input  wire STCP,
    input  wire [7:0] D,
    output wire Q
    );

wire shcp_i;
wire stcp_i;
reg [7:0] D_i = 0;

assign #1 shcp_i = SHCP;
assign #1 stcp_i = STCP;
assign #1 Q = D_i[7];

/*============================================================================*/
always @(*) begin : SN74HC597_process
/*============================================================================*/
    D_i = D_i; // Latch.
    if ( SHCP && !shcp_i ) begin
        D_i = {D_i[6:0], SDATA};
    end
    if ( STCP && !stcp_i && !PL_N ) begin
        D_i = D;
    end
end // SN74HC597_process

endmodule // SN74HC597
