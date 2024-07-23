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
 *  Description:
 *
 *  Sine wave generator 3rd order polynomial interpolation test bench
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module sine_wg_pol_tb;

parameter NR_CHANNELS = 4;
parameter CHANNEL_WIDTH = $clog2( NR_CHANNELS );
parameter RADIAN_WIDTH = 24;

reg clk = 0;
reg rst_n = 0;

reg  [RADIAN_WIDTH-1:0] s_sine_d = 0;
reg  s_sine_phase = 0;
reg  [CHANNEL_WIDTH-1:0] s_sine_ch = 0;
reg  s_sine_dv = 0;
wire s_sine_dr;
wire [RADIAN_WIDTH-1:0] m_sine_d;
wire [CHANNEL_WIDTH-1:0] m_sine_ch;
wire m_sine_dv;
reg  m_sine_dr = 0;

sine_wg_pol swg_1(
    .clk(clk),
    .rst_n(rst_n),
    .s_sine_d(s_sine_d),
    .s_sine_phase(s_sine_phase),
    .s_sine_ch(s_sine_ch),
    .s_sine_dv(s_sine_dv),
    .s_sine_dr(s_sine_dr),
    .m_sine_d(m_sine_d),
    .m_sine_ch(m_sine_ch),
    .m_sine_dv(m_sine_dv),
    .m_sine_dr(m_sine_dr)
    );

defparam swg_1.NR_CHANNELS = NR_CHANNELS;
defparam swg_1.RADIAN_WIDTH = RADIAN_WIDTH;

localparam real MATH_PI = 3.141592653589793115997963;
localparam real FACTOR_1_0 = 2.0 ** ( RADIAN_WIDTH - 3 );
localparam signed [RADIAN_WIDTH-1:0] PI = FACTOR_1_0 * MATH_PI;
localparam PHASE_STEP = 256;
localparam real PHASE = FACTOR_1_0 * MATH_PI / PHASE_STEP;
localparam signed [RADIAN_WIDTH-1:0] ADD_PHASE = PHASE;

// Generate clock 49.152MHz
always #( 20.345 / 2 ) clk = ~clk;

localparam US_10 = 10000;
localparam US_100 = 10 * US_10;
localparam MS_1 = 10 * US_100;
localparam MS_10 = 10 * MS_1;

/*============================================================================*/
task set_sine_rad( input [RADIAN_WIDTH-1:0] sine_d, input [0:0] add_phase );
/*============================================================================*/
begin
    s_sine_d = sine_d;
    wait( s_sine_dr )
    wait ( clk ) @( negedge clk )
    s_sine_phase = add_phase;
    s_sine_dv = 1;
    wait ( clk ) @( negedge clk )
    s_sine_dv = 0;
    s_sine_phase = 0;
    wait( s_sine_dr );
    if ( !add_phase ) begin
        $display( "Radian = %08f, sine = %08f",  ( $signed( sine_d ) / FACTOR_1_0 ),
            ( $signed( m_sine_d ) / FACTOR_1_0 ));
    end
end
endtask

integer i;
/*============================================================================*/
initial begin : test
/*============================================================================*/
    rst_n = 0;
    s_sine_phase = 0;
    s_sine_dv = 0;
    #100
    $display( "Sine wave generator (3rd order interpolation) simulation started" );
    $display( "PI       %8x = %0d", swg_1.PI, swg_1.PI );
    $display( "CONV_PI  %8x = %0d", swg_1.CONV_PI, swg_1.CONV_PI );
    $display( "Sine table size   = %0d, bitwidth = %0d", swg_1.SINE_TBL_SIZE, swg_1.SINE_TBL_WIDTH );
    $display( "Sine_table[0]     = %0x", swg_1.sine_table[0] );
    $display( "Sine_table[1]     = %0x", swg_1.sine_table[1] );
    $display( "Sine_table[%0d]    = %0x", swg_1.SINE_TBL_SIZE-2, swg_1.sine_table[swg_1.SINE_TBL_SIZE-2] );
    $display( "Sine_table[%0d]    = %0x", swg_1.SINE_TBL_SIZE-1, swg_1.sine_table[swg_1.SINE_TBL_SIZE-1] );
    wait ( clk ) @( negedge clk );
    rst_n = 1;
    set_sine_rad(( PI + 1 ), 0 );     // Invalid input!
    set_sine_rad( -( PI + 1 ), 0 );
    set_sine_rad( PI, 0 );            // 180 degrees
    set_sine_rad( -PI, 0 );
    set_sine_rad(( PI * 5 / 6 ), 0 ); // 150 degrees
    set_sine_rad( -( PI * 5 / 6 ), 0 );
    set_sine_rad(( PI * 3 / 4 ), 0 ); // 135 degrees
    set_sine_rad( -( PI * 3 / 4 ), 0 );
    set_sine_rad(( PI / 2 ), 0 );     // 90 degrees
    set_sine_rad( -( PI / 2 ), 0 );
    set_sine_rad(( PI / 4 ), 0 );     // 45 degrees
    set_sine_rad( -( PI / 4 ), 0 );
    set_sine_rad(( PI / 6 ), 0 );     // 30 degrees
    set_sine_rad( -( PI / 6 ), 0 );
    set_sine_rad( 0, 0 );             // 0 degrees
    #100
    for ( i = 0; i < ( 2 * PHASE_STEP ); i = i + 1 ) begin
        set_sine_rad( ADD_PHASE, 1 );
    end
    $finish;
end // test

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "sine_wg_pol_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // sine_wg_pol_tb
