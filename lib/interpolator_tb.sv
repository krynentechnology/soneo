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
 *  Description: Interpolator module simulation
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module interpolator_tb;
/*============================================================================*/

localparam NR_CHANNELS = 3;
localparam INPUT_WIDTH = 24;
localparam FRACTION_WIDTH = 32;

localparam real SIGNAL_6DB = 2.0 ** ( INPUT_WIDTH - 2 ); // -6dB
localparam real FRACTION_1_0 = 2.0 ** ( FRACTION_WIDTH - 1 );
localparam INW = INPUT_WIDTH; // Input  width
localparam OUTW = INPUT_WIDTH; // Output width
localparam CHW = $clog2( NR_CHANNELS ); // Channel width
localparam CHN = NR_CHANNELS; // Number of channels
localparam CNTRW = FRACTION_WIDTH; // Fraction and counter width

reg clk = 0;
reg rst_n = 0; // Synchronous reset, high when clk is stable!

reg  [INW-1:0] s_intrp1_d = 0;
reg  s_intrp1_dv = 0;
wire s_intrp1_dr;
reg  [CNTRW-1:0] fraction1 = 0; // 1.CNTRW-1 fraction value
reg  [2:0] select1 = 0;
reg  [INW-1:0] s_signal1_d = SIGNAL_6DB;
reg  s_signal1_dv = 0;
wire s_signal1_dr;
wire [OUTW-1:0]  m_intrp1_d;
wire m_intrp1_dv;
reg  m_intrp1_dr = 1;
wire [OUTW-1:0] m_signal1_d;
wire m_signal1_dv;
reg  stop_attn1 = 0;
wire overflow1;

interpolator #(
    .POLYNOMIAL( "LINEAR" ),
    .NR_CHANNELS( 1 ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .FRACTION_WIDTH( FRACTION_WIDTH ),
    .ATTENUATION( 1 ))
intrp1(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp1_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp1_dv),
    .s_intrp_dr(s_intrp1_dr),
    .s_intrp_nchr(),
    .fraction(fraction1),
    .select(select1),
    .s_signal_d(s_signal1_d),
    .s_signal_dv(s_signal1_dv),
    .s_signal_dr(s_signal1_dr),
    .m_intrp_d(m_intrp1_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp1_dv),
    .m_intrp_dr(m_intrp1_dv & m_intrp1_dr),
    .m_signal_d(m_signal1_d),
    .m_signal_dv(m_signal1_dv),
    .stop_attn(stop_attn1),
    .overflow(overflow1));

reg  [INW-1:0] s_intrp2_d = 0;
reg  s_intrp2_dv = 0;
wire s_intrp2_dr;
reg  [CNTRW-1:0] fraction2; // 1.CNTRW-1 fraction value
reg  [2:0] select2 = 0;
wire [OUTW-1:0] m_intrp2_d;
wire m_intrp2_dv;
reg  m_intrp2_dr = 1;
wire overflow2;

interpolator #(
    .POLYNOMIAL( "2ND_ORDER" ),
    .NR_CHANNELS( 1 ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .FRACTION_WIDTH( FRACTION_WIDTH ),
    .ATTENUATION( 0 ))
intrp2(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp2_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp2_dv),
    .s_intrp_dr(s_intrp2_dr),
    .s_intrp_nchr(),
    .fraction(fraction2),
    .select(select2),
    .s_signal_d(),
    .s_signal_dv(1'b0),
    .s_signal_dr(),
    .m_intrp_d(m_intrp2_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp2_dv),
    .m_intrp_dr(m_intrp2_dr),
    .m_signal_d(),
    .m_signal_dv(),
    .stop_attn(1'b0),
    .overflow(overflow2));

wire [INW-1:0] s_intrp_d;  // Input for intrp3/4/5/6!
wire [CHW-1:0] s_intrp_ch; // Input for intrp3/4/5/6!
wire s_intrp_dv; // Input for intrp3/4/5/6!
wire s_intrp3_dr;
wire s_intrp3_nchr;
reg  [CNTRW-1:0] fraction = 0; // 1.CNTRW-1 fraction value
reg  [2:0] select = 0;
wire [OUTW-1:0] m_intrp3_d;
wire [CHW-1:0] m_intrp3_ch;
wire m_intrp3_dv;
reg  m_intrp3_dr = 0;
wire m_intrp_dr; // Input for intrp4/5/6!
wire overflow3;

interpolator #(
    .POLYNOMIAL( "3RD_ORDER" ),
    .NR_CHANNELS( NR_CHANNELS ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .FRACTION_WIDTH( FRACTION_WIDTH ),
    .ATTENUATION( 0 ))
intrp3(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(s_intrp_ch),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp3_dr),
    .s_intrp_nchr(s_intrp3_nchr),
    .fraction(fraction),
    .select(select),
    .s_signal_d(),
    .s_signal_dv(1'b0),
    .s_signal_dr(),
    .m_intrp_d(m_intrp3_d),
    .m_intrp_ch(m_intrp3_ch),
    .m_intrp_dv(m_intrp3_dv),
    .m_intrp_dr(m_intrp3_dr),
    .m_signal_d(),
    .m_signal_dv(),
    .stop_attn(1'b0),
    .overflow(overflow3));

wire s_intrp4_dr;
wire [OUTW-1:0] m_intrp4_d;
wire m_intrp4_dv;
wire overflow4;

interpolator #(
    .POLYNOMIAL( "3RD_ORDER" ),
    .NR_CHANNELS( 1 ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .FRACTION_WIDTH( FRACTION_WIDTH ),
    .ATTENUATION( 0 ))
intrp4(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp4_dr),
    .s_intrp_nchr(),
    .fraction(fraction),
    .select(select),
    .s_signal_d(),
    .s_signal_dv(1'b0),
    .s_signal_dr(),
    .m_intrp_d(m_intrp4_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp4_dv),
    .m_intrp_dr(m_intrp_dr),
    .m_signal_d(),
    .m_signal_dv(),
    .stop_attn(1'b0),
    .overflow(overflow4));

wire s_intrp5_dr;
wire [OUTW-1:0] m_intrp5_d;
wire m_intrp5_dv;
wire overflow5;

interpolator #(
    .POLYNOMIAL( "4TH_ORDER" ),
    .NR_CHANNELS( 1 ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .FRACTION_WIDTH( FRACTION_WIDTH ),
    .ATTENUATION( 0 ))
intrp5(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp5_dr),
    .s_intrp_nchr(),
    .fraction(fraction),
    .select(select),
    .s_signal_d(),
    .s_signal_dv(1'b0),
    .s_signal_dr(),
    .m_intrp_d(m_intrp5_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp5_dv),
    .m_intrp_dr(m_intrp_dr),
    .m_signal_d(),
    .m_signal_dv(),
    .stop_attn(1'b0),
    .overflow(overflow5));

wire s_intrp6_dr;
wire [OUTW-1:0] m_intrp6_d;
wire m_intrp6_dv;
wire overflow6;

interpolator #(
    .POLYNOMIAL( "5TH_ORDER" ),
    .NR_CHANNELS( 1 ),
    .INPUT_WIDTH( INPUT_WIDTH ),
    .FRACTION_WIDTH( FRACTION_WIDTH ),
    .ATTENUATION( 0 ))
intrp6(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp6_dr),
    .s_intrp_nchr(),
    .fraction(fraction),
    .select(select),
    .s_signal_d(),
    .s_signal_dv(1'b0),
    .s_signal_dr(),
    .m_intrp_d(m_intrp6_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp6_dv),
    .m_intrp_dr(m_intrp_dr),
    .m_signal_d(),
    .m_signal_dv(),
    .stop_attn(1'b0),
    .overflow(overflow6));

defparam intrp6.POLYNOMIAL = "5TH_ORDER";
defparam intrp6.NR_CHANNELS = 1;
defparam intrp6.INPUT_WIDTH = INPUT_WIDTH;
defparam intrp6.FRACTION_WIDTH = FRACTION_WIDTH;

always #5 clk = ~clk; // 100 MHz clock

// Same intrp4, intrp5 and intrp6 input needs output synchronization!
assign m_intrp_dr = m_intrp4_dv & m_intrp5_dv & m_intrp6_dv;

/*============================================================================*/
task setup_linear( input [INPUT_WIDTH-1:0] data,
                   input [CNTRW-1:0] fraction,
                   input [2:0] select );
/*============================================================================*/
begin
    wait( s_intrp1_dr );
    s_intrp1_d = data;
    fraction1 = fraction;
    select1 = select;
    wait ( clk ) @( negedge clk );
    s_intrp1_dv = 1;
    wait ( clk ) @( negedge clk );
    s_intrp1_dv = 0;
    wait( !s_intrp1_dr );
    m_intrp1_dr = 1;
    if (( fraction != 0 ) && ( 0 == select ) && intrp1.ATTENUATION ) begin
        // Interpolation with ATTENUATION starts!
        wait( s_intrp1_dr );
        wait( !s_intrp1_dr );
        wait( m_intrp1_dv );
        wait ( clk ) @( posedge clk );
        m_intrp1_dr = 0; // Discontinue attenuation
        wait( s_intrp1_dr );
    end
end
endtask // setup_linear

integer i;
/*============================================================================*/
task setup_linear_shapes;
/*============================================================================*/
begin
    s_signal1_dv = 1;
    // Triangle
    setup_linear( 0, 0, intrp1.STORE ); // n1 = 0
    for ( i = 0; i < 10; i = i + 1 ) begin
        setup_linear( SIGNAL_6DB, ( FRACTION_1_0 / 20.0 ), 0 );
        setup_linear( -SIGNAL_6DB, ( FRACTION_1_0 / 40.0 ), 0 );
        setup_linear( 0, ( FRACTION_1_0 / 20.0 ), 0 );
    end
    // Ramp down sawtooth
    for ( i = 0; i < 10; i = i + 1 ) begin
        setup_linear( SIGNAL_6DB, 0, intrp1.STORE );
        setup_linear( -SIGNAL_6DB, ( FRACTION_1_0 / 20.0 ), 0 );
    end
    setup_linear( 0, 0, intrp1.STORE ); // n1 = 0
    setup_linear( 0, ( FRACTION_1_0 / 20.0 ), 0 );
    // Ramp up sawtooth
    for ( i = 0; i < 10; i = i + 1 ) begin
        setup_linear( -SIGNAL_6DB, 0, intrp1.STORE );
        setup_linear( SIGNAL_6DB, ( FRACTION_1_0 / 20.0 ), 0 );
    end
    setup_linear( 0, 0, intrp1.STORE ); // n1 = 0
    setup_linear( 0, ( FRACTION_1_0 / 20.0 ), 0 );
    // Square
    for ( i = 0; i < 10; i = i + 1 ) begin
        setup_linear( SIGNAL_6DB, 0, intrp1.STORE );
        setup_linear( SIGNAL_6DB, ( FRACTION_1_0 / 20.0 ), 0 );
        setup_linear( -SIGNAL_6DB, 0, intrp1.STORE );
        setup_linear( -SIGNAL_6DB, ( FRACTION_1_0 / 20.0 ), 0 );
    end
    setup_linear( 0, 0, intrp1.STORE ); // n1 = 0
    setup_linear( 0, ( FRACTION_1_0 / 20.0 ), 0 );
    // Pulse
    for ( i = 0; i < 10; i = i + 1 ) begin
        setup_linear( SIGNAL_6DB, 0, intrp1.STORE );
        setup_linear( SIGNAL_6DB, ( FRACTION_1_0 / 2.0 ), 0 );
        setup_linear( 0, 0, intrp1.STORE ); // n1 = 0
        setup_linear( 0, ( FRACTION_1_0 / 20.0 ), 0 );
        setup_linear( -SIGNAL_6DB, 0, intrp1.STORE );
        setup_linear( -SIGNAL_6DB, ( FRACTION_1_0 / 2.0 ), 0 );
        setup_linear( 0, 0, intrp1.STORE ); // n1 = 0
        setup_linear( 0, ( FRACTION_1_0 / 20.0 ), 0 );
    end
    // Exponential
    setup_linear( SIGNAL_6DB, 0, intrp1.STORE ); // Set threshold
    setup_linear( 0, 0, intrp1.STORE ); // Set PO = 0
    setup_linear( 1000, ( FRACTION_1_0 * 1.01 ), intrp1.EXPONENTIAL ); // Set N1 start value
    // Interpolation with ATTENUATION starts!
    wait( s_intrp1_dr );
    wait( !s_intrp1_dr );
    #500 // Interpolation and attenuation continue while m_intrp1_dr = 1!
    wait( s_intrp1_dr );
    wait( !s_intrp1_dr );
    stop_attn1 = 1; // Stop attenuation
    wait( m_intrp1_dv );
    wait( s_intrp1_dr );
    stop_attn1 = 0;
end
endtask // setup_linear_shapes

/*============================================================================*/
task setup_quadratic( input [INPUT_WIDTH-1:0] data,
                      input [CNTRW-1:0] fraction,
                      input [0:0] store,
                      input [0:0] head );
/*============================================================================*/
begin
    wait( s_intrp2_dr );
    s_intrp2_d = data;
    fraction2 = fraction;
    select2 = {head, store};
    wait ( clk ) @( negedge clk );
    s_intrp2_dv = 1;
    wait ( clk ) @( negedge clk );
    s_intrp2_dv = 0;
    wait( !s_intrp2_dr );
end
endtask // setup_quadratic

integer j;
/*============================================================================*/
task setup_quadratic_shapes;
/*============================================================================*/
begin
    m_intrp2_dr = 1;
    // Circle
    setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
    for ( j = 0; j < 5; j = j + 1 ) begin
         // p1 = 0, p0 = 0/-SIGNAL_6DB, n1 = 0, n2 = SIGNAL_6DB
        setup_quadratic( SIGNAL_6DB, 0, 0, 0 );
         // p1 = 0, p0 = 0, n1 = SIGNAL_6DB, n2 = 0
        setup_quadratic( 0, ( FRACTION_1_0 / 20.0 ), 0, 1 ); // Select "head"
         // p1 = 0, p0 = SIGNAL_6DB, n1 = 0, n2 = -SIGNAL_6DB
        setup_quadratic( -SIGNAL_6DB, 0, 0, 0 );
         // p1 = SIGNAL_6DB, p0 = 0, n1 = -SIGNAL_6DB, n2 = 0
        setup_quadratic( 0, 0, 0, 1 ); // Select "head"
    end
    setup_quadratic( 0, 0, 0, 0 );
    setup_quadratic( 0, 0, 1, 0 );
    setup_quadratic( 0, 0, 0, 0 );
    wait( s_intrp2_dr );
    // Parabola
    for ( j = 0; j < 5; j = j + 1 ) begin
        setup_quadratic( SIGNAL_6DB, 0, 1, 0 ); // n2 = SIGNAL_6DB
         // p1 = 0, p0 = 0, n1 = SIGNAL_6DB, n2 = SIGNAL_6DB
        setup_quadratic( SIGNAL_6DB, ( FRACTION_1_0 / 20.0 ), 0, 1 ); // Select "head"
        setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
         // p1 = SIGNAL_6DB, p0 = SIGNAL_6DB, n1 = 0, n2 = 0,
        setup_quadratic( 0, 0, 0, 0 );
        setup_quadratic( -SIGNAL_6DB, 0, 1, 0 ); // n2 = -SIGNAL_6DB
         // p1 = SIGNAL_6DB, p0 = 0, n1 = -SIGNAL_6DB, n2 = -SIGNAL_6DB
        setup_quadratic( -SIGNAL_6DB, 0, 0, 1 ); // Select "head"
        setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
         // p1 = -SIGNAL_6DB, p0 = -SIGNAL_6DB, n1 = 0, n2 = 0
        setup_quadratic( 0, 0, 0, 0 );
    end
    setup_quadratic( 0, 0, 1, 0 );
    setup_quadratic( 0, 0, 1, 0 );
    setup_quadratic( 0, 0, 0, 0 );
    wait( s_intrp2_dr );
    // Circular spike
    for ( j = 0; j < 5; j = j + 1 ) begin
        setup_quadratic( SIGNAL_6DB, 0, 1, 0 ); // n2 = SIGNAL_6DB
        setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
        setup_quadratic( SIGNAL_6DB, 0, 1, 0 ); // n2 = SIGNAL_6DB
         // p1 = SIGNAL_6DB, p0 = 0, n1 = SIGNAL_6DB, n2 = 0
        setup_quadratic( 0, ( FRACTION_1_0 / 20.0 ), 0, 0 );
         // p1 = 0, p0 = SIGNAL_6DB, n1 = 0, n2 = SIGNAL_6DB
        setup_quadratic( SIGNAL_6DB, 0, 0, 1 ); // Select "head"
        setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
        setup_quadratic( -SIGNAL_6DB, 0, 1, 0 ); // n2 = -SIGNAL_6DB
        setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
        setup_quadratic( -SIGNAL_6DB, 0, 1, 0 ); // n2 = -SIGNAL_6DB
         // p1 = -SIGNAL_6DB, p0 = 0, n1 = -SIGNAL_6DB, n2 = 0
        setup_quadratic( 0, 0, 0, 0 );
        setup_quadratic( -SIGNAL_6DB, 0, 1, 0 ); // n2 = -SIGNAL_6DB
        setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
         // p1 = 0, p0 = -SIGNAL_6DB, n1 = 0, n2 = -SIGNAL_6DB
        setup_quadratic( -SIGNAL_6DB, 0, 0, 1 ); // Select "head"
        setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
    end
    setup_quadratic( 0, 0, 1, 0 );
    setup_quadratic( 0, 0, 1, 0 );
    setup_quadratic( 0, 0, 0, 0 );
    wait( s_intrp2_dr );
    // Parabolic spike
    setup_quadratic( 0, 0, 1, 0 ); // n2 = 0
    for ( j = 0; j < 5; j = j + 1 ) begin
        setup_quadratic( SIGNAL_6DB, 0, 1, 0 ); // n2 = SIGNAL_6DB
         // p1 = 0, p0 = 0/-SIGNAL_6DB, n1 = SIGNAL_6DB, n2 = 0
        setup_quadratic( 0, ( FRACTION_1_0 / 20.0 ), 0, 0 );
         // p1 = 0, p0 = SIGNAL_6DB, n1 = 0, n2 = 0
        setup_quadratic( 0, 0, 0, 1 ); // Select "head"
        setup_quadratic( -SIGNAL_6DB, 0, 1, 0 ); // n2 = -SIGNAL_6DB
         // p1 = 0, p0 = 0, n1 = -SIGNAL_6DB, n2 = 0
        setup_quadratic( 0, 0, 0, 0 );
         // p1 = 0, p0 = -SIGNAL_6DB, n1 = 0, n2 = 0
        setup_quadratic( 0, 0, 0, 1 ); // Select "head"
    end
    setup_quadratic( 0, 0, 1, 0 );
    setup_quadratic( 0, 0, 1, 0 );
    setup_quadratic( 0, 0, 0, 0 );
    wait( s_intrp2_dr );
end
endtask // setup_quadratic_shapes

reg sg_enabled = 0; // Sine generator
reg swg_enabled = 0; // Sweep generator
reg swg_dv = 0;
reg mute = 0;
reg pos_minus_6dB = 0; // To test continuous DC -6dB positive value
reg neg_minus_6dB = 0; // To test continuous DC -6dB negative value

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    s_intrp1_dv = 0;
    s_intrp2_dv = 0;
    m_intrp3_dr = 0;
    fraction1 = 0;
    fraction2 = 0;
    fraction = 0;
    select = 0;
    stop_attn1 = 0;
    sg_enabled = 0;
    swg_enabled = 0;
    mute = 0;
    pos_minus_6dB = 0;
    neg_minus_6dB = 0;
    #100 // 0.1us
    $display( "Interpolator simulation started" );
    wait ( clk ) @( negedge clk );
    $display( "Linear and quadratic shape generation" );
    rst_n = 1;
    fork // Parallel operation
        setup_linear_shapes;
        setup_quadratic_shapes;
    join
    select = intrp3.RESET;
    swg_dv = 1; // Use swg_dv for reset!
    wait ( clk ) @( negedge clk );
    select = 0;
    swg_dv = 0;
    wait ( clk ) @( negedge clk );
    #100 // 0.1us
    $display( "Sine generator enabled" );
    sg_enabled = 1;
    pos_minus_6dB = 1;
    m_intrp3_dr = 1;
    fraction[CNTRW-2] = 1; // fraction = 0.5
    wait ( s_intrp_dv );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    fraction[CNTRW-2] = 0;
    wait ( s_intrp_dv );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    pos_minus_6dB = 0;
    neg_minus_6dB = 1;
    wait ( s_intrp_dv );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    wait ( !s_intrp3_dr ) @( negedge s_intrp3_dr );
    neg_minus_6dB = 0;
    #100000 // 100us
    wait ( clk ) @( negedge clk );
    mute = 1;
    $display( "Mute" );
    #5000 // 5us
    wait ( clk ) @( negedge clk );
    m_intrp3_dr = 0;
    sg_enabled = 0;
    mute = 0;
    #100 // 0.1us
    select = intrp3.RESET;
    swg_dv = 1;
    wait ( clk ) @( negedge clk );
    select = 0;
    swg_dv = 0;
    wait ( clk ) @( negedge clk );
    #100 // 0.1us
    $display( "Sweep generator enabled" );
    swg_enabled = 1;
    fraction[CNTRW-2] = 1; // fraction = 0.5
    wait ( s_intrp_dv );
    wait ( !s_intrp_dv );
    fraction[CNTRW-2] = 0;
    #200000 // 200us
   $finish;
end

reg signed [INPUT_WIDTH-1:0] data_intrp_in_0 = 0;
reg signed [INPUT_WIDTH-1:0] data_intrp_in_1 = 0;
reg signed [INPUT_WIDTH-1:0] data_intrp_in_2 = 0;
reg signed [INPUT_WIDTH-1:0] data_intrp_out_0 = 0;
reg signed [INPUT_WIDTH-1:0] data_intrp_out_1 = 0;
reg signed [INPUT_WIDTH-1:0] data_intrp_out_2 = 0;

/*============================================================================*/
always @(posedge clk) begin : collect_intrp_data
/*============================================================================*/
    if ( s_intrp_dv ) begin
        if ( s_intrp3_dr && m_intrp3_dr ) begin
            case ( s_intrp_ch )
                0 : begin
                    data_intrp_in_0 <= s_intrp_d;
                end
                1 : begin
                    data_intrp_in_1 <= s_intrp_d;
                end
                2 : begin
                    data_intrp_in_2 <= s_intrp_d;
                end
            endcase
        end
    end
    if ( sg_enabled ) begin
        if ( m_intrp3_dv ) begin
            case ( m_intrp3_ch )
                0 : begin
                    data_intrp_out_0 <= m_intrp3_d;
                end
                1 : begin
                    data_intrp_out_1 <= m_intrp3_d;
                end
                2 : begin
                    data_intrp_out_2 <= m_intrp3_d;
                end
            endcase
        end
    end
    else if ( swg_enabled ) begin
        if ( s_intrp_dv ) begin
            data_intrp_in_2 <= s_intrp_d;
        end
        if ( m_intrp4_dv ) begin
            data_intrp_out_0 <= m_intrp4_d;
        end
        if ( m_intrp5_dv ) begin
            data_intrp_out_1 <= m_intrp5_d;
        end
        if ( m_intrp6_dv ) begin
            data_intrp_out_2 <= m_intrp6_d;
        end
    end
end

/////////////////// Sine generator for NR_CHANNELS channels ////////////////////
reg signed [INPUT_WIDTH-1:0] sg_d = 0;
reg signed [INPUT_WIDTH-1:0] sg_d_c;
reg [CHW-1:0] sg_ch = 0;
reg sg_dv = 0;

localparam real MATH_2_PI = 2 * 3.14159265358979323846;
localparam integer SAMPLE_FREQUENCY = 48000;
localparam real FACTOR_1 = ( 2.0 ** ( INPUT_WIDTH - 1 )) - 1;
real step[NR_CHANNELS-1:0];
real sine_counter[NR_CHANNELS-1:0];
/*============================================================================*/
initial begin
/*============================================================================*/
    step[0] = MATH_2_PI * 1000 / SAMPLE_FREQUENCY;
    step[1] = MATH_2_PI * 4000 / SAMPLE_FREQUENCY;
    step[2] = MATH_2_PI * 16000 / SAMPLE_FREQUENCY;
    sine_counter[0] = 0;
    sine_counter[1] = 0;
    sine_counter[2] = 0;
end

/*============================================================================*/
always @(posedge clk) begin : sine_generator
/*============================================================================*/
    if ( sg_enabled ) begin
        sg_dv <= 0;
        if ( s_intrp3_dr ) begin
            if ( pos_minus_6dB ) begin
                sg_d <= 0;
                sg_d[INPUT_WIDTH-1:INPUT_WIDTH-2] <= 2'b01;
            end
            else if ( neg_minus_6dB ) begin
                sg_d <= 0;
                sg_d[INPUT_WIDTH-1:INPUT_WIDTH-2] <= 3'b11;
            end
            else begin
                sg_d_c = FACTOR_1 * $sin( sine_counter[sg_ch] );
                sg_d <= sg_d_c;
                sine_counter[sg_ch] <= sine_counter[sg_ch] + step[sg_ch];
            end
            sg_dv <= 1;
        end
        if ( s_intrp3_nchr ) begin
            if (( NR_CHANNELS - 1 ) == sg_ch ) begin
                sg_ch <= 0;
            end else begin
                sg_ch <= sg_ch + 1;
            end
        end
    end
    if ( !rst_n || !sg_enabled ) begin
        sine_counter[0] <= 0;
        sine_counter[1] <= 0;
        sine_counter[2] <= 0;
        sg_d <= 0;
        sg_dv <= 0;
        sg_ch <= 0;
    end
end // sine_generator

/////////////////////////////// Sweep generator ////////////////////////////////
localparam real F_START = 10.0;
localparam real F_END = 24000.0;
localparam real F_INTERVAL = 0.5;
localparam NR_STEPS = 5000;
real swg_delta = 0;
real swg_t = 0;
real swg_phase = 0;
reg [$clog2( NR_STEPS )-1:0] swg_step = 0;
reg signed [INPUT_WIDTH-1:0] swg_d = 0;
reg signed [INPUT_WIDTH-1:0] swg_d_c;

/*============================================================================*/
always @(posedge clk) begin : sweep_generator
/*============================================================================*/
    if ( swg_enabled ) begin
        if ( swg_step < NR_STEPS ) begin
            swg_dv <= 0;
            if ( !swg_dv && s_intrp4_dr && s_intrp5_dr && s_intrp6_dr ) begin
                swg_delta = swg_step / $itor( NR_STEPS );
                swg_t = F_INTERVAL * swg_delta;
                swg_phase = MATH_2_PI * swg_t * ( F_START + (( F_END - F_START ) * swg_delta / 2 ));
                swg_d_c = FACTOR_1 * $sin( swg_phase );
                swg_d <= swg_d_c;
                swg_dv <= 1;
                swg_step <= swg_step + 1;
            end
        end
    end
    if ( !rst_n ) begin
        swg_step <= 0;
        swg_d <= 0;
        swg_dv <= 0;
    end
end // sweep_generator

assign s_intrp_d = ( sg_d | swg_d ) & { ( INPUT_WIDTH ){~mute}};
assign s_intrp_ch = sg_ch;
assign s_intrp_dv = sg_dv | ( swg_dv & s_intrp4_dr & s_intrp5_dr & s_intrp6_dr );

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "interpolator_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule // interpolator_tb
