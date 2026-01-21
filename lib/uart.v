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
 *  Description: UART - Universal Asynchronous Receiver Transmitter
 *
 *  https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module uart #(
/*============================================================================*/
    parameter real CLK_FREQ = 100E6,
    parameter real BAUD_RATE = 115.2E3,
    parameter [4:0] NR_BITS = 8,
    parameter PARITY = "NONE", // Or "EVEN", "ODD"
    parameter [1:0] STOP_BITS = 1 )
    (
    input  wire clk,
    input  wire rst_n, // High when clock stable!
    // RX
    output reg [NR_BITS-1:0] uart_rx_d = 0,
    output reg uart_rx_dv = 0,
    output reg parity_ok = 0,
    // TX
    input  wire [NR_BITS-1:0] uart_tx_d,
    input  wire uart_tx_dv,
    output wire uart_tx_dr,
    // UART full duplex lines
    input  wire uart_rx,
    output reg  uart_tx = 1
    );

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( BAUD_RATE < 50.0 || CLK_FREQ < 200.0 ||
        ( CLK_FREQ / BAUD_RATE ) < 4.0 ) begin
        $display( "BAUD_RATE < 50.0 || CLK_FREQ < 200.0 || ( CLK_FREQ / BAUD_RATE ) < 4.0!" );
        $finish;
    end
    if ( NR_BITS < 2 || NR_BITS > 16 ) begin
        $display( "NR_BITS < 2 || NR_BITS > 16!" );
        $finish;
    end
    if (( "NONE" != PARITY ) && ( "EVEN" != PARITY ) && ( "ODD" != PARITY )) begin
        $display( "PARITY not defined!" );
        $finish;
    end
    if ( STOP_BITS < 1 || STOP_BITS > 2 ) begin
        $display( "STOP_BITS < 1 || STOP_BITS > 2!" );
        $finish;
    end
end // parameter_check

localparam MAX_CLOG2_WIDTH = 32;
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

localparam [0:0] START_BITS = 1;
localparam [0:0] PARITY_BITS = ( "NONE" == PARITY ) ? 0 : 1;
localparam [4:0] START_STOP_WIDTH = START_BITS + NR_BITS + PARITY_BITS + STOP_BITS;
localparam [3:0] STSTW = clog2( START_STOP_WIDTH );
localparam integer CLK_DIV_BAUD = ( CLK_FREQ / BAUD_RATE );
localparam CLK_COUNT_WIDTH = clog2( CLK_DIV_BAUD );
localparam CLKW = CLK_COUNT_WIDTH;
localparam [CLKW-1:0] RX_SAMPLE = ( CLK_DIV_BAUD / 2.0 ) - 1;

reg [1:0] uart_rx_i = ~0; // All 1's
reg [CLKW-1:0] rx_clk_count = 0;
reg [STSTW-1:0] rx_bit_count = 0;
reg [NR_BITS-1:0] uart_rx_d_i = 0;

reg [CLKW-1:0] tx_clk_count = 0;
reg [STSTW-1:0] tx_bit_count = 0;
reg [NR_BITS-1:0] uart_tx_d_i = 0;
reg uart_tx_dr_i = 1;
reg tx_d_parity = 0;

/*============================================================================*/
always @(posedge clk) begin : process_rx
/*============================================================================*/
    uart_rx_i <= {uart_rx_i[0], uart_rx};
    rx_clk_count <= rx_clk_count + 1;
    uart_rx_dv <= 0;
    if ( CLK_DIV_BAUD == rx_clk_count ) begin
        rx_clk_count <= 0;
    end
    if (( 0 == rx_bit_count ) && ( 2'b10 == uart_rx_i )) begin
        rx_clk_count <= 0;
    end else if ( RX_SAMPLE == rx_clk_count ) begin
        if (( 0 == rx_bit_count ) && ( 0 == uart_rx )) begin
            rx_bit_count <= 1; // Start bit
        end
        if ( rx_bit_count > 0 ) begin
            rx_bit_count <= rx_bit_count + 1;
            if ( rx_bit_count <= NR_BITS ) begin
                uart_rx_d_i <= {uart_rx, uart_rx_d_i[NR_BITS-1:1]};
            end
            if (( NR_BITS + 1 ) == rx_bit_count ) begin
                uart_rx_d <= uart_rx_d_i;
                uart_rx_dv <= 1;
                if ( "EVEN" == PARITY ) begin // Conditional synthesis!
                    parity_ok <= ( ^uart_rx_d_i == uart_rx );
                end else if ( "ODD" == PARITY ) begin // Conditional synthesis!
                    parity_ok <= ( ^uart_rx_d_i != uart_rx );
                end
                rx_bit_count <= 0;
            end
        end
    end
    if ( !rst_n ) begin
        uart_rx_i <= ~0;
        uart_rx_d_i <= 0;
        uart_rx_dv <= 0;
        rx_clk_count <= 0;
    end
end

assign uart_tx_dr = uart_tx_dr_i & ~uart_tx_dv;

/*============================================================================*/
always @(posedge clk) begin : process_tx
/*============================================================================*/
    tx_clk_count <= tx_clk_count + 1;
    if ( CLK_DIV_BAUD == tx_clk_count ) begin
        tx_clk_count <= 0;
        if ( START_STOP_WIDTH == tx_bit_count ) begin
            tx_bit_count <= 0;
            uart_tx_dr_i <= 1;
        end
    end
    if ( uart_tx_dv && uart_tx_dr_i ) begin
        uart_tx_dr_i <= 0;
        uart_tx_d_i <= uart_tx_d;
        if ( "EVEN" == PARITY ) begin // Conditional synthesis!
            tx_d_parity <= ^uart_tx_d;
        end else if ( "ODD" == PARITY ) begin // Conditional synthesis!
            tx_d_parity <= ~( ^uart_tx_d );
        end
        tx_clk_count <= 0;
        tx_bit_count <= 0;
        uart_tx <= 1;
    end
    if ( !uart_tx_dr_i ) begin
        if ( 0 == tx_clk_count ) begin
            tx_bit_count <= tx_bit_count + 1;
            uart_tx <= 1;
            if ( 0 == tx_bit_count ) begin
                uart_tx <= 0; // Start bit
            end else if ( tx_bit_count <= NR_BITS ) begin
                uart_tx <= uart_tx_d_i[0];
                uart_tx_d_i <= uart_tx_d_i >> 1;
            end
            if (( NR_BITS + 1 ) == tx_bit_count ) begin
                if ( "NONE" != PARITY ) begin // Conditional synthesis!
                    uart_tx <= tx_d_parity;
                end
            end
        end
    end
    if ( !rst_n ) begin
        uart_tx <= 1;
        uart_tx_d_i <= 0;
        uart_tx_dr_i <= 1;
    end
end

endmodule // uart
