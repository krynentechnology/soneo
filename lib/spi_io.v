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
 *  Description: SPI module I/O selection for word read/write - interrupt
 *
 *  The first word from the SPI master specifies R/W action and address width:
 *    MSB     = R/W, 0 = read, 1 = write.
 *    MSB-1   = Extendend address, 0 = SPI_DATA_WIDTH-2 bit address,
 *                                 1 = SPI_ADDR_WIDTH bit address.
 *    MSB-2:0 = SPI_DATA_WIDTH-2 bit address when BIT MSB-1 = 0,
 *              upper SPI_DATA_WIDTH-2 bit of the SPI_ADDR_WIDTH bit address
 *              when BIT MSB-1 = 1.
 *
 *  The second SPI word input from the SPI master specifies the lowest
 *  SPI_DATA_WIDTH bit of the SPI_ADDR_WIDTH bit address when BIT MSB-1 = 1 of
 *  the first SPI word input, otherwise it is the first data word input.
 *
 *  The upper spi_addr[SPI_ADDR_WIDTH-1:SPI_ADDR_WIDTH-NR_MODULES_WIDTH] space
 *  selects the module. The spi_status is monitored and the interrupt signal
 *  spi_intr is raised when this status changes.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module spi_io #(
/*============================================================================*/
    parameter NR_MODULES = 5,
    parameter SPI_DATA_WIDTH = 8 ) // SPI word size
    (
    clk,
    m_spi_d, m_spi_dv,
    s_spi_d, s_spi_dv,
    spi_active,
    spi_status,
    spi_rd,
    spi_wr,
    spi_addr,
    spi_data_rd, // Should be 0 when select = 0
    spi_data_wr,
    select,
    spi_intr
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

localparam MAX_MODULES_WIDTH = 6;
localparam NR_MODULES_WIDTH = clog2( NR_MODULES );
localparam SPI_ADDR_WIDTH = ( SPI_DATA_WIDTH << 1 ) - 2;

input  wire clk;
input  wire [SPI_DATA_WIDTH-1:0] m_spi_d;
input  wire m_spi_dv;
output wire [SPI_DATA_WIDTH-1:0] s_spi_d;
output wire s_spi_dv;
input  wire spi_active;
input  wire [SPI_DATA_WIDTH-1:0] spi_status;
output wire spi_rd;
output wire spi_wr;
output wire [SPI_ADDR_WIDTH-1:0] spi_addr;
input  wire [SPI_DATA_WIDTH-1:0] spi_data_rd; // Should be 0 when select = 0
output wire [SPI_DATA_WIDTH-1:0] spi_data_wr;
output wire [NR_MODULES-1:0] select;
output wire spi_intr;

reg [SPI_DATA_WIDTH-1:0] m_spi_i = 0;

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
     if ( SPI_DATA_WIDTH < ( 3 + NR_MODULES_WIDTH )) begin
        $display( "SPI_DATA_WIDTH < ( 3 + NR_MODULES_WIDTH )!");
        $finish;
    end
   if (( NR_MODULES < 1 ) || ( NR_MODULES > ( 2 ** MAX_MODULES_WIDTH ))) begin
        $display( "NR_MODULES error" );
        $finish;
    end
end // parameter_check

reg [SPI_DATA_WIDTH-1:0] s_spi_d_i = 0;
reg s_spi_dv_i = 0;
reg spi_rd_i = 0;
reg spi_rd_ii = 0;
reg spi_wr_i = 0;
reg [SPI_ADDR_WIDTH-1:0] spi_addr_i = 0;
reg addr_valid_i = 0;
reg addr_extended = 0;
reg write_enable = 0;
reg next_address = 0;
reg [SPI_DATA_WIDTH-1:0] spi_data_wr_i = 0;
reg [SPI_DATA_WIDTH-1:0] spi_status_i = 0;
reg [SPI_DATA_WIDTH-1:0] spi_status_intr = 0;
reg [NR_MODULES-1:0] select_i = 0;
reg spi_intr_i = 0;

/*============================================================================*/
always @(posedge clk) begin : io_handshake // Interpret first SPI bytes (R/W, address)
/*============================================================================*/
    spi_rd_i <= 0;
    spi_rd_ii <= spi_rd_i; // Delay read actions one clock clycle
    s_spi_dv_i <= spi_rd_ii; // Valid one clock clycle later
    spi_wr_i <= 0;
    next_address <= 0;
    // Monitor spi_status change
    spi_status_i <= spi_status;
    spi_status_intr <= spi_status_intr | ( spi_status ^ spi_status_i );
    if ( spi_status_intr ) begin
        spi_intr_i <= 1; // Raise SPI slave interrupt
    end
    // Process SPI data
    if ( spi_active ) begin
        if ( m_spi_dv ) begin
            if ( addr_valid_i ) begin
                spi_rd_i <= ~write_enable;
                spi_wr_i <= write_enable;
                spi_data_wr_i <= m_spi_d;
                s_spi_d_i <= 0; // Reset s_spi_d_i
            end
            else if ( addr_extended ) begin // SPI_ADDR_WIDTH-bit extended address
                spi_addr_i[SPI_DATA_WIDTH-1:0] <= m_spi_d;
                addr_valid_i <= 1;
                spi_rd_i <= ~write_enable;
                s_spi_d_i <= 0; // Reset s_spi_d_i
            end else begin
                if ( m_spi_d[SPI_DATA_WIDTH-2] ) begin // SPI extented address
                    addr_extended <= 1;
                end else begin // SPI_DATA_WIDTH-2 bit address
                    addr_valid_i <= 1;
                    spi_rd_i <= ~m_spi_d[SPI_DATA_WIDTH-1]; // MSB, 0 = read
                end
                write_enable <= m_spi_d[SPI_DATA_WIDTH-1]; // MSB, 1 = write
                if ( m_spi_d[SPI_DATA_WIDTH-2] | m_spi_d[SPI_DATA_WIDTH-1] ) begin // SPI extented address or write
                    s_spi_d_i <= spi_status; // Actual spi status
                    s_spi_dv_i <= 1;
                end
                spi_addr_i[SPI_ADDR_WIDTH-1:SPI_DATA_WIDTH] <= m_spi_d[SPI_DATA_WIDTH-3:0];
                spi_intr_i <= 0; // Reset SPI slave interrupt
                spi_status_intr <= 0;
            end
        end
        else if ( next_address ) begin
            if ( addr_extended ) begin
                spi_addr_i[SPI_ADDR_WIDTH-NR_MODULES_WIDTH-1:0] <= spi_addr_i[SPI_ADDR_WIDTH-NR_MODULES_WIDTH-1:0] + 1;
            end else begin
                spi_addr_i[SPI_ADDR_WIDTH-NR_MODULES_WIDTH-1:SPI_DATA_WIDTH] <= spi_addr_i[SPI_ADDR_WIDTH-NR_MODULES_WIDTH-1:SPI_DATA_WIDTH] + 1;
            end
        end
        else if ( addr_extended || ( !addr_extended && ( NR_MODULES_WIDTH < MAX_MODULES_WIDTH ))) begin // See spi_addr_i increment
            next_address <= spi_wr_i | spi_rd_ii;
        end
    end
    else begin
        spi_rd_ii <= 0;
        s_spi_dv_i <= 0;
        s_spi_d_i <= spi_status_intr;
        spi_addr_i <= 0;
        addr_valid_i <= 0;
        spi_intr_i <= 0;
        addr_extended <= 0;
        write_enable <= 0;
    end
end // io_handshake

/*============================================================================*/
always @(*) begin : select_module
/*============================================================================*/
    reg [NR_MODULES_WIDTH-1:0] i;
    select_i = 0;
    if ( addr_valid_i ) begin
        for ( i = 0; i < NR_MODULES; i = i + 1 ) begin
            if ( i == spi_addr_i[SPI_ADDR_WIDTH-1:SPI_ADDR_WIDTH-NR_MODULES_WIDTH] ) begin
                select_i[i] = 1;
            end
        end
    end
end // select_module

assign s_spi_d = s_spi_d_i | spi_data_rd;
assign s_spi_dv = s_spi_dv_i;
assign spi_rd = spi_rd_ii;
assign spi_wr = spi_wr_i;
assign spi_addr = spi_addr_i;
assign spi_data_wr = spi_data_wr_i;
assign select = select_i;
assign spi_intr = spi_intr_i;

endmodule // spi_io
