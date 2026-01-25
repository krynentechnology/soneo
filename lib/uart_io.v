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
 *  Description: UART - IO, terminal (console) interaction, XON/XOFF enabled!
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module uart_io #(
/*============================================================================*/
    parameter PROMPT = "FDK>", // Fpga Development Kit prompt
    parameter [4:0] NR_BITS = 8,
    parameter [0:0] SKIP_SPACE = 0, // 1 = Do not add SPACE to RX fifo
    parameter RX_FIFO = 8 )
    (
    input  wire clk,
    input  wire rst_n, // High when clock stable!
    // UART IO RX
    output reg  [NR_BITS-1:0] uart_io_rx_d = 0,
    output reg  uart_io_rx_dv = 0,
    input  wire uart_io_rx_dr,
    output reg  parity_io_ok = 0,
    output wire rx_fifo_nz, // RX FIFO input non zero
    // UART IO TX
    input  wire [NR_BITS-1:0] uart_io_tx_d,
    input  wire uart_io_tx_dv,
    output wire uart_io_tx_dr,
    // UART RX
    input  wire [NR_BITS-1:0] uart_rx_d,
    input  wire uart_rx_dv,
    input  wire parity_ok,
    // UART TX
    output reg  [NR_BITS-1:0] uart_tx_d = 0,
    output reg  uart_tx_dv = 0,
    input  wire uart_tx_dr
    );

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( NR_BITS != 8 ) begin
        $display( "NR_BITS = 8 expected for console interaction!" );
        $finish;
    end
    if ( RX_FIFO < 2 ) begin
        $display( "RX_FIFO < 2!" );
        $finish;
    end
end // parameter_check

/*============================================================================*/
function integer clog2( input [31:0] value );
/*============================================================================*/
reg [31:0] depth;
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

/*============================================================================*/
function integer strlen( input [( 10 * 8 )-1:0] prompt );
/*============================================================================*/
begin
    strlen = 0;
    while (( prompt >> ( strlen * 8 )) != 0 ) begin
        strlen = strlen + 1;
    end
end
endfunction // strlen

localparam [7:0] BS = 8'h08;
localparam [7:0] CR = 8'h0D;
localparam [7:0] LF = 8'h0A;
localparam [7:0] XON = 8'h11;
localparam [7:0] XOFF = 8'h13;
localparam [7:0] SPACE = 8'h20;
localparam PROMPT_SIZE = strlen( PROMPT );
localparam TX_PROMPT_SIZE = strlen( PROMPT ) + 1; // +LF
localparam RXFW = clog2( RX_FIFO );
localparam TXCW = clog2(( RX_FIFO > TX_PROMPT_SIZE ) ? RX_FIFO : TX_PROMPT_SIZE );

reg [7:0] fifo [0:RX_FIFO-1];
reg [RXFW:0] rx_count = 0; // +1
reg rx_enable = 0;
reg [TXCW:0] tx_count = 0; // +1
reg tx_prompt = 0;
reg tx_bs = 0;
reg tx_space = 0;
reg tx_xon = 0;

assign rx_fifo_nz = |rx_count;
assign uart_io_tx_dr = uart_tx_dr & tx_xon & ~( tx_prompt | tx_space | tx_bs );

reg [7:0] prompt [0:TX_PROMPT_SIZE-1];

reg [TXCW:0] i;
/*============================================================================*/
initial begin : init_prompt
/*============================================================================*/
    prompt[0] = LF;
    for ( i = 1; i < TX_PROMPT_SIZE; i = i + 1 ) begin
        prompt[i] = ( PROMPT >> (( PROMPT_SIZE - i ) * 8 ));
    end
//  for ( i = 0; i < TX_PROMPT_SIZE; i = i + 1 ) begin
//      $display( "prompt[%0d] = %x, %d, %d ", i, prompt[i], PROMPT_SIZE, TX_PROMPT_SIZE );
//  end
end // init_prompt

/*============================================================================*/
always @(posedge clk) begin : uart_handler
/*============================================================================*/
    uart_io_rx_dv <= 0;
    uart_tx_dv <= 0;
    if ( uart_rx_dv ) begin
        uart_tx_d <= uart_rx_d; // Echo RX!
        if ( |uart_rx_d[7:5] ) begin // uart_rx_d >= 8'h20
            if ( !( SKIP_SPACE && ( SPACE[4:0] == uart_rx_d[4:0] ))) begin
                if ( rx_count < RX_FIFO ) begin
                    fifo[rx_count] <= uart_rx_d;
                    rx_count <= rx_count + 1;
                end
            end
            uart_tx_dv <= 1;
        end
        if ( BS == uart_rx_d ) begin
            if ( rx_fifo_nz ) begin
                rx_count <= rx_count - 1;
                uart_tx_dv <= 1;
                tx_space <= 1;
            end
        end
        if ( CR == uart_rx_d ) begin
            rx_enable <= 1;
            tx_prompt <= 1; // LF in included by prompt!
            tx_count <= 0;
            uart_tx_dv <= 1;
        end
        if ( XON == uart_rx_d ) begin
            tx_xon <= 1;
        end
        if ( XOFF == uart_rx_d ) begin
            tx_xon <= 0;
        end
        parity_io_ok <= rx_fifo_nz ? ( parity_io_ok & parity_ok ) : parity_ok;
    end else if ( uart_io_rx_dr ) begin
        if ( rx_fifo_nz ) begin
            if ( rx_enable ) begin
                uart_io_rx_d <= fifo[0];
                uart_io_rx_dv <= 1;
                for ( i = 0; i < ( RX_FIFO - 1 ); i = i + 1 ) begin
                    fifo[i] <= fifo[i+1];
                end
                rx_count <= rx_count - 1;
            end
        end else begin
            rx_enable <= 0; // RX FIFO empty
        end
    end
    if ( uart_tx_dr ) begin
        if ( tx_prompt ) begin
            uart_tx_d <= prompt[tx_count];
            uart_tx_dv <= 1;
            if (( TX_PROMPT_SIZE - 1 ) == tx_count ) begin
                tx_prompt <= 0; // Stop TX prompt
            end else begin
                tx_count <= tx_count + 1;
            end
        end
        if ( tx_space ) begin
            tx_space <= 0;
            tx_bs <= 1;
            uart_tx_d <= SPACE;
            uart_tx_dv <= 1;
        end
        if ( tx_bs ) begin
            tx_bs <= 0;
            uart_tx_d <= BS;
            uart_tx_dv <= 1;
        end
        if ( uart_io_tx_dr && uart_io_tx_dv ) begin
            uart_tx_d <= uart_io_tx_d;
            uart_tx_dv <= 1;
            if ( CR == uart_io_tx_d ) begin
                tx_prompt <= 1; // LF in included by prompt!
                tx_count <= 0;
            end
        end
    end
    if ( !rst_n ) begin
        rx_count <= 0;
        rx_enable <= 0;
        tx_count <= 0;
        tx_prompt <= 0;
        tx_bs <= 0;
        tx_space <= 0;
        tx_xon <= 1;
    end
end

endmodule // uart_io
