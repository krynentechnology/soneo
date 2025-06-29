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
 *  Description: I2C master module simulation
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module i2c_m_tb;
/*============================================================================*/

reg clk = 0;
reg rst_n = 0;

reg  [9:0] s_i2c_da_1 = 0;
reg  s_i2c_rd_1 = 0;
reg  s_i2c_10bit_1 = 0;
reg  [7:0] s_i2c_ra_1 = 0;
reg  s_i2c_re_1 = 0;
reg  s_i2c_av_1 = 0;
wire s_i2c_ar_1;
reg  [7:0] s_i2c_d_1 = 0;
reg  s_i2c_dv_1 = 0;
wire s_i2c_dr_1;
wire [7:0] m_i2c_d_1;
wire m_i2c_dv_1;
wire ack_nack_1;
reg  ack_nack_i_1 = 0;
wire ack_nack_o_1;
wire SCL_1;
wire SDA_1;
reg  sda_i_1 = 0;
wire sda_o_1;
wire sda_oe_1;

i2c_m #(
    .CLK_FREQ( 100E6 ), // 100MHz
    .BIT_RATE( 10E6 ), // 10MHz
    .TL_BIDIR( 1 ))
i2c_1 (
    .clk(clk),
    .rst_n(rst_n),
    .s_i2c_da(s_i2c_da_1),
    .s_i2c_rd(s_i2c_rd_1),
    .s_i2c_10bit(s_i2c_10bit_1),
    .s_i2c_ra(s_i2c_ra_1),
    .s_i2c_re(s_i2c_re_1),
    .s_i2c_av(s_i2c_av_1),
    .s_i2c_ar(s_i2c_ar_1),
    .s_i2c_d(s_i2c_d_1),
    .s_i2c_dv(s_i2c_dv_1),
    .s_i2c_dr(s_i2c_dr_1),
    .m_i2c_d(m_i2c_d_1),
    .m_i2c_dv(m_i2c_dv_1),
    .ack_nack(ack_nack_1),
    .ack_nack_i(ack_nack_i_1),
    .ack_nack_o(ack_nack_o_1),
    .scl(SCL_1),
    .sda(SDA_1),
    .sda_i(sda_i_1),
    .sda_o(sda_o_1),
    .sda_oe(sda_oe_1)
    );

always #5  clk = ~clk; // 100 MHz clock

reg [1:0] scl_i_1 = 0;
reg [1:0] scl_ii_1 = 0;
reg [7:0] s_i2c_d_i_1 = 0;
reg [7:0] m_i2c_d_i_1 = 0;
/*============================================================================*/
always @(posedge clk) begin : sda_data_rw
/*============================================================================*/
    scl_i_1 <= {scl_i_1[0], SCL_1};
    scl_ii_1 <= scl_i_1;
    if ( !ack_nack_1 ) begin
        if ( !s_i2c_rd_1 ) begin // Write
            sda_i_1 <= 0; // Slave ACK
        end
        if ( 2'b01 == scl_i_1 ) begin // Rising edge SCL
            s_i2c_d_i_1 <= {s_i2c_d_i_1[6:0], sda_o_1}; // Read SDA
        end
        if ( s_i2c_rd_1 ) begin // Read
            sda_i_1 <= m_i2c_d_i_1[7]; // Write SDA
            if ( 2'b10 == scl_i_1 ) begin // Falling edge SCL
                m_i2c_d_i_1 <= {m_i2c_d_i_1[6:0], 1'b1};
            end
        end
    end
end // sda_data_rw



reg passed = 0;
integer i;
/*============================================================================*/
task i2c_write( input [9:0] da,
                input [7:0] ra,
                input string data );
/*============================================================================*/
begin
    s_i2c_da_1 = da;
    s_i2c_rd_1 = ( 0 == data.len() ); // Write, read for repeated start.
    s_i2c_10bit_1 = ( da[9:7] > 0 );
    s_i2c_ra_1 = ra;
    s_i2c_re_1 = ( ra > 0 );
    wait ( s_i2c_ar_1 );
    wait ( clk ) @( negedge clk );
    s_i2c_av_1 = 1;
    wait ( !s_i2c_ar_1 );
    wait ( clk ) @( negedge clk );
    s_i2c_av_1 = 0;
    passed = 1;
    for ( i = 0; i < data.len(); i = i + 1 ) begin
        wait ( s_i2c_dr_1 );
        wait ( clk ) @( negedge clk );
        if ( i > 0 ) begin
            passed = passed && ( s_i2c_d_i_1 == data[i-1] );
        end else if ( s_i2c_re_1 ) begin
            passed = passed && ( s_i2c_d_i_1 == ra );
        end else if ( s_i2c_10bit_1 ) begin
            passed = passed && ( s_i2c_d_i_1 == da[7:0] );
        end else begin
            passed = passed && ( s_i2c_d_i_1 == {da[6:0], 1'b0} );
        end
        s_i2c_d_1 = data[i];
        s_i2c_dv_1 = 1;
        wait ( !s_i2c_dr_1 );
        wait ( clk ) @( negedge clk );
        s_i2c_dv_1 = 0;
    end
    if ( data.len() ) begin
        wait ( s_i2c_dr_1 );
        wait ( clk ) @( negedge clk );
        if ( i > 0 ) begin
            passed = passed && ( s_i2c_d_i_1 == data[i-1] );
        end
        wait ( s_i2c_ar_1 );
    end else begin // Repeated start condition
        wait ( ack_nack_1 );
        if ( s_i2c_10bit_1 ) begin
            passed = passed && ( s_i2c_d_i_1 == {5'b11110, da[9:8], 1'b0} );
            wait ( !ack_nack_1 );
        end else begin
            passed = ( s_i2c_d_i_1 == {da[6:0], 1'b0} );
            wait ( !ack_nack_1 );
        end
        wait ( ack_nack_1 );
        if ( s_i2c_10bit_1 ) begin
            passed = passed && ( s_i2c_d_i_1 == da[7:0] );
            wait ( !ack_nack_1 );
            if ( s_i2c_re_1 ) begin
                wait ( ack_nack_1 );
                passed = passed && ( s_i2c_d_i_1 == ra );
                wait ( !ack_nack_1 );
            end
        end else if ( s_i2c_re_1 ) begin
            passed = passed && ( s_i2c_d_i_1 == ra );
            wait ( !ack_nack_1 );
        end
    end
end
endtask // i2c_write

/*============================================================================*/
task i2c_read( input [9:0] da,
               input [7:0] ra,
               input string data ); // Data to read by I2C master!
/*============================================================================*/
begin
    s_i2c_da_1 = da;
    s_i2c_rd_1 = 1; // Read
    s_i2c_10bit_1 = ( da[9:7] > 0 );
    s_i2c_ra_1 = ra;
    s_i2c_re_1 = ( ra > 0 );
    ack_nack_i_1 = 0;
    passed = 1;
    if ( s_i2c_re_1 ) begin
        i2c_write( da, ra, "" ); // Repeated start, s_i2c_ar stays low!
        s_i2c_re_1 = 0;
    end else begin
        wait ( s_i2c_ar_1 );
        wait ( clk ) @( negedge clk );
        s_i2c_av_1 = 1;
        wait ( !s_i2c_ar_1 );
        wait ( clk ) @( negedge clk );
        s_i2c_av_1 = 0;
    end
    if ( s_i2c_10bit_1 ) begin
        wait ( ack_nack_1 );
        wait ( !ack_nack_1 );
    end
    if ( s_i2c_re_1 ) begin
        wait ( ack_nack_1 );
        wait ( !ack_nack_1 );
    end
    for ( i = 0; i < data.len(); i = i + 1 ) begin
        wait ( ack_nack_1 );
        wait ( clk ) @( negedge clk );
        if ( 0 == i ) begin
            if ( s_i2c_re_1 ) begin
                passed = passed && ( s_i2c_d_i_1 == ra );
            end else if ( s_i2c_10bit_1 ) begin
                passed = passed && ( s_i2c_d_i_1 == da[7:0] );
            end else begin
                passed = passed && ( s_i2c_d_i_1 == {da[6:0], 1'b1} );
            end
        end
        wait ( !ack_nack_1 );
        wait ( 2'b10 == scl_ii_1 );
        m_i2c_d_i_1 = data[i];
        wait ( m_i2c_dv_1 )
        passed = passed && ( m_i2c_d_1 == data[i] );
    end
    ack_nack_i_1 = 1; // Last byte sent
    wait ( s_i2c_ar_1 );
    ack_nack_i_1 = 0;
end
endtask // i2c_read

/*============================================================================*/
function string result( input reg passed );
/*============================================================================*/
begin
    result = passed ? "passed" : "failed";
end
endfunction

/*============================================================================*/
initial begin
/*============================================================================*/
    #100 // 0.1us
    $display( "I2C master simulation started" );
    rst_n = 1;
    wait ( s_i2c_ar_1 );
    #200 // 0.2us
    i2c_write( 10'h041, 8'h00, "M1" );
    $display( "I2C master 7-bit, no register, write - %s", result( passed ));
    #200 // 0.2us
    i2c_write( 10'h289, 8'h00, "M2" );
    $display( "I2C master 10-bit, no register, write - %s", result( passed ));
    #200 // 0.2us
    i2c_write( 10'h041, 8'h81, "M3" );
    $display( "I2C master 7-bit, register, write - %s", result( passed ));
    #200 // 0.2us
    i2c_write( 10'h289, 8'h81, "M4" );
    $display( "I2C master 10-bit, register, write - %s", result( passed ));
    #200 // 0.2us
    i2c_read( 10'h041, 8'h00, "S1" );
    $display( "I2C master 7-bit, no register, read - %s", result( passed ));
    #200 // 0.2us
    i2c_read( 10'h289, 8'h00, "S2" );
    $display( "I2C master 10-bit, no register, read - %s", result( passed ));
    #200 // 0.2us
    i2c_read( 10'h041, 8'h81, "S3" );
    $display( "I2C master 7-bit, register, read - %s", result( passed ));
    #200 // 0.2us
    i2c_read( 10'h289, 8'h81, "S4" );
    $display( "I2C master 10-bit, register, read - %s", result( passed ));
    #500 // 0.5us
    $display( "Simulation finished" );
    $finish;
end

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "i2c_m_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule // i2c_m_tb
