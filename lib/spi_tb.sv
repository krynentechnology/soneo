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
 *  Description: SPI master/slave/io module simulation
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module spi_tb;
/*============================================================================*/

localparam [0:0] CPOL_1 = 1;
localparam [0:0] CPHA_1 = 1;
localparam SPI_DATA_WIDTH = 8;
localparam NR_MODULES_1 = 5;

reg  clk = 0;
reg  spi_clk_1 = 0;
wire spi_sclk_1;
wire spi_mosi_1;
wire spi_miso_1;
wire spi_cs_n;
wire [SPI_DATA_WIDTH-1:0] s_spi_d_m1;
wire s_spi_dv_m1;
reg  [SPI_DATA_WIDTH-1:0] m_spi_d_1 = 0;
reg  m_spi_dv_1 = 0;
wire m_spi_dr_1;
wire [SPI_DATA_WIDTH-1:0] s_spi_d_1;
wire s_spi_dv_1;
wire [SPI_DATA_WIDTH-1:0] m_spi_d_s1;
wire m_spi_dv_s1;
wire spi_active_s1;
reg  [SPI_DATA_WIDTH-1:0] spi_status_s1 = 0;
wire spi_rd_s1;
wire spi_wr_s1;
wire [13:0] spi_addr_s1;
reg  [SPI_DATA_WIDTH-1:0] spi_data_rd_s1 = 0;
wire [SPI_DATA_WIDTH-1:0] spi_data_wr_s1;
wire [NR_MODULES_1-1:0] select_s1;
wire spi_intr_s1;

spi_master spi_master_1(
    .clk(clk),
    .spi_clk(spi_clk_1),
    .spi_sclk(spi_sclk_1),
    .spi_mosi(spi_mosi_1),
    .spi_miso(spi_miso_1),
    .spi_cs_n(spi_cs_n),
    .m_spi_d(m_spi_d_1),
    .m_spi_dv(m_spi_dv_1),
    .m_spi_dr(m_spi_dr_1),
    .s_spi_d(s_spi_d_m1),
    .s_spi_dv(s_spi_dv_m1));

defparam spi_master_1.CPOL = CPOL_1;
defparam spi_master_1.CPHA = CPHA_1;
defparam spi_master_1.SPI_DATA_WIDTH = SPI_DATA_WIDTH;

spi_slave spi_slave_1(
    .clk(clk),
    .spi_sclk(spi_sclk_1),
    .spi_mosi(spi_mosi_1),
    .spi_miso(spi_miso_1),
    .spi_cs_n(spi_cs_n),
    .s_spi_d(s_spi_d_1),
    .s_spi_dv(s_spi_dv_1),
    .m_spi_d(m_spi_d_s1),
    .m_spi_dv(m_spi_dv_s1),
    .spi_active(spi_active_s1));

defparam spi_slave_1.CPOL = CPOL_1;
defparam spi_slave_1.CPHA = CPHA_1;
defparam spi_slave_1.SPI_DATA_WIDTH = SPI_DATA_WIDTH;

spi_io spi_io_1(
    .clk(clk),
    .m_spi_d(m_spi_d_s1),
    .m_spi_dv(m_spi_dv_s1),
    .s_spi_d(s_spi_d_1),
    .s_spi_dv(s_spi_dv_1),
    .spi_active(spi_active_s1),
    .spi_status(spi_status_s1),
    .spi_rd(spi_rd_s1),
    .spi_wr(spi_wr_s1),
    .spi_addr(spi_addr_s1),
    .spi_data_rd(spi_data_rd_s1),
    .spi_data_wr(spi_data_wr_s1),
    .select(select_s1),
    .spi_intr(spi_intr_s1));

defparam spi_io_1.NR_MODULES = NR_MODULES_1;
defparam spi_io_1.SPI_DATA_WIDTH = SPI_DATA_WIDTH;

// Define system clock period
always #10.173 clk = ~clk; // 49.152 MHz system clock

// Define SPI clock
always #62.500 spi_clk_1 = ~spi_clk_1; // 8 MHz SPI clock

localparam SPI_ADDR_WIDTH = ( SPI_DATA_WIDTH << 1 ) - 2;

/*============================================================================*/
task spi_write_addr_1( input [0:0] write,
                       input [0:0] extend_addr,
                       input [SPI_ADDR_WIDTH-1:0] data_m );
/*============================================================================*/
begin
    wait ( m_spi_dr_1 );
    @( negedge clk );
    m_spi_d_1[SPI_DATA_WIDTH-1] = write;
    m_spi_d_1[SPI_DATA_WIDTH-2] = extend_addr;
    if ( extend_addr ) begin
        m_spi_d_1[SPI_DATA_WIDTH-3:0] = data_m[SPI_ADDR_WIDTH-1:SPI_DATA_WIDTH];
    end else begin
        m_spi_d_1[SPI_DATA_WIDTH-3:0] = data_m[SPI_DATA_WIDTH-3:0];
    end
    m_spi_dv_1 = 1;
    wait ( !m_spi_dr_1 );
    @( negedge clk );
    m_spi_dv_1 = 0;
    if ( extend_addr ) begin
        wait ( m_spi_dr_1 );
        @( negedge clk );
        m_spi_d_1 = data_m[SPI_DATA_WIDTH-1:0];
        m_spi_dv_1 = 1;
        wait ( !m_spi_dr_1 );
        @( negedge clk );
        m_spi_dv_1 = 0;
    end
end
endtask // spi_write_data_1

/*============================================================================*/
task spi_write_data_1( input [SPI_DATA_WIDTH-1:0] data_m );
/*============================================================================*/
begin
    wait ( m_spi_dr_1 );
    @( negedge clk );
    m_spi_d_1 = data_m;
    m_spi_dv_1 = 1;
    wait ( !m_spi_dr_1 );
    @( negedge clk );
    m_spi_dv_1 = 0;
end
endtask // spi_write_data_1

/*============================================================================*/
initial begin
/*============================================================================*/
    #100 // 0.1us
    $display( "SPI simulation started" );
    $display( "CPOL = %d, CPHA = %d", CPOL_1, CPHA_1 );
    spi_status_s1 = 8'h81;
    @(negedge clk);
    if ( !CPHA_1 ) @(negedge clk); // Extra clock cycle required!
    spi_write_data_1( 8'h11 ); // Read single byte
    $display( "01 - Wait select SPI active enable" );
    wait ( spi_active_s1 );
    $display( "02 - Wait select interrupt enable" );
    wait ( spi_intr_s1 );
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != spi_status_s1 ) begin
        $display( "02 - SPI status 0x%h = 0x%h mismatch", s_spi_d_m1, spi_status_s1 );
        $finish;
    end    
    $display( "03 - Wait select active" );
    wait ( select_s1 );
    if ( select_s1 != 5'b00100 ) begin
        $display( "03 - SPI select 0x%h = 0x%h mismatch", 5'b00100, select_s1 );
        $finish;
    end    
    $display( "04 - Wait select SPI active disable" );
    wait ( !spi_active_s1 );
    $display( "05 - Wait select interrupt disable" );
    wait ( !spi_intr_s1 );
    #200
    spi_status_s1 = 8'hC3;
    @(negedge clk);
    if ( !CPHA_1 ) @(negedge clk); // Extra clock cycle required!
    spi_write_data_1( 8'hD9 ); // 1st byte, write modus, extended address
    $display( "06 - Wait select SPI active enable" );
    wait ( spi_active_s1 );
    $display( "07 - Wait select interrupt enable" );
    wait ( spi_intr_s1 );
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != ( 8'h81 ^ 8'hC3 )) begin
        $display( "07 - SPI status 0x%h = 0x%h mismatch", ( 8'h81 ^ 8'hC3 ), s_spi_d_m1 );
        $finish;
    end    
    wait ( !s_spi_dv_m1 );
    spi_write_data_1( 8'h81 ); // 2nd byte, low address
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != spi_status_s1 ) begin
        $display( "08 - SPI status 0x%h = 0x%h mismatch", s_spi_d_m1, spi_status_s1 );
        $finish;
    end    
    $display( "08 - Wait select active" );
    wait ( select_s1 );
    if ( select_s1 != 5'b01000 ) begin
        $display( "08 - SPI select 0x%h = 0x%h mismatch", 5'b01000, select_s1 );
        $finish;
    end    
    spi_write_data_1( 8'hE7 ); // 3rd byte, data
    $display( "09 - Wait select SPI active disable" );
    wait ( !spi_active_s1 );
    #200
    spi_status_s1 = 8'hA5;
    @(negedge clk);
    if ( !CPHA_1 ) @(negedge clk); // Extra clock cycle required!
    spi_write_data_1( 8'h49 ); // 1st byte, read modus, extended address
    $display( "10 - Wait select SPI active enable" );
    wait ( spi_active_s1 );
    $display( "11 - Wait select interrupt enable" );
    wait ( spi_intr_s1 );
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != 8'h66 ) begin
        $display( "11 - SPI status 0x%h = 0x%h mismatch", 8'h66, s_spi_d_m1 );
        $finish;
    end    
    wait ( !s_spi_dv_m1 );
    spi_write_data_1( 8'h83 ); // 2nd byte, low address
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != spi_status_s1 ) begin
        $display( "12 - SPI status 0x%h = 0x%h mismatch", s_spi_d_m1, spi_status_s1 );
        $finish;
    end    
    wait ( !s_spi_dv_m1 );
    $display( "12 - Wait select active" );
    wait ( select_s1 );
    if ( select_s1 != 5'b00010 ) begin
        $display( "12 - SPI select 0x%h = 0x%h mismatch", 5'b00010, select_s1 );
        $finish;
    end    
    spi_write_data_1( 8'hE7 ); // 3rd byte, data
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != 8'h99 ) begin
        $display( "12 - SPI slave data 0x%h = 0x%h mismatch", 8'h99, s_spi_d_m1 );
        $finish;
    end    
    $display( "13 - Wait select SPI active disable" );
    wait ( !spi_active_s1 );
    #200
    spi_write_addr_1( 0, 1, 14'h0983 ); // Read extended address again
    $display( "14 - Wait select active" );
    wait ( select_s1 );
    if ( select_s1 != 5'b00010 ) begin
        $display( "14 - SPI select 0x%h = 0x%h mismatch", 5'b00010, select_s1 );
        $finish;
    end    
    spi_write_data_1( 8'hE7 ); // 3rd byte, data
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != 8'h99 ) begin
        $display( "14 - SPI slave data 0x%h = 0x%h mismatch", 8'h99, s_spi_d_m1 );
        $finish;
    end    
    wait ( !spi_active_s1 );
    spi_write_addr_1( 1, 1, 14'h03 ); // Write address
    $display( "15 - Wait select active" );
    wait ( select_s1 );
    if ( select_s1 != 5'b00001 ) begin
        $display( "15 - SPI select 0x%h = 0x%h mismatch", 5'b00001, select_s1 );
        $finish;
    end    
    spi_write_data_1( 8'hE7 ); // 3rd byte, data
    wait ( !spi_active_s1 );
    spi_write_addr_1( 0, 1, 14'h03 ); // Read address
    $display( "16 - Wait select active" );
    wait ( select_s1 );
    if ( select_s1 != 5'b00001 ) begin
        $display( "16 - SPI select 0x%h = 0x%h mismatch", 5'b00001, select_s1 );
        $finish;
    end    
    spi_write_data_1( 8'h00 ); // 3rd byte, data
    wait ( s_spi_dv_m1 );
    if ( s_spi_d_m1 != 8'hE7 ) begin
        $display( "16 - SPI slave data 0x%h = 0x%h mismatch", 8'hE7, s_spi_d_m1 );
        $finish;
    end    
    $display( "17 - Wait select SPI active disable" );
    wait ( !spi_active_s1 );
    #200
    $display( "Simulation finished" );
    $finish;
end

reg [SPI_DATA_WIDTH-1:0] spi_data_wr = 0;
/*============================================================================*/
always @(posedge clk) begin : simulate_block_ram
/*============================================================================*/
    spi_data_rd_s1 <= 0;
    if ( spi_rd_s1 && ( spi_addr_s1[7:0] == 8'h83 )) begin
        spi_data_rd_s1 <= 8'h99;
    end
    if ( spi_wr_s1 && ( spi_addr_s1[7:0] == 8'h03 )) begin
        spi_data_wr <= spi_data_wr_s1;
    end
    if ( spi_rd_s1 && ( spi_addr_s1[7:0] == 8'h03 )) begin
        spi_data_rd_s1 <= spi_data_wr;
    end
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "spi_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule // spi_tb
