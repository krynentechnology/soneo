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
 *  Sine wave generator. Based on sine lookup table and 3rd order interpolation.
 *  Input radian values > ABS(PI) for s_sine_d are invalid and ignored for sine
 *  wave generation!
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module sine_wg_pol #(
/*============================================================================*/
    parameter NR_CHANNELS = 2,
    parameter RADIAN_WIDTH = 24 )
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    s_sine_d, // Signed radian (-PI, +PI), S2.(RADIAN_WIDTH-3) fraction!
    s_sine_phase, // Phase addition flag, 2.0^(RADIAN_WIDTH-3) == 1.0!
    s_sine_ch, // _ch = channel for sine wave generation
    s_sine_dv, // _dv = data valid
    s_sine_dr, // _dr = data ready
    m_sine_d, // (-1.0, +1.0), S1.(RADIAN_WIDTH-2) fraction!
    m_sine_ch, // output sine wave channel
    m_sine_dv,
    m_sine_dr
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

localparam CHANNEL_WIDTH = clog2( NR_CHANNELS );

input wire  clk;
input wire  rst_n;
input wire  [RADIAN_WIDTH-1:0] s_sine_d;
input wire  s_sine_phase;
input wire  [CHANNEL_WIDTH-1:0] s_sine_ch;
input wire  s_sine_dv;
output reg  s_sine_dr = 1;
output wire [RADIAN_WIDTH-1:0] m_sine_d;
output wire [CHANNEL_WIDTH-1:0] m_sine_ch;
output wire m_sine_dv;
input wire  m_sine_dr;

localparam NOISE_BITS = 2;
localparam AW = RADIAN_WIDTH + NOISE_BITS; // Product 1x2 argument width

/*============================================================================*/
function signed [AW:0] abs( input signed [AW:0] value );
/*============================================================================*/
    begin
        abs = value;
        if ( value[AW] ) begin
            abs = -value;
        end
    end
endfunction
/*
 *  The purpose of interpolation is to determine the amplitude y(x), for an
 *  arbitrary x, where x is a fraction between 0.0 and 1.0:
 *
 *          y(-1)       y(0)  y(x)  y(1)        y(2)
 *            |           |     |     |           |
 *     ----- -1 --------- 0 --- x --- 1 --------- 2 -----> T (time)
 *            |           |           |           |
 *            p1          p0          n1          n2
 *
 *  The samples being interpolated represent the wave amplitude at a particular
 *  instant of time, T - an impulse train. So each sample is the amplitude at
 *  T = ..., -1, 0, 1, 2, ... etc.
 *
 *  Determination n-th order polynomial coefficients requires n+1 data points.
 *  When the polynomial coefficients are known y(x) can be calculated:
 *
 *    y(x)  = ax3 + bx2 + cx + d   // 3rd order polynomial
 *    y(x)  = x(x(ax + b) + c) + d
 *       x = -1, 0, 1, 2           // Determine coefficients by substitution
 *
 *    y(-1) -> p1 = -a + b - c + d             a = (-p1 + 3p0 - 3n1 + n2)/6
 *    y(0)  -> p0 = d                          b = (p1 - 2p0 + n1)/2
 *    y(1)  -> n1 = a + b + c + d              c = (-2p1 - 3p0 + 6n1 - n2)/6
 *    y(2)  -> n2 = 8a + 4b + 2c + d           d = p0
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
 */

localparam SINE_TBL_SIZE = 64;
localparam SINE_TBL_WIDTH = clog2( SINE_TBL_SIZE );
localparam real FACTOR_1_0 = 2.0 ** ( AW - 3 );
localparam [AW-1:0] FACTOR_1 = FACTOR_1_0;

/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( RADIAN_WIDTH < ( SINE_TBL_WIDTH + 3 )) begin
        $display( "RADIAN_WIDTH < ( SINE_TBL_WIDTH + 3 )!" );
        $finish;
    end
    if (( 2 ** SINE_TBL_WIDTH ) != SINE_TBL_SIZE ) begin
        $display( "SINE_TBL_SIZE should be a power of 2!" );
        $finish;
    end
    if ( FACTOR_1 != FACTOR_1_0 ) begin
        $display( "FACTOR_1 != FACTOR_1_0!" );
        $finish;
    end
end // param_check

reg  [AW-4:0] sine_table[0:SINE_TBL_SIZE-1];
reg [SINE_TBL_WIDTH-1:0] p0;
wire signed [AW-1:0] p0_c;
wire signed [AW-1:0] p1_c;
wire signed [AW-1:0] n1_c;
wire signed [AW-1:0] n2_c;

assign p1_c = ( 0 == p0 ) ? -$signed( {3'h0, sine_table[1]} ) :
    { 3'h0, sine_table[( p0 - 1 )]};
assign p0_c = { 3'h0, sine_table[ p0 ]};
assign n1_c = (( SINE_TBL_SIZE - 1 ) == p0 ) ?
    FACTOR_1 : {3'h0, sine_table[( p0 + 1 )]};
assign n2_c = (( SINE_TBL_SIZE - 1 ) == p0 ) ?
    {3'h0, sine_table[( SINE_TBL_SIZE - 1 )]} : (( SINE_TBL_SIZE - 2 ) == p0 ) ?
        FACTOR_1 : {3'h0, sine_table[( p0 + 2 )]};

wire signed [AW-1:0] p0_x_2;
wire signed [AW-1:0] p0_x_3;
wire signed [AW-1:0] n1_x_3;
wire signed [AW-1:0] n1_x_6;
reg signed [AW-1:0] a_x_6;
reg signed [AW-1:0] b;
reg signed [AW-1:0] c_x_6;
reg signed [AW-1:0] d;
reg signed [AW-1:0] ax_plus_b_r = 0;
reg signed [AW-1:0] cx_plus_d_r = 0;

assign p0_x_2 = p0_c << 1;
assign p0_x_3 = p0_x_2 + p0_c;
assign n1_x_3 = ( n1_c << 1 ) + n1_c;
assign n1_x_6 = n1_x_3 << 1;

localparam [RADIAN_WIDTH-2:0] ALL_ZERO = 0; // 00000...
localparam [RADIAN_WIDTH-2:0] ALL_ONES = -1; // 11111...
localparam PW = 2 * AW;

reg signed [AW-1:0] p_arg_1;
reg signed [AW-1:0] p_arg_2;
reg signed [PW-1:0] product_c;
wire overflow_p; // Positive values
assign overflow_p = !product_c[PW-1] && |product_c[PW-2:PW-4];
wire overflow_n; // Negative values
assign overflow_n = product_c[PW-1] && !( &product_c[PW-2:PW-4] );
wire signed [SINE_TBL_WIDTH+1:0] p0_pre;
assign p0_pre = {product_c[PW-1], product_c[PW-5:PW-SINE_TBL_WIDTH-5]};
wire signed [AW-1:0] yx_i;
assign yx_i = product_c[PW-2:AW-1] + cx_plus_d_r;

localparam real MATH_PI = 3.141592653589793115997963;
localparam real ONE_SIXTH = ( FACTOR_1_0 / 6.0 ) + 0.5; // 1/6 factor
localparam signed [AW-1:0] PI = FACTOR_1_0 * MATH_PI;
localparam [AW-1:0] CONV_PI = ( 4.0 * FACTOR_1_0 / MATH_PI ) - 1;

/*============================================================================*/
always @(*) begin : multiplication_and_calc_coeff
/*============================================================================*/
    product_c = ( p_arg_1 * p_arg_2 ) + $signed( {{( AW + 1 ){1'b0}},
        // Round to zero (for negative product values)!
        {( AW - 1 ){p_arg_1[AW-1] ^ p_arg_2[AW-1]}}} );
    // 6a = -p1 + 3p0 - 3n1 + n2
    a_x_6 = -p1_c + p0_x_3 - n1_x_3 + n2_c;
    // 2b = p1 - 2p0 + n1
    b     = ( p1_c - p0_x_2 + n1_c ) >>> 1; // Sign extension shift!
    // 6c = -2p1 - 3p0 + 6n1 - n2
    c_x_6 = -( p1_c << 1 ) - p0_x_3 + n1_x_6 - n2_c;
    d     = {{ ( AW ){p0_c[AW-1]}}, p0_c};
end // multiplication_and_calc_coeff

// Boolean states
reg set_p_arg_2 = 0;
reg set_p0 = 0;
reg set_p1n1n2 = 0;
reg ax = 0;
reg ax_x_6 = 0;
reg ax_plus_b = 0;
reg axx_plus_bx = 0;
reg axxx_plus_bxx = 0;
reg cx = 0;
reg yx = 0;

reg [RADIAN_WIDTH-1:0] m_sine_d_i = 0;
reg [CHANNEL_WIDTH-1:0] m_sine_ch_i = 0;
reg m_sine_dv_i = 0;

reg  [CHANNEL_WIDTH-1:0] sine_ch_i = 0;
wire [CHANNEL_WIDTH-1:0] sine_ch_c = 0;
reg signed [AW-1:0] sine[0:NR_CHANNELS-1];

wire signed [AW-1:0] sine_c;
wire signed [AW-1:0] abs_sine_d;
wire signed [AW-1:0] abs_sine_c;
wire signed [AW:0]next_sine_c;
wire signed [AW:0]surplus_next_sine_c;
wire signed next_sine_gt_pi;
wire sine_valid;

assign sine_ch_c = s_sine_dv ? s_sine_ch : sine_ch_i;
assign sine_c = sine[sine_ch_c];
assign abs_sine_d = abs( {s_sine_d[RADIAN_WIDTH-1], s_sine_d, {(NOISE_BITS){1'b0}}} );
assign abs_sine_c = abs( {sine_c[AW-1], sine_c} );
assign next_sine_c = sine_c + $signed( {s_sine_d, {(NOISE_BITS){1'b0}}} );
assign next_sine_gt_pi = abs( next_sine_c ) > {1'b0, PI};
assign surplus_next_sine_c = next_sine_c + ( next_sine_c[AW] ? { 1'b0, PI } : { 1'b1, -PI } );
assign sine_valid = abs_sine_d <= {1'b0, PI};

/*============================================================================*/
always @(posedge clk) begin : sine_wg_polerator
/*============================================================================*/
    m_sine_dv_i <= m_sine_dv_i & ~m_sine_dr;
    set_p_arg_2 <= 0; // Pulse
    if ( s_sine_dv && s_sine_dr ) begin
        sine_ch_i <= s_sine_ch;
        if ( sine_valid ) begin
            s_sine_dr <= 0;
            p_arg_1 <= CONV_PI;
            sine[sine_ch_c] <= {s_sine_d, {(NOISE_BITS){1'b0}}};
            if ( s_sine_phase ) begin
                sine[sine_ch_c] <= next_sine_c;
                if ( next_sine_gt_pi ) begin
                    sine[sine_ch_c] <= surplus_next_sine_c[AW-1:0] + // Correction +/- PI radian
                        ( next_sine_c[AW] ? $signed( PI ) : // Negative next_sine_c!
                            $signed( -PI )); // Positive next_sine_c!
                end
            end
            set_p_arg_2 <= 1;
        end
    end
    set_p0 <= set_p_arg_2;
    if ( set_p_arg_2 ) begin
        // p_arg_1 <= CONV_PI;
        p_arg_2 <= sine_c;
    end
    set_p1n1n2 <= set_p0; // Extra clock cycle!
    if ( set_p0 ) begin
        if ( !p0_pre[SINE_TBL_WIDTH+1] ) begin // Positive!
            p0 <= p0_pre[SINE_TBL_WIDTH-1:0]; // Sine table p0 index
            if ( p0_pre[SINE_TBL_WIDTH] ) begin // >= 32
                p0 <= ~p0_pre[SINE_TBL_WIDTH-1:0];
            end
        end
        if ( p0_pre[SINE_TBL_WIDTH+1] ) begin // Negative!
            p0 <= ~p0_pre[SINE_TBL_WIDTH-1:0];
            if ( !p0_pre[SINE_TBL_WIDTH] ) begin // >= 32
                p0 <= p0_pre[SINE_TBL_WIDTH-1:0];
            end
        end
    end
    // y(x)  = x(x(ax + b) + c) + d
    ax_x_6 <= set_p1n1n2;
    if ( ax_x_6 ) begin
        p_arg_1 <= abs_sine_c;
        p_arg_2 <= a_x_6;
    end
    ax <= ax_x_6;
    if ( ax ) begin
        p_arg_1 <= ONE_SIXTH;
        p_arg_2 <= product_c[PW-2:AW-1];
    end
    ax_plus_b <= ax;
    if ( ax_plus_b ) begin
        p_arg_1 <= abs_sine_c;
        p_arg_2 <= c_x_6;
        ax_plus_b_r <= product_c[PW-2:AW-1] + b;
    end
    cx <= ax_plus_b;
    if ( cx ) begin
        p_arg_1 <= ONE_SIXTH;
        p_arg_2 <= product_c[PW-2:AW-1];
    end
    axx_plus_bx <= cx;
    if ( axx_plus_bx ) begin
        p_arg_1 <= abs_sine_c;
        p_arg_2 <= ax_plus_b_r;
        cx_plus_d_r <= product_c[PW-2:AW-1] + d;
    end
    axxx_plus_bxx <= axx_plus_bx;
    if ( axxx_plus_bxx ) begin
        // p_arg_1 <= abs_sine_c;
        p_arg_2 <= product_c[PW-2:AW-1];
        m_sine_ch_i <= sine_ch_i;
    end
    yx <= axxx_plus_bxx;
    if ( yx ) begin
        m_sine_d_i[RADIAN_WIDTH-1] <= yx_i[AW-1]; // Copy sign!
        m_sine_d_i[RADIAN_WIDTH-2:0] <= yx_i[RADIAN_WIDTH:2];
        // Check for overflow!
        if ( overflow_p ) begin
            m_sine_d_i[RADIAN_WIDTH-2:0] <= ALL_ONES;
        end
        if ( overflow_n ) begin
            m_sine_d_i[RADIAN_WIDTH-2:0] <= ALL_ZERO;
        end
        if ( sine_c[AW-1] ) begin // Adjust output for negative sign!
            m_sine_d_i[RADIAN_WIDTH-1] <= ~yx_i[AW-1]; // Negate sign!
            m_sine_d_i[RADIAN_WIDTH-2:0] <= -yx_i[RADIAN_WIDTH:2];
            // Check for overflow!
            if ( overflow_p ) begin
                m_sine_d_i[RADIAN_WIDTH-2:0] <= ALL_ZERO;
            end
            if ( overflow_n ) begin
                m_sine_d_i[RADIAN_WIDTH-2:0] <= ALL_ONES;
            end
        end
        s_sine_dr <= 1;
        m_sine_dv_i <= 1;
    end
    if ( !rst_n ) begin
        s_sine_dr <= 1;
        ax <= 0;
        ax_x_6 <= 0;
        ax_plus_b <= 0;
        axx_plus_bx <= 0;
        cx <= 0;
        yx <= 0;
    end
end // sine_wg_polerator

assign m_sine_d = m_sine_d_i;
assign m_sine_ch = m_sine_ch_i;
assign m_sine_dv = m_sine_dv_i;

integer i;
/*============================================================================*/
initial begin : init_arrays
/*============================================================================*/
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        sine[i] = 0;
    end
end

/*============================================================================*/
initial begin : init_sine_table // Generate table with e.g. Octave
/*============================================================================*/
// Quarter sine-wave (90 degrees, PI/2 radian) lookup table.
//
// fid=fopen('sine_table.txt', 'w+')
// for i=0:31 fprintf( fid, '    sine_table[%d] = ( FACTOR_1 * %.24f ) + 0.5;\n', i, sin( pi * i / 64.0 )) endfor
// fclose(fid)
//
    sine_table[0]  = 0;
//  SINE_TBL_SIZE = 32
/*  sine_table[1]  = ( FACTOR_1 * 0.049067674327418014934565 ) + 0.5;
    sine_table[2]  = ( FACTOR_1 * 0.098017140329560603628778 ) + 0.5;
    sine_table[3]  = ( FACTOR_1 * 0.146730474455361747931903 ) + 0.5;
    sine_table[4]  = ( FACTOR_1 * 0.195090322016128248083788 ) + 0.5;
    sine_table[5]  = ( FACTOR_1 * 0.242980179903263870944130 ) + 0.5;
    sine_table[6]  = ( FACTOR_1 * 0.290284677254462331053020 ) + 0.5;
    sine_table[7]  = ( FACTOR_1 * 0.336889853392220051109263 ) + 0.5;
    sine_table[8]  = ( FACTOR_1 * 0.382683432365089781779233 ) + 0.5;
    sine_table[9]  = ( FACTOR_1 * 0.427555093430282084909777 ) + 0.5;
    sine_table[10] = ( FACTOR_1 * 0.471396736825997642039709 ) + 0.5;
    sine_table[11] = ( FACTOR_1 * 0.514102744193221661284099 ) + 0.5;
    sine_table[12] = ( FACTOR_1 * 0.555570233019602177648721 ) + 0.5;
    sine_table[13] = ( FACTOR_1 * 0.595699304492433356905678 ) + 0.5;
    sine_table[14] = ( FACTOR_1 * 0.634393284163645487794270 ) + 0.5;
    sine_table[15] = ( FACTOR_1 * 0.671558954847018330092112 ) + 0.5;
    sine_table[16] = ( FACTOR_1 * 0.707106781186547461715008 ) + 0.5;
    sine_table[17] = ( FACTOR_1 * 0.740951125354959105884234 ) + 0.5;
    sine_table[18] = ( FACTOR_1 * 0.773010453362736993376814 ) + 0.5;
    sine_table[19] = ( FACTOR_1 * 0.803207531480644831844984 ) + 0.5;
    sine_table[20] = ( FACTOR_1 * 0.831469612302545235671403 ) + 0.5;
    sine_table[21] = ( FACTOR_1 * 0.857728610000272118085718 ) + 0.5;
    sine_table[22] = ( FACTOR_1 * 0.881921264348354938533703 ) + 0.5;
    sine_table[23] = ( FACTOR_1 * 0.903989293123443338195955 ) + 0.5;
    sine_table[24] = ( FACTOR_1 * 0.923879532511286738483136 ) + 0.5;
    sine_table[25] = ( FACTOR_1 * 0.941544065183020806308889 ) + 0.5;
    sine_table[26] = ( FACTOR_1 * 0.956940335732208935404230 ) + 0.5;
    sine_table[27] = ( FACTOR_1 * 0.970031253194543974238684 ) + 0.5;
    sine_table[28] = ( FACTOR_1 * 0.980785280403230430579242 ) + 0.5;
    sine_table[29] = ( FACTOR_1 * 0.989176509964781014438984 ) + 0.5;
    sine_table[30] = ( FACTOR_1 * 0.995184726672196817709448 ) + 0.5;
    sine_table[31] = ( FACTOR_1 * 0.998795456205172405006465 ) + 0.5;
*/
//  for i=0:63 fprintf( fid, '    sine_table[%d] = ( FACTOR_1 * %.24f ) + 0.5;\n', i, sin( pi * i / 128.0 )) endfor
//  SINE_TBL_SIZE = 64
    sine_table[1] =  ( FACTOR_1 * 0.024541228522912288123603 ) + 0.5;
    sine_table[2] =  ( FACTOR_1 * 0.049067674327418014934565 ) + 0.5;
    sine_table[3] =  ( FACTOR_1 * 0.073564563599667426307960 ) + 0.5;
    sine_table[4] =  ( FACTOR_1 * 0.098017140329560603628778 ) + 0.5;
    sine_table[5] =  ( FACTOR_1 * 0.122410675199216195663254 ) + 0.5;
    sine_table[6] =  ( FACTOR_1 * 0.146730474455361747931903 ) + 0.5;
    sine_table[7] =  ( FACTOR_1 * 0.170961888760301217171644 ) + 0.5;
    sine_table[8] =  ( FACTOR_1 * 0.195090322016128248083788 ) + 0.5;
    sine_table[9] =  ( FACTOR_1 * 0.219101240156869797592876 ) + 0.5;
    sine_table[10] = ( FACTOR_1 * 0.242980179903263870944130 ) + 0.5;
    sine_table[11] = ( FACTOR_1 * 0.266712757474898365384064 ) + 0.5;
    sine_table[12] = ( FACTOR_1 * 0.290284677254462331053020 ) + 0.5;
    sine_table[13] = ( FACTOR_1 * 0.313681740398891517607183 ) + 0.5;
    sine_table[14] = ( FACTOR_1 * 0.336889853392220051109263 ) + 0.5;
    sine_table[15] = ( FACTOR_1 * 0.359895036534988110865640 ) + 0.5;
    sine_table[16] = ( FACTOR_1 * 0.382683432365089781779233 ) + 0.5;
    sine_table[17] = ( FACTOR_1 * 0.405241314004989860997341 ) + 0.5;
    sine_table[18] = ( FACTOR_1 * 0.427555093430282084909777 ) + 0.5;
    sine_table[19] = ( FACTOR_1 * 0.449611329654606539651951 ) + 0.5;
    sine_table[20] = ( FACTOR_1 * 0.471396736825997642039709 ) + 0.5;
    sine_table[21] = ( FACTOR_1 * 0.492898192229784037898810 ) + 0.5;
    sine_table[22] = ( FACTOR_1 * 0.514102744193221661284099 ) + 0.5;
    sine_table[23] = ( FACTOR_1 * 0.534997619887097153323907 ) + 0.5;
    sine_table[24] = ( FACTOR_1 * 0.555570233019602177648721 ) + 0.5;
    sine_table[25] = ( FACTOR_1 * 0.575808191417845338655468 ) + 0.5;
    sine_table[26] = ( FACTOR_1 * 0.595699304492433356905678 ) + 0.5;
    sine_table[27] = ( FACTOR_1 * 0.615231590580626819253496 ) + 0.5;
    sine_table[28] = ( FACTOR_1 * 0.634393284163645487794270 ) + 0.5;
    sine_table[29] = ( FACTOR_1 * 0.653172842953776755514639 ) + 0.5;
    sine_table[30] = ( FACTOR_1 * 0.671558954847018330092112 ) + 0.5;
    sine_table[31] = ( FACTOR_1 * 0.689540544737066829483751 ) + 0.5;
    sine_table[32] = ( FACTOR_1 * 0.707106781186547461715008 ) + 0.5;
    sine_table[33] = ( FACTOR_1 * 0.724247082951466891742598 ) + 0.5;
    sine_table[34] = ( FACTOR_1 * 0.740951125354959105884234 ) + 0.5;
    sine_table[35] = ( FACTOR_1 * 0.757208846506484456462260 ) + 0.5;
    sine_table[36] = ( FACTOR_1 * 0.773010453362736993376814 ) + 0.5;
    sine_table[37] = ( FACTOR_1 * 0.788346427626606227612172 ) + 0.5;
    sine_table[38] = ( FACTOR_1 * 0.803207531480644831844984 ) + 0.5;
    sine_table[39] = ( FACTOR_1 * 0.817584813151583711388071 ) + 0.5;
    sine_table[40] = ( FACTOR_1 * 0.831469612302545235671403 ) + 0.5;
    sine_table[41] = ( FACTOR_1 * 0.844853565249707005868629 ) + 0.5;
    sine_table[42] = ( FACTOR_1 * 0.857728610000272118085718 ) + 0.5;
    sine_table[43] = ( FACTOR_1 * 0.870086991108711349518501 ) + 0.5;
    sine_table[44] = ( FACTOR_1 * 0.881921264348354938533703 ) + 0.5;
    sine_table[45] = ( FACTOR_1 * 0.893224301195515324458540 ) + 0.5;
    sine_table[46] = ( FACTOR_1 * 0.903989293123443338195955 ) + 0.5;
    sine_table[47] = ( FACTOR_1 * 0.914209755703530690951197 ) + 0.5;
    sine_table[48] = ( FACTOR_1 * 0.923879532511286738483136 ) + 0.5;
    sine_table[49] = ( FACTOR_1 * 0.932992798834738845670245 ) + 0.5;
    sine_table[50] = ( FACTOR_1 * 0.941544065183020806308889 ) + 0.5;
    sine_table[51] = ( FACTOR_1 * 0.949528180593036674750351 ) + 0.5;
    sine_table[52] = ( FACTOR_1 * 0.956940335732208935404230 ) + 0.5;
    sine_table[53] = ( FACTOR_1 * 0.963776065795439840222514 ) + 0.5;
    sine_table[54] = ( FACTOR_1 * 0.970031253194543974238684 ) + 0.5;
    sine_table[55] = ( FACTOR_1 * 0.975702130038528570032952 ) + 0.5;
    sine_table[56] = ( FACTOR_1 * 0.980785280403230430579242 ) + 0.5;
    sine_table[57] = ( FACTOR_1 * 0.985277642388941221618381 ) + 0.5;
    sine_table[58] = ( FACTOR_1 * 0.989176509964781014438984 ) + 0.5;
    sine_table[59] = ( FACTOR_1 * 0.992479534598709967063712 ) + 0.5;
    sine_table[60] = ( FACTOR_1 * 0.995184726672196817709448 ) + 0.5;
    sine_table[61] = ( FACTOR_1 * 0.997290456678690206970828 ) + 0.5;
    sine_table[62] = ( FACTOR_1 * 0.998795456205172405006465 ) + 0.5;
    sine_table[63] = ( FACTOR_1 * 0.999698818696204249967252 ) + 0.5;
end

endmodule // sine_wg_pol