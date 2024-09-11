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
 *  Description: SPI slave
 *
 *  Specification: https://en.wikipedia.org/wiki/Serial_Peripheral_Interface
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module spi_slave #(
/*============================================================================*/
    parameter [0:0] CPOL = 1, // CPOL = 0, first clock edge = 0/1, second edge = 1/0 transition
                              // CPOL = 1, first clock edge = 1/0, second edge = 0/1 transition
    parameter [0:0] CPHA = 1, // CPHA = 0, data valid during first clock edge
                              // CPHA = 1, data valid during second clock edge
    parameter SPI_DATA_WIDTH = 8 ) // SPI word size
    (
        input  wire clk,
        input  wire spi_sclk, // SPI serial clock
        input  wire spi_mosi, // SPI master out, slave in
        output wire spi_miso, // SPI master in, slave out
        input  wire spi_cs_n, // SPI chip select, active low
        input  wire [SPI_DATA_WIDTH-1:0] s_spi_d, // Data from slave
        input  wire s_spi_dv, // Data valid
        output wire [SPI_DATA_WIDTH-1:0] m_spi_d, // Data from master
        output wire m_spi_dv, // Data valid
        output wire spi_active
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

localparam BIT_COUNTER_WIDTH = clog2( SPI_DATA_WIDTH );

reg sck_i = CPOL;
reg sck_ii = CPOL;
reg cs_n_i = 1;
reg mosi_i = 0;
reg miso_i = 0;
reg [SPI_DATA_WIDTH-1:0] m_spi_d_i = 0;
reg last_shift = 0;
reg [BIT_COUNTER_WIDTH-1:0] bit_counter = 0;
reg [SPI_DATA_WIDTH-1:0] shift_reg = 0;
wire last_bit_count;
wire zero_bit_count;

assign last_bit_count = ( SPI_DATA_WIDTH - 1 ) == bit_counter;
assign zero_bit_count = 0 == bit_counter;


/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( SPI_DATA_WIDTH < 2 ) begin
        $display( "SPI_DATA_WIDTH < 2!");
        $finish;
    end
end // parameter_check

/*============================================================================*/
always @(posedge clk) begin : synchronize
/*============================================================================*/
    sck_i <= spi_sclk;
    cs_n_i <= spi_cs_n;
    mosi_i <= spi_mosi;
end

/*============================================================================*/
always @(posedge clk) begin : shift_and_count
/*============================================================================*/
    sck_ii <= sck_i;
    if ( last_bit_count ) begin
        if ( !last_shift ) begin
            // Ouput already first (SPI_DATA_WIDTH - 1) master bits to slave.
            m_spi_d_i[SPI_DATA_WIDTH-1:1] <= shift_reg[SPI_DATA_WIDTH-2:0];
            // Next shift will be last shift.
            last_shift <= 1;
        end
    end
    if ( cs_n_i ) begin
        bit_counter <= 0;
        shift_reg = s_spi_d;
        sck_ii <= CPOL; // Clock polarity before first clock edge.
        m_spi_d_i <= 0;
        last_shift <= 0;
    end
    else if ( sck_i != sck_ii ) begin
        if ( sck_i != ( CPOL ^ CPHA )) begin
            // SPI shift register
            shift_reg[SPI_DATA_WIDTH-1:1] = shift_reg[SPI_DATA_WIDTH-2:0];
            shift_reg[0] = mosi_i;
            if ( last_bit_count ) begin
                bit_counter <= 0;
            end else begin
                bit_counter <= bit_counter + 1;
            end
        end else begin
            shift_reg = shift_reg;
        end
    end else if ( zero_bit_count && s_spi_dv ) begin
        shift_reg = s_spi_d;
    end else begin
        shift_reg = shift_reg;
    end
    // Output last bit from master directly to slave.
    if ( last_shift ) begin
        m_spi_d_i[0] <= mosi_i;
        if ( zero_bit_count ) begin
            last_shift <= 0;
        end
    end
    miso_i <= shift_reg[SPI_DATA_WIDTH-1];
end

assign m_spi_d = m_spi_d_i;
// Master data to slave is valid when last shift has been done.
assign m_spi_dv = last_shift & zero_bit_count;
assign spi_active = ~spi_cs_n;
assign spi_miso = miso_i;

endmodule
