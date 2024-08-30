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
 *  Description: SPI master
 *
 *  Specification: https://en.wikipedia.org/wiki/Serial_Peripheral_Interface
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module spi_master #(
/*============================================================================*/
    parameter [0:0] CPOL = 1, // CPOL = 0, first clock edge = 0/1, second edge = 1/0 transition
                              // CPOL = 1, first clock edge = 1/0, second edge = 0/1 transition
    parameter [0:0] CPHA = 1, // CPHA = 0, data valid during first clock edge
                              // CPHA = 1, data valid during second clock edge
    parameter SPI_DATA_WIDTH = 8 ) // SPI word size
    (
    input  wire clk,
    input  wire spi_clk,
    output wire spi_sclk, // SPI serial clock
    output wire spi_mosi, // SPI master out, slave in
    input  wire spi_miso, // SPI master in, slave out
    output wire spi_cs_n, // SPI chip select, low active
    input  wire [SPI_DATA_WIDTH-1:0] m_spi_d, // Data from master
    input  wire m_spi_dv, // Data valid
    output wire m_spi_dr, // Ready for data
    output wire [SPI_DATA_WIDTH-1:0] s_spi_d, // Data from slave
    output wire s_spi_dv // Data valid
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
reg [SPI_DATA_WIDTH-1:0] s_spi_d_i = 0;
reg m_spi_dr_i = 1;
reg [2:0] m_spi_dr_delay = 0;
reg last_shift = 0;
reg [BIT_COUNTER_WIDTH-1:0] bit_counter = 0;
reg [SPI_DATA_WIDTH-1:0] shift_reg = 0;
wire last_bit_count;
wire zero_bit_count;
wire spi_m_dv;

assign last_bit_count = ( SPI_DATA_WIDTH - 1 ) == bit_counter;
assign zero_bit_count = 0 == bit_counter;
assign spi_m_dv = zero_bit_count && m_spi_dv && m_spi_dr_i;

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if ( SPI_DATA_WIDTH < 2 ) begin
        $display( "SPI_DATA_WIDTH < 2!" );
        $finish;
    end
end // parameter_check

/*============================================================================*/
always @(posedge clk) begin : synchronize
/*============================================================================*/
    sck_i <= spi_clk;
    sck_ii <= sck_i;
    miso_i <= spi_miso;
end // synchronize

/*============================================================================*/
always @(posedge clk) begin : shift_and_count
/*============================================================================*/
    m_spi_dr_delay <= {m_spi_dr_delay[1:0], m_spi_dr_i};
    // Check for last shift action
    if ( last_bit_count ) begin
        if ( !last_shift ) begin
            // Ouput already first 7 slave bits to master.
            s_spi_d_i[SPI_DATA_WIDTH-1:1] <= shift_reg[SPI_DATA_WIDTH-2:0];
            // Next shift will be last shift.
            last_shift <= 1;
        end
    end
    if ( cs_n_i ) begin
        s_spi_d_i <= 0;
        m_spi_dr_i <= 1;
        bit_counter <= 0;
        last_shift <= 0;
        if ( spi_m_dv && ( CPOL == sck_i )) begin
            shift_reg = m_spi_d;
            cs_n_i <= 0;
            m_spi_dr_i <= 0;
            m_spi_dr_delay <= 0;
        end else begin
            shift_reg = 0;
        end
    end else if ( sck_i != sck_ii ) begin
        if ( sck_i != ( CPOL ^ CPHA )) begin
            // SPI shift register
            shift_reg[SPI_DATA_WIDTH-1:1] = shift_reg[SPI_DATA_WIDTH-2:0];
            shift_reg[0] = miso_i;
            if ( last_bit_count ) begin
                bit_counter <= 0;
            end else begin
                bit_counter <= bit_counter + 1;
            end
        end
        else begin
            shift_reg = shift_reg;
        end
    end else if ( spi_m_dv ) begin
        shift_reg = m_spi_d;
        m_spi_dr_i <= 0;
    end else begin
        shift_reg = shift_reg;
        if ( &m_spi_dr_delay && ( CPOL == spi_clk )) begin
            cs_n_i <= 1;
        end
    end
    // Output last bit from master directly to slave.
    if ( last_shift ) begin
        s_spi_d_i[0] <= miso_i;
        if ( zero_bit_count ) begin
            m_spi_dr_i <= 1;
            last_shift <= 0;
        end
    end
    // Output shift register
    mosi_i <= shift_reg[SPI_DATA_WIDTH-1];
end

assign spi_sclk = cs_n_i ? CPOL : spi_clk;
assign spi_mosi = mosi_i;
assign spi_cs_n = cs_n_i;
assign s_spi_d = s_spi_d_i;
assign s_spi_dv = last_shift & zero_bit_count;
assign m_spi_dr = m_spi_dr_i;

endmodule
