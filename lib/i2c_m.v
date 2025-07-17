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
 *  Description: I2C master
 *
 *  I2C communication is initiated by the I2C master sending a high-to-low
 *  transition on the SDA line while the SCL is high (START condition) and
 *  terminated by the master sending a low-to-high transition on the SDA line
 *  while the SCL is high (STOP condition). Instead of termination (STOP
 *  condition) the master could intiate a new I2C commnunication by a START
 *  condition.
 *
 *  The I2C protocol has a byte format starting with the MSB {after START/ACK
 *  condition). Data bits are set during the low phase of the I2C clock (SCL)
 *  and hold and sampled during the high phase. The I2C receiver (master or
 *  addressed slave) should send an acknowledge (ACK) after the LSB by holding
 *  the SDA line low during the SCL low/high phase - the sender has released the
 *  SDA line during the ACK/NACK. A NACK (not acknowlegde) is sent by holding
 *  the SDA line high during the SCL low/high phase and indicates a receiver
 *  error (or does not accept more data) or master reading done. A NACK should
 *  be followed up by a STOP condition.
 *
 *  The I2C protocol starts with a 7- or 10-bit device (slave) address followed
 *  by an 8-bit (device) register address if the I2C device has registers to
 *  address. The LSB of the (first/upper) address byte indicates a read (=1) or
 *  write (=0) action. In 10-bit address mode the address upper 5 bits (7-3) are
 *  set to 0xF0 (0x11110XXR). In case of reading from I2C device registers, the
 *  master will first write (LSB=0) the (device) register address to read from
 *  and then send a repeated START condition with device address to read (LSB=1)
 *  the data from the (device) register address. Once the master has received
 *  the expected number of bytes, it sends a NACK followed up by a STOP
 *  condition.
 *
 *  https://en.wikipedia.org/wiki/I%C2%B2C
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module i2c_m #(
/*============================================================================*/
    parameter real CLK_FREQ = 100E6,
    parameter real BIT_RATE = 100E3,
    parameter [0:0] TL_BIDIR = 0 ) // 1 = top level bidirectional pin only
    (
    input  wire clk, // Clock rate > 4 * SCL clk clock rate!
    input  wire rst_n, // High when clock stable!
    input  wire [9:0] s_i2c_da, // Device address
    input  wire s_i2c_rd, // Read = 1, Write = 0
    input  wire s_i2c_10bit, // 10-bit device address mode
    input  wire [7:0] s_i2c_ra, // Register address
    input  wire s_i2c_re, // Register enable (I2C device has registers)
    input  wire s_i2c_av,// Address valid
    output wire s_i2c_ar, // Address ready
    input  wire [7:0] s_i2c_d, // Data in
    input  wire s_i2c_dv,// Data valid
    output wire s_i2c_dr, // Data ready
    output reg  [7:0] m_i2c_d = 0, // Data out
    output reg  m_i2c_dv = 0, // Data valid
    output wire ack_nack, // ACK/NACK expected (SCL period after data byte)
    input  wire ack_nack_i, // ACK/NACK master
    output reg  ack_nack_o = 0, // ACK/NACK slave
    output wire scl, // I2C clock
    inout  wire sda, // I2C data
    input  wire sda_i, // I2C data in
    output reg  sda_o = 1, // I2C data out
    output reg  sda_oe = 1 // I2C data out enable
    );

/*============================================================================*/
initial begin : parameter_check
/*============================================================================*/
    if (( CLK_FREQ / BIT_RATE ) < 4.0 ) begin
        $display( "CLK_FREQ / BIT_RATE ) < 4.0!" );
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

localparam integer TOGGLE_COUNT = ( CLK_FREQ / BIT_RATE / 2.0 );
localparam CLK_COUNT_WIDTH = clog2( TOGGLE_COUNT );
localparam CLKW = CLK_COUNT_WIDTH;
localparam [CLKW-1:0] TX_SAMPLE = TOGGLE_COUNT >> 1; // START, STOP, DATA (SCL = 0)
localparam [CLKW-1:0] RX_SAMPLE = TOGGLE_COUNT - 1; // Slave DATA (SCL = 1)
localparam ACK_BIT_COUNT = 9;
localparam BIT_COUNT_1 = 4'd1;

reg scl_i = 1;
reg [CLKW-1:0] clk_count = 0;
reg [3:0] bit_count = 0;
reg [9:0] s_i2c_da_i = 0;
reg s_i2c_rd_i = 0;
reg s_i2c_10bit_i = 0;
reg s_i2c_10bit_ii = 0;
reg s_i2c_ar_n = 0;
reg s_i2c_dr_i = 0;
reg [7:0] s_i2c_ra_i = 0;
reg s_i2c_re_i = 0;
reg [7:0] s_i2c_d_i = 0;
reg init = 0;
reg start = 0;
reg repeated_start = 0;
reg repeated_start_i = 0;
reg repeated_start_ii = 0;
reg read = 0;
reg write = 0;
reg stop = 0;
reg stop_i = 0;

wire sda_ii;
wire data_stage;
wire rx;

assign s_i2c_dr = s_i2c_dr_i;
assign scl = scl_i;
assign s_i2c_ar = ~s_i2c_ar_n;
assign sda = sda_oe ? sda_o : 1'bZ;
assign sda_ii = TL_BIDIR ? sda_i : sda;
assign data_stage = ~( s_i2c_10bit_i || s_i2c_re_i );
assign ack_nack = ( ACK_BIT_COUNT == bit_count );
assign rx = ( scl_i & ( RX_SAMPLE == clk_count ));

/*============================================================================*/
always @(posedge clk) begin : i2c_protocol
/*============================================================================*/
    if ( init || s_i2c_ar_n ) begin
        clk_count <= clk_count + 1;
        if ( TOGGLE_COUNT == clk_count ) begin
            scl_i <= ~scl_i; // Toggle scl
            clk_count <= 0;
            if ( scl_i ) begin // SCL = 1
                bit_count <= bit_count + 1;
                if ( ack_nack ) begin
                    bit_count <= BIT_COUNT_1;
                    read <= s_i2c_rd_i & data_stage;
                    if ( s_i2c_10bit_i ) begin
                        s_i2c_10bit_i <= 0;
                        // Write lower byte 10-bit device address
                        s_i2c_d_i <= s_i2c_da_i;
                    end else if ( s_i2c_re_i ) begin
                        s_i2c_re_i <= 0;
                        // Write register address
                        s_i2c_d_i <= s_i2c_ra;
                    end
                    if ( ack_nack_i || ack_nack_o || s_i2c_dr ) begin
                        read <= 0;
                        write <= 0;
                        stop <= 1;
                    end
                end
                if ( data_stage && repeated_start_i) begin
                    repeated_start_i <= 0;
                    repeated_start <= repeated_start_i;
                    scl_i <= 1; // Do not toggle scl!
                    sda_o <= 1; // Setup repeated start condition
                    sda_oe <= 1;
                end
                if (( ack_nack && init ) || stop_i ) begin
                    init <= 0;
                    stop <= 0;
                    stop_i <= 0;
                    scl_i <= 1; // Do not toggle scl!
                    s_i2c_ar_n <= 0; // I2C communication stops
                end
            end
        end
        if ( !init ) begin
            if ( read ) begin
                sda_oe <= 0;
                if ( rx ) begin
                    if ( !ack_nack ) begin
                        s_i2c_d_i <= {s_i2c_d_i[6:0], sda_ii};
                    end
                end
            end else if ( TX_SAMPLE == clk_count ) begin
                if ( scl_i ) begin // SCL = 1
                    if ( start ) begin
                        start <= 0;
                        sda_o <= 0;
                        sda_oe <= 1;
                    end
                    if ( stop_i ) begin
                        sda_o <= 1;
                    end
                end else begin // SCL = 0
                    if ( stop ) begin
                        stop <= 0;
                        stop_i <= 1;
                        sda_o <= 0;
                        sda_oe <= 1;
                    end else if ( !ack_nack ) begin
                        sda_o <= s_i2c_d_i[7];
                        sda_oe <= 1;
                        s_i2c_d_i <= {s_i2c_d_i[6:0], 1'b1};
                    end
                end
            end
            s_i2c_dr_i <= s_i2c_dr_i & ~s_i2c_dv;
            m_i2c_dv <= 0;
            if ( ack_nack ) begin // I2C master/slave ACK/NACK
                if ( data_stage && repeated_start_ii ) begin
                    repeated_start_ii <= 0;
                    repeated_start_i <= repeated_start_ii;
                end else begin
                    sda_oe <= read;
                    if ( read ) begin
                        sda_o <= ack_nack_i;
                        m_i2c_d <= s_i2c_d_i;
                        m_i2c_dv <= 1;
                    end
                    if ( write ) begin // Write
                        s_i2c_dr_i <= data_stage;
                        if ( s_i2c_dv ) begin
                            write <= 0;
                            s_i2c_dr_i <= 0;
                            s_i2c_d_i <= s_i2c_d;
                        end
                    end
                    if ( rx && !s_i2c_rd_i ) begin
                        ack_nack_o <= sda_ii;
                    end
                end
            end else begin
                write <= !s_i2c_rd_i;
                s_i2c_dr_i <= 0;
            end
        end
    end
    if (( s_i2c_av  && s_i2c_ar ) || repeated_start ) begin
        s_i2c_ar_n <= 1; // ~s_i2c_ar
        if ( repeated_start ) begin
            repeated_start <= 0;
            if ( s_i2c_10bit_ii ) begin
                // Always first write (upper) device address
                s_i2c_d_i[0] <= 0;
                s_i2c_d_i[2:1] <= s_i2c_da_i[9:8];
                s_i2c_d_i[7:3] <= 5'b11110;
            end else begin
                s_i2c_d_i[7:0] <= {s_i2c_da_i[6:0], 1'b1}; // Read!
            end
            s_i2c_10bit_i <= s_i2c_10bit_ii;
        end else begin
            s_i2c_da_i <= s_i2c_da;
            s_i2c_rd_i <= s_i2c_rd;
            s_i2c_10bit_i <= s_i2c_10bit;
            s_i2c_10bit_ii <= s_i2c_10bit;
            s_i2c_ra_i <= s_i2c_ra;
            s_i2c_re_i <= s_i2c_re;
            if ( s_i2c_10bit ) begin
                // Always first write (upper) device address
                s_i2c_d_i[0] <= ~s_i2c_re & s_i2c_rd;
                s_i2c_d_i[2:1] <= s_i2c_da[9:8];
                s_i2c_d_i[7:3] <= 5'b11110;
            end else begin
                s_i2c_d_i[7:0] <= {s_i2c_da[6:0], ( ~s_i2c_re & s_i2c_rd )};
            end
            repeated_start_i <= 0;
            repeated_start_ii <= s_i2c_re & s_i2c_rd;
        end
        clk_count <= 0;
        bit_count <= 0; // START condition
        start <= 1;
        read <= 0;
        write <= 0;
        scl_i <= 1;
        sda_o <= 1;
        sda_oe <= 1;
    end
    if ( !rst_n ) begin
        s_i2c_ar_n <= 1;
        m_i2c_d <= 0;
        m_i2c_dv <= 0;
        s_i2c_dr_i <= 0;
        stop <= 0;
        stop_i <= 0;
        repeated_start <= 0;
        // Start with ACK_BIT_COUNT clock outputs, see AN-686 I2C reset.
        init <= 1;
        scl_i <= 1;
        sda_o <= 1;
        sda_oe <= 1;
        clk_count <= 0;
        bit_count <= 0;
    end
end // i2c_protocol

endmodule // i2c_m