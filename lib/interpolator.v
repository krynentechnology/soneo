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
 *  Description:
 *
 *  The purpose of interpolation is to determine the amplitude y(x), for an
 *  arbitrary x, where x is a fraction between 0.0 and 1.0:
 *
 *       y(-2)        y(-1)       y(0)  y(x)  y(1)        y(2)
 *         |            |           |     |     |           |
 *     -- -2 --------- -1 --------- 0 --- x --- 1 --------- 2 -----> T (time)
 *         |            |           |           |           |
 *         p2           p1          p0          n1          n2
 *
 *  The samples being interpolated represent the wave amplitude at a particular
 *  instant of time, T - an impulse train. So each sample is the amplitude at
 *  T = ..., -2, -1, 0, 1, 2, ... etc.
 *
 *  Determination n-th order polynomial coefficients requires n+1 data points.
 *  When the polynomial coefficients are known y(x) can be calculated:
 *
 *    y(x) = ax3 + bx2 + cx + d   // 3rd order polynomial
 *    y(x) = x(x(ax + b) + c) + d
 *       x = -1, 0, 1, 2          // Determine coefficients by substitution
 *
 *    y(-1) -> p1 = -a + b - c + d            a = (-p1 + 3p0 - 3n1 + n2)/6
 *    y(0)  -> p0 = d                         b = (p1 - 2p0 + n1)/2
 *    y(1)  -> n1 = a + b + c + d             c = (-2p1 - 3p0 + 6n1 - n2)/6
 *    y(2)  -> n2 = 8a + 4b + 2c + d          d = p0
 *
 *  Interpolates between p0 and n1 taking the previous (p1) and next (n2) points
 *  into account:
 *
 *    float interpolate( float x, p1, p0, n1, n2 )
 *    {
 *        return ( // return y(x)
 *            p0 +                                          // d
 *            x * ((( -2p1 - 3p0 + 6n1 - n2 ) / 6 ) +       // c
 *              x * ((( p1 - 2p0 + n1 ) / 2 ) +             // b
 *                x * (( -p1 + 3p0 - 3n1 + n2 ) / 6 ) )));  // a
 *    }
 *
 *    2p0 = p0 << 1, 3p0 = 2p0 + p0, 6n1 = 3n1 << 1, /2 => >> 1
 *    /6 => * 1/6, division equals multiplication by fraction
 *
 *    y(x) = ax4 + bx3 + cx2 + dx + e     // 4th order polynomial
 *    y(x) = x(x(x(ax + b) + c) + d) + e
 *       x = -2, -1, 0, 1, 2              // Determine coefficients by substitution
 *
 *    y(-2) -> p2 = 16a - 8b + 4c - 2d + e    a = (p2 - 4p1 + 6p0 - 4n1 + n2)/24
 *    y(-1) -> p1 = a - b + c - d + e         b = (-p2 + 2p1 - 2n1 + n2)/12
 *    y(0)  -> p0 = e                         c = (-p2 + 16p1 - 30p0 + 16n1 - n2)/24
 *    y(1)  -> n1 = a + b + c + d + e         d = (p2 - 8p1 + 8n1 - n2)/12
 *    y(2)  -> n2 = 16a + 8b + 4c + 2d + e    e = p0
 *
 *  Interpolates between p0 and n1 taking the previous (p2, p1) and next (n2)
 *  points into account:
 *
 *    float interpolate( float x, p2, p1, p0, n1, n2 )
 *    {
 *        return ( // return y(x)
 *            p0 +                                                   // e
 *            x * ((( p2 - 8p1 + 8n1 - n2 ) / 12 ) +                 // d
 *              x * ((( -p2 + 16p1 - 30p0 + 16n1 - n2 ) / 24 ) +     // c
 *                x * ((( -p2 + 2p1 - 2n1 + n2 ) / 12 ) +            // b
 *                  x * (( p2 - 4p1 + 6p0 - 4n1 + n2 ) / 24 ) ))));  // a
 *    }
 *
 *    2p1 = p1 << 1, 8p1 = p1 << 3, 16p1 = 8p1 << 1, 30p0 = ( p0 << 5 ) - 2p0
 *    /12 => ( * 1/6 ) >> 1, /24 => ( * 1/6 ) >> 2
 *
 *  A 5th order polynomial interpolation, with four data points sampled, is
 *  based on publications by Joshua Scholar and Dave Waugh:
 *
 *    y(x) = ax5 + bx4 + cx3 + dx2 + ex + f  // 5th order polynomial
 *    y(x) = x(x(x(x(ax + b) + c) + d) + e) + f
 *
 *    float interpolate( float x, p1, p0, n1, n2 )
 *    {
 *        return ( // return y(x)
 *            p0 +                                                          // f
 *            .5f *
 *            x * ( n1 - p1 +                                               // e
 *              x * ( n1 + ( -2 * p0 ) + p1 +                               // d
 *                x * (( 9 * ( n1 - p0 )) + ( 3 * ( p1 - n2 )) +            // c
 *                  x * (( 15 * ( p0 - n1 )) + ( 5 * ( n2 - p1 )) +         // b
 *                    x * (( 6 * ( n1 - p0 )) + ( 2 * ( p1 - n2 ))) )))));  // a
 *    }
 *
 *    .5f *            => >> 1
 *    -2 * p0          => -p0 << 1
 *    9 * ( n1 - p0 )  => (( n1 - p0 ) << 3 ) + ( n1 - p0 )
 *    3 * ( p1 - n2 )  => ( -( n2 - p1 ) << 1 ) - ( n2 - p1 )
 *    15 * ( p0 - n1 ) => ( -( n1 - p0 ) << 4 ) + ( n1 - p0 )
 *    5 * ( n2 - p1 )  => (( n2 - p1 ) << 2 ) + ( n2 - p1 )
 *    6 * ( n1 - p0 )  => (( n1 - p0 ) << 2 ) + (( n1 - p0 ) << 1 )
 *    2 * ( p1 - n2 )  => -( n2 - p1 ) << 1
 *
 *  The data output is asynchronous due to multi channel processing. Synchronous
 *  data output would require data fifos for timing the output of every channel.
 *  When there is a single channel (NR_CHANNELS=1), the data output is semi-
 *  synchronous what helps the process visualization in graphical simulation
 *  display.
 **/

`resetall
`timescale 1ns / 1ps
`default_nettype none

module interpolator #(
    parameter POLYNOMIAL     = "3RD_ORDER", // "4TH_ORDER", "5TH_ORDER"
    parameter INPUT_WIDTH    = 24, // Input width
    parameter FRACTION_WIDTH = 32, // >= INPUT_WIDTH + 1
    parameter NR_CHANNELS    = 2 ) // Number of interpolation channels
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    s_intrp_d, s_intrp_ch, s_intrp_dv, s_intrp_dr, // _d = data, _ch = channel id
    fraction, // Fraction represents max. value 2.0 to allow down conversions
    m_intrp_d, m_intrp_ch, m_intrp_dv, m_intrp_dr, // _dv = data valid, _dr = data ready
    overflow
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

localparam INW   = INPUT_WIDTH; // Input  width
localparam OUTW  = INPUT_WIDTH; // Output width
localparam CHW   = clog2( NR_CHANNELS ); // Channel width
localparam CHN   = NR_CHANNELS; // Number of channels
localparam CNTRW = FRACTION_WIDTH; // Fraction and counter width

input  wire             clk;
input  wire             rst_n; // Synchronous reset, high when clk is stable!
input  wire [INW-1:0]   s_intrp_d;
input  wire [CHW-1:0]   s_intrp_ch;
input  wire             s_intrp_dv;
output wire             s_intrp_dr;
input  wire [CNTRW-1:0] fraction; // 1.CNTRW-1 fraction value
output wire [OUTW-1:0]  m_intrp_d;
output wire [CHW-1:0]   m_intrp_ch;
output wire             m_intrp_dv;
input  wire             m_intrp_dr;
output wire             overflow;
/**
 * The 1.CNTRW-1 fraction (step) value represents a maximum of 2. E.g. an input
 * sample rate of 48kHz could be converted down to 24kHz but not lower. Most
 * generally 48kHz audio could be converted down to 44.1kHz or 32kHz.
 **/
localparam real FACTOR_1 = 2.0 ** ( CNTRW - 1 ); // 1.0 == power 2 fraction width
localparam real ONE_SIXTH = ( FACTOR_1 / 6.0 ) + 0.5; // 1/6 factor
localparam real ONE_TWELFTH = ( FACTOR_1 / 12.0 ) + 0.5; // 1/12 factor
localparam real ONE_TWENTY_FOURTH = ( FACTOR_1 / 24.0 ) + 0.5; // 1/24 factor

// Parameter checks
/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( POLYNOMIAL != "3RD_ORDER" &&
         POLYNOMIAL != "4TH_ORDER" &&
         POLYNOMIAL != "5TH_ORDER" ) begin
        $display( "Select one of the interpolation implementations!" );
        $finish;
    end
    if ( NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )) begin
        $display( "NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )!" );
        $finish;
    end
    if (( INPUT_WIDTH + 1 ) > FRACTION_WIDTH ) begin
        $display( "( INPUT_WIDTH + 1 ) > FRACTION_WIDTH!" );
        $finish;
    end
end // param_check

reg  signed [INW-1:0] p2 [0:CHN-1];
wire signed [INW-1:0] p2_c;
reg  signed [INW-1:0] p1 [0:CHN-1];
wire signed [INW-1:0] p1_c;
reg  signed [INW-1:0] p0 [0:CHN-1];
wire signed [INW-1:0] p0_c;
reg  signed [INW-1:0] n1 [0:CHN-1];
wire signed [INW-1:0] n1_c;
reg  signed [INW-1:0] n2 [0:CHN-1];
wire signed [INW-1:0] n2_c;

// Boolean states
reg s0 = 0;
reg s0_i = 0;
reg s0_ii = 0;
reg yx = 0;
reg next_x = 0;

reg s_intrp_dr_i = 0;
reg [CHW-1:0] m_intrp_ch_i = 0;
reg m_intrp_dv_i = 0;
wire chs_intrp_dv; // Channel select valid
assign chs_intrp_dv = s_intrp_dv && s_intrp_dr_i && ( s_intrp_ch < NR_CHANNELS );

integer i = 0;
/*============================================================================*/
initial begin
/*============================================================================*/
    for ( i = 0; i < CHN; i = i + 1 ) begin // Initialize data memory
        p2[i] = 0;
        p1[i] = 0;
        p0[i] = 0;
        n1[i] = 0;
        n2[i] = 0;
    end
end

wire [CHW-1:0] intrp_ch;
assign intrp_ch = s_intrp_dr_i ? s_intrp_ch : m_intrp_ch_i;
assign p2_c = p2[ intrp_ch ];
assign p1_c = p1[ intrp_ch ];
assign p0_c = p0[ intrp_ch ];
assign n1_c = n1[ intrp_ch ];
assign n2_c = n2[ intrp_ch ];

/*============================================================================*/
always @(posedge clk) begin : fifo
/*============================================================================*/
    s_intrp_dr_i <= s_intrp_dr_i || next_x;
    if ( chs_intrp_dv ) begin
        s_intrp_dr_i <= 0;
        m_intrp_ch_i <= s_intrp_ch;
        { p2[ s_intrp_ch ], p1[ s_intrp_ch ], p0[ s_intrp_ch ], n1[ s_intrp_ch ], n2[ s_intrp_ch ] } <=
            { p1_c, p0_c, n1_c, n2_c, s_intrp_d };
    end
    if ( !rst_n ) begin
        s_intrp_dr_i <= 1;
    end
end // fifo
assign s_intrp_dr = s_intrp_dr_i;
assign m_intrp_ch = m_intrp_ch_i;

reg [CNTRW-1:0] step = 0;
reg [CNTRW:0] acc_fraction = 0;
wire [CNTRW:0] acc_fraction_c;
assign acc_fraction_c = acc_fraction + { 1'b0, step };
wire next_x_c;
assign next_x_c = |acc_fraction_c[CNTRW:CNTRW-1];
/*============================================================================*/
always @(posedge clk) begin : accumulate_fraction
/*============================================================================*/
    s0_i <= 0;
    s0_ii <= s0_i;
    s0 <= s0_ii; // Two clock cycles delay for same s0/yx timing as input
    next_x <= 0;
    if ( chs_intrp_dv ) begin
        s0 <= ~next_x_c;
        if ( fraction != 0 ) begin // Ignore fraction when zero!
            step <= fraction;
            acc_fraction <= { 2'b00, fraction[CNTRW-2:0] };
            next_x <= fraction[CNTRW-1];
            // No need to start when fraction >= 1, but fraction is stored for next iteration!
            s0 <= ~fraction[CNTRW-1];
        end
        else if ( 0 == step ) begin
            s0 <= 0; // Fraction step has no value yet!
            next_x <= 1;
        end
    end
    if ( yx ) begin
        acc_fraction <= acc_fraction_c;
        // Skip y(x) calculation when acc_fraction >= 1
        s0_i <= ~next_x_c;
        next_x <= next_x_c;
        if ( next_x_c ) begin
            acc_fraction[CNTRW:CNTRW-1] <= 0;
        end
    end
    if ( !rst_n ) begin
        s0 <= 0;
        next_x <= 0;
        step <= 0;
        acc_fraction <= 0;
    end
end // accumulate_fraction

localparam ASW = INW+6; // Reserved width for add and subtract
wire signed [ASW-1:0] p0_x_2;
wire signed [ASW-1:0] p0_x_3;
wire signed [ASW-1:0] p0_x_6;
wire signed [ASW-1:0] p1_plus_n1__x_4;
wire signed [ASW-1:0] p1_minus_n1__x_2;
wire signed [ASW-1:0] n1_x_3;
wire signed [ASW-1:0] n1_x_6;
wire signed [ASW-1:0] n1_minus_p0;
wire signed [ASW-1:0] n1_minus_p0__x_6;
wire signed [ASW-1:0] n1_minus_p0__x_9;
wire signed [ASW-1:0] p0_minus_n1__x_15;
wire signed [ASW-1:0] n2_minus_p1;
wire signed [ASW-1:0] p1_minus_n2__x_2;
wire signed [ASW-1:0] p1_minus_n2__x_3;
wire signed [ASW-1:0] n2_minus_p1__x_5;
reg signed  [ASW-1:0] a = 0;
reg signed  [ASW-1:0] a_x_6 = 0;
reg signed  [ASW-1:0] a_x_24 = 0;
reg signed  [ASW-1:0] b = 0;
reg signed  [ASW-1:0] b_x_12 = 0;
reg signed  [ASW-1:0] c = 0;
reg signed  [ASW-1:0] c_x_6 = 0;
reg signed  [ASW-1:0] c_x_24 = 0;
reg signed  [ASW-1:0] d = 0;
reg signed  [ASW-1:0] d_x_12 = 0;
reg signed  [ASW-1:0] e = 0;
reg signed  [ASW-1:0] d3rd_e4th_f5th = 0;

assign p0_x_2 = p0_c << 1;
assign p0_x_3 = p0_x_2 + p0_c;
assign p0_x_6 = p0_x_3 << 1;
assign n1_x_3 = ( n1_c << 1 ) + n1_c;
assign n1_x_6 = n1_x_3 << 1;
assign p1_plus_n1__x_4 = ( p1_c + n1_c ) << 2;
assign p1_minus_n1__x_2 = ( p1_c - n1_c ) << 1;
assign n1_minus_p0 = n1_c - p0_c;
assign n1_minus_p0__x_6 = ( n1_minus_p0 << 2 ) + ( n1_minus_p0 << 1 );
assign n1_minus_p0__x_9 = ( n1_minus_p0 << 3 ) + n1_minus_p0;
assign p0_minus_n1__x_15 = -( n1_minus_p0 << 4 ) + n1_minus_p0;
assign n2_minus_p1 = n2_c - p1_c;
assign p1_minus_n2__x_2 = -( n2_minus_p1 << 1 );
assign p1_minus_n2__x_3 = p1_minus_n2__x_2 -  n2_minus_p1;
assign n2_minus_p1__x_5 = ( n2_minus_p1 << 2 ) + n2_minus_p1;

localparam PW = CNTRW + ASW;

reg signed [CNTRW-1:0] p_arg_1; // x0_1 or division fraction (sign=0)
reg signed [ASW-1:0] p_arg_2;
reg signed [PW-1:0] product_c;
/*============================================================================*/
always @(*) begin : multiplication_and_calc_coeff
/*============================================================================*/
    product_c = ( p_arg_1 * p_arg_2 ) + // Round to zero (for negative values)!
        $signed( {{( ASW + 1 ){1'b0}}, {( CNTRW - 1 ){p_arg_2[ASW-1]}}} );
    if ( POLYNOMIAL == "3RD_ORDER" ) begin // Conditional synthesis!
        // 6a = -p1 + 3p0 - 3n1 + n2
        a_x_6 = -p1_c + p0_x_3 - n1_x_3 + n2_c;
        // 2b = p1 - 2p0 + n1
        b     = ( p1_c - p0_x_2 + n1_c ) >>> 1; // Sign extension shift!
        // 6c = -2p1 - 3p0 + 6n1 - n2
        c_x_6 = -( p1_c << 1 ) - p0_x_3 + n1_x_6 - n2_c;
    end
    if ( POLYNOMIAL == "4TH_ORDER" ) begin // Conditional synthesis!
        // 24a = p2 - 4p1 + 6p0 - 4n1 + n2
        a_x_24 = p2_c - p1_plus_n1__x_4 + p0_x_6 + n2_c;
        // 12b = -p2 + 2p1 - 2n1 + n2
        b_x_12 = -p2_c + p1_minus_n1__x_2 + n2_c;
        // 24c = -p2 + 16p1 - 30p0 + 16n1 - n2
        c_x_24 = -p2_c + ( p1_plus_n1__x_4 << 2 ) - (( p0_c << 5 ) - p0_x_2 ) - n2_c;
        // 12d = p2 - 8p1 + 8n1 - n2
        d_x_12 = p2_c - ( p1_minus_n1__x_2 << 2 ) - n2_c;
    end
    if ( POLYNOMIAL == "5TH_ORDER" ) begin // Conditional synthesis!
        // a = ( 6 * ( n1 - p0 )) + ( 2 * ( p1 - n2 ))
        a = n1_minus_p0__x_6 + p1_minus_n1__x_2;
        // b = ( 15 * ( p0 - n1 )) + ( 5 * ( n2 - p1 ))
        b = p0_minus_n1__x_15 + n2_minus_p1__x_5;
        // c = ( 9 * ( n1 - p0 )) + ( 3 * ( p1 - n2 ))
        c = n1_minus_p0__x_9 + p1_minus_n2__x_3;
        // d = n1 + ( -2 * p0 ) + p1
        d = n1_c - p0_x_2 + p1_c;
        // e = n1 - p1
        e = n1_c - p1_c;
    end
    d3rd_e4th_f5th = {{ ( ASW - INW ){p0_c[INW-1]}}, p0_c};
end // multiplication_and_calc_coeff

// Boolean states
reg ax_x_6 = 0;
reg ax_x_24 = 0;
reg ax = 0;
reg ax_plus_b = 0;
reg ax_plus_b_x_24 = 0;
reg axx_bx_c = 0;
reg axxx_bxx_cx_d = 0;
reg axxxx_bxxx_cxx_dx_e = 0;
reg cx = 0;
reg cx_plus_d_x_24 = 0;
reg axx_plus_bx = 0;
reg cxx_plus_dx = 0;
reg axxx_plus_bxx = 0;
reg axxxx_plus_bxxx = 0;
reg signed [ASW-1:0] ax_plus_b_r = 0;
reg signed [ASW-1:0] cx_plus_d_r = 0;
reg signed [ASW-1:0] cxx_plus_dx_plus_e_r = 0;

localparam [INW-2:0] ALL_ZERO = 0; // 00000...
localparam [INW-2:0] ALL_ONES = -1; // 11111...

wire signed [CNTRW-1:0] x0_1;
assign x0_1 = { 1'b0, acc_fraction[CNTRW-2:0] };

wire signed [ASW-1:0] yx_i;
assign yx_i = product_c[PW-2:CNTRW-1] +
    (( POLYNOMIAL == "3RD_ORDER" ) ? cx_plus_d_r :
        (( POLYNOMIAL == "4TH_ORDER" ) ? cxx_plus_dx_plus_e_r : d3rd_e4th_f5th )); // 5TH_ORDER
wire overflow_xy_i_p; // Positive values
assign overflow_xy_i_p = !yx_i[ASW-1] && |yx_i[ASW-2:INW-1];
wire overflow_xy_i_n; // Negative values
assign overflow_xy_i_n = yx_i[ASW-1] && !( &yx_i[ASW-2:INW-1] );
// Output overflow
assign overflow = yx && ( overflow_xy_i_p | overflow_xy_i_n );
// Overflow flags for test purposes
wire overflow_ax_plus_b_r;
assign overflow_ax_plus_b_r =
    ( !ax_plus_b_r[ASW-1] && |ax_plus_b_r[ASW-2:INW-1] ) |
    ( ax_plus_b_r[ASW-1] && !( &ax_plus_b_r[ASW-2:INW-1] ));
wire overflow_cx_plus_d_r;
assign overflow_cx_plus_d_r =
    ( !cx_plus_d_r[ASW-1] && |cx_plus_d_r[ASW-2:INW-1] ) |
    ( cx_plus_d_r[ASW-1] && !( &cx_plus_d_r[ASW-2:INW-1] ));

reg signed [OUTW-1:0] m_intrp_d_i = 0;
/*============================================================================*/
always @(posedge clk) begin : calc_y
/*============================================================================*/
    m_intrp_dv_i <= m_intrp_dv_i & !m_intrp_dr;
    if ( POLYNOMIAL == "3RD_ORDER" ) begin // Conditional synthesis!
        // y(x)  = x(x(ax + b) + c) + d
        ax_x_6 <= s0;
        if ( ax_x_6 ) begin
            p_arg_1 <= x0_1;
            p_arg_2 <= a_x_6;
        end
        ax <= ax_x_6;
        if ( ax ) begin
            p_arg_1 <= ONE_SIXTH;
            p_arg_2 <= product_c[PW-2:CNTRW-1];
        end
        ax_plus_b <= ax;
        if ( ax_plus_b ) begin
            p_arg_1 <= x0_1;
            p_arg_2 <= c_x_6;
            ax_plus_b_r <= product_c[PW-2:CNTRW-1] + b;
        end
        cx <= ax_plus_b;
        if ( cx ) begin
            p_arg_1 <= ONE_SIXTH;
            p_arg_2 <= product_c[PW-2:CNTRW-1];
        end
        axx_plus_bx <= cx;
        if ( axx_plus_bx ) begin
            p_arg_1 <= x0_1;
            p_arg_2 <= ax_plus_b_r;
            cx_plus_d_r <= product_c[PW-2:CNTRW-1] + d3rd_e4th_f5th;
        end
        axxx_plus_bxx <= axx_plus_bx;
        if ( axxx_plus_bxx ) begin
            // p_arg_1 <= x0_1;
            p_arg_2 <= product_c[PW-2:CNTRW-1];
        end
        yx <= axxx_plus_bxx;
    end
    if ( POLYNOMIAL == "4TH_ORDER" ) begin // Conditional synthesis!
        // y(x) = x(x(x(ax + b) + c) + d) + e
        ax_x_24 <= s0;
        if ( ax_x_24) begin
            p_arg_1 <= x0_1;
            p_arg_2 <= a_x_24;
        end
        ax_plus_b_x_24 <= ax_x_24;
        if ( ax_plus_b_x_24 ) begin
            p_arg_1 <= ONE_TWENTY_FOURTH;
            p_arg_2 <= product_c[PW-2:CNTRW-1] + ( b_x_12 << 1 );
        end
        ax_plus_b <= ax_plus_b_x_24;
        if ( ax_plus_b ) begin
            p_arg_1 <= x0_1;
            p_arg_2 <= c_x_24;
            ax_plus_b_r <= product_c[PW-2:CNTRW-1];
        end
        cx_plus_d_x_24 <= ax_plus_b;
        if ( cx_plus_d_x_24 ) begin
            p_arg_1 <= ONE_TWENTY_FOURTH;
            p_arg_2 <= product_c[PW-2:CNTRW-1] + ( d_x_12 << 1 );
        end
        cxx_plus_dx <= cx_plus_d_x_24;
        if ( cxx_plus_dx ) begin
            p_arg_1 <= x0_1;
            p_arg_2 <= product_c[PW-2:CNTRW-1];
        end
        axx_plus_bx <= cxx_plus_dx;
        if ( axx_plus_bx ) begin
            // p_arg_1 <= x0_1;
            p_arg_2 <= ax_plus_b_r;
            cxx_plus_dx_plus_e_r <= product_c[PW-2:CNTRW-1] + d3rd_e4th_f5th;
        end
        axxx_plus_bxx <= axx_plus_bx;
        if ( axxx_plus_bxx ) begin
            // p_arg_1 <= x0_1;
            p_arg_2 <= product_c[PW-2:CNTRW-1];
        end
        axxxx_plus_bxxx <= axxx_plus_bxx;
        if ( axxxx_plus_bxxx ) begin
            // p_arg_1 <= x0_1;
            p_arg_2 <= product_c[PW-2:CNTRW-1];
        end
        yx <= axxxx_plus_bxxx;
    end
    if ( POLYNOMIAL == "5TH_ORDER" ) begin // Conditional synthesis!
        // y(x) = ax5 + bx4 + cx3 + dx2 + ex + f  // 5th order polynomial
        ax <= s0;
        if ( ax ) begin
            p_arg_1 <= x0_1;
            p_arg_2 <= a;
        end
        ax_plus_b <= ax;
        if ( ax_plus_b ) begin
            // p_arg_1 <= x0_1;
            p_arg_2 <= product_c[PW-2:CNTRW-1] + b;
        end
        axx_bx_c <= ax_plus_b;
        if ( axx_bx_c ) begin
            // p_arg_1 <= x0_1;
            p_arg_2 <= product_c[PW-2:CNTRW-1] + c;
        end
        axxx_bxx_cx_d <= axx_bx_c;
        if ( axxx_bxx_cx_d ) begin
            // p_arg_1 <= x0_1;
            p_arg_2 <= product_c[PW-2:CNTRW-1] + d;
        end
        axxxx_bxxx_cxx_dx_e <= axxx_bxx_cx_d;
        if ( axxxx_bxxx_cxx_dx_e ) begin
            p_arg_1 <= x0_1 >>> 1; // 0.5f
            p_arg_2 <= product_c[PW-2:CNTRW-1] + e;
        end
        yx <= axxxx_bxxx_cxx_dx_e;
    end
    if ( yx ) begin
        m_intrp_d_i[OUTW-1] <= yx_i[ASW-1]; // Assign sign
        m_intrp_d_i[OUTW-2:0] <= yx_i[INW-2:0];
        // Check for overflow!
        if ( overflow_xy_i_p ) begin
            m_intrp_d_i[OUTW-2:0] <= ALL_ONES;
        end
        if ( overflow_xy_i_n ) begin
            m_intrp_d_i[OUTW-2:0] <= ALL_ZERO;
        end
        m_intrp_dv_i <= 1;
    end
    if ( !rst_n ) begin
        ax <= 0;
        ax_x_6 <= 0;
        ax_x_24 <= 0;
        ax_plus_b <= 0;
        axx_plus_bx <= 0;
        axx_bx_c <= 0;
        axxx_bxx_cx_d <= 0;
        axxx_plus_bxx <= 0;
        axxxx_plus_bxxx <= 0;
        axxxx_bxxx_cxx_dx_e <= 0;
        ax_plus_b_x_24 <= 0;
        cx <= 0;
        cx_plus_d_x_24 <= 0;
        cxx_plus_dx <= 0;
        yx <= 0;
        ax_plus_b_r <= 0;
        cx_plus_d_r <= 0;
        cxx_plus_dx_plus_e_r <= 0;
        m_intrp_d_i <= 0;
        m_intrp_dv_i <= 0;
    end
end // calc_y
assign m_intrp_d = m_intrp_d_i;
assign m_intrp_dv = m_intrp_dv_i;

endmodule
