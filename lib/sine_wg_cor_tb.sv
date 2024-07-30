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
 *  Sine wave generator (cordic) test bench
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module sine_wg_cor_tb;

parameter NR_CHANNELS = 3;
parameter CHANNEL_WIDTH = $clog2( NR_CHANNELS );
parameter RADIAN_WIDTH = 28;
parameter PRECISION = 25;

/*============================================================================*/
function real abs( input real value );
/*============================================================================*/
    begin
        abs = value;
        if ( value < 0.0  ) begin
            abs = -value;
        end
    end
endfunction

reg clk = 0;
reg rst_n = 0;

reg  [RADIAN_WIDTH-1:0] s_sine_d = 0;
reg  s_sine_zero = 0;
reg  [CHANNEL_WIDTH-1:0] s_sine_ch = 0;
reg  s_sine_dv = 0;
wire s_sine_dr;
wire [RADIAN_WIDTH-1:0] m_sine_d;
wire [RADIAN_WIDTH-1:0] m_cosine_d;
wire [CHANNEL_WIDTH-1:0] m_sine_ch;
wire m_sine_dv;
reg  m_sine_dr = 0;

sine_wg_cor swg_1(
    .clk(clk),
    .rst_n(rst_n),
    .s_sine_d(s_sine_d),
    .s_sine_zero(s_sine_zero),
    .s_sine_ch(s_sine_ch),
    .s_sine_dv(s_sine_dv),
    .s_sine_dr(s_sine_dr),
    .m_sine_d(m_sine_d),
    .m_cosine_d(m_cosine_d),
    .m_sine_ch(m_sine_ch),
    .m_sine_dv(m_sine_dv),
    .m_sine_dr(m_sine_dr)
    );

defparam swg_1.NR_CHANNELS = NR_CHANNELS;
defparam swg_1.RADIAN_WIDTH = RADIAN_WIDTH;
defparam swg_1.PRECISION = PRECISION;

localparam real MATH_PI = 3.141592653589793115997963;
localparam real FACTOR_1_0 = 2.0 ** ( RADIAN_WIDTH - 3 );
localparam signed [RADIAN_WIDTH-1:0] PI = FACTOR_1_0 * MATH_PI;
localparam PI_PHASE = 180; // Degrees
localparam real PHASE_STEP = FACTOR_1_0 * MATH_PI / PI_PHASE;
localparam signed [RADIAN_WIDTH-1:0] ADD_PHASE = PHASE_STEP;

// Generate clock 49.152MHz
always #( 20.345 / 2 ) clk = ~clk;

localparam US_10 = 10000;
localparam US_100 = 10 * US_10;
localparam MS_1 = 10 * US_100;
localparam MS_10 = 10 * MS_1;

reg [RADIAN_WIDTH-1:0] m_sine_d_out[0:NR_CHANNELS-1];
reg [RADIAN_WIDTH-1:0] angle = 0;
reg [RADIAN_WIDTH-1:0] sweep_angle = 0;
real angle_r = 0.0;
real angle_error = 0.0;
real max_angle_error = 0.0;

/*============================================================================*/
task set_sine_rad(
/*============================================================================*/
    input [RADIAN_WIDTH-1:0] sine_d,
    input [CHANNEL_WIDTH-1:0] sine_ch,
    input [0:0] phase_zero,
    input [0:0] display );
begin
    s_sine_d = sine_d;
    wait( s_sine_dr )
    wait ( clk ) @( negedge clk )
    s_sine_ch = sine_ch;
    s_sine_zero = phase_zero;
    s_sine_dv = 1;
    wait ( clk ) @( negedge clk )
    s_sine_dv = 0;
    s_sine_zero = 0;
    wait( s_sine_dr );
    m_sine_d_out[sine_ch] = m_sine_d;
    if ( display ) begin
        $display( "Angle = %12.9f, sine = %12.9f, cosine = %12.9f, quadrant = %1d",
            ( $signed( sine_d ) / FACTOR_1_0 ), ( $signed( m_sine_d ) / ( 2.0 * FACTOR_1_0 )),
            ( $signed( m_cosine_d ) / ( 2.0 * FACTOR_1_0 )), ( swg_1.quadrant + 1 ));
    end
end
endtask

reg [RADIAN_WIDTH-1:0] k_factor = 0;
integer i;
/*============================================================================*/
initial begin : test
/*============================================================================*/
    rst_n = 0;
    s_sine_zero = 0;
    s_sine_dv = 0;
    k_factor = swg_1.K_FACTOR;
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        m_sine_d_out[i] = 0;
    end
    #100
    $display( "Sine wave generator (CORDIC algorithm based) simulation started" );
    $display( "K_FACTOR %8x = %0d = %9.7f", k_factor, k_factor, ( swg_1.K_FACTOR / ( 2.0 * FACTOR_1_0 )));
    $display( "FACTOR_1 %8x = %0d", swg_1.FACTOR_1, swg_1.FACTOR_1 );
    $display( "2PI      %8x = %0d", swg_1.PI_X_2, swg_1.PI_X_2 );
    $display( "PI       %8x = %0d = %9.7f", swg_1.PI, swg_1.PI, ( swg_1.PI / FACTOR_1_0 ));
    $display( "PI/2     %8x = %0d", swg_1.PI_OVER_2, swg_1.PI_OVER_2 );
    wait ( clk ) @( negedge clk );
    rst_n = 1;
    set_sine_rad(( PI + 100 ), 0, 1, 1 );   // > 180 degrees!
    set_sine_rad( -( PI + 100 ), 0, 1, 1 );
    set_sine_rad( PI, 0, 1, 1 );            // 180 degrees
    set_sine_rad( -PI, 0, 1, 1 );
    set_sine_rad(( PI * 5 / 6 ), 0, 1, 1 ); // 150 degrees
    set_sine_rad( -( PI * 5 / 6 ), 0, 1, 1 );
    set_sine_rad(( PI * 3 / 4 ), 0, 1, 1 ); // 135 degrees
    set_sine_rad( -( PI * 3 / 4 ), 0, 1, 1 );
    set_sine_rad(( PI / 2 ), 0, 1, 1 );     // 90 degrees
    set_sine_rad( -( PI / 2 ), 0, 1, 1 );
    set_sine_rad(( PI / 4 ), 0, 1, 1 );     // 45 degrees
    set_sine_rad( -( PI / 4 ), 0, 1, 1 );
    set_sine_rad(( PI / 6 ), 0, 1, 1 );     // 30 degrees
    set_sine_rad( -( PI / 6 ), 0, 1, 1 );
    set_sine_rad( 0, 0, 1, 1 );             // 0 degrees
    #100
    for ( i = 0; i <= ( 2 * PI_PHASE ); i = i + 1 ) begin
        set_sine_rad( ADD_PHASE, 0, 0, 0 );
        angle_r = i * ( FACTOR_1_0 * MATH_PI / PI_PHASE );
        // Beware of s_sine_d overflow!!!
        if ( i >= PI_PHASE ) begin
            angle_r = ( FACTOR_1_0 * MATH_PI ) - angle_r;
        end
        angle = angle_r;
        set_sine_rad( angle, 1, 1, 0 );
        sweep_angle = angle >>> 1;
        set_sine_rad( sweep_angle, 2, 0, 0 );
        angle_error = $sin( angle_r / FACTOR_1_0 ) - ( $signed( m_sine_d_out[1] ) / ( 2.0 * FACTOR_1_0 ));
        if ( abs( angle_error ) > abs( max_angle_error )) begin
            max_angle_error = angle_error;
        end
    end
    $display( "Maximum sine error (0 - 360 degrees) = %12.9f", max_angle_error );
    $finish; 
end // test

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "sine_wg_cor_tb.vcd" );
    $dumpvars(0);
`endif
end

endmodule // sine_wg_cor_tb
