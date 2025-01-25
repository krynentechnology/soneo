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
 *  Multi channel sine wave generator. CORDIC algorithm based (atan lookup
 *  table): https://en.wikipedia.org/wiki/CORDIC (COordinate Rotation DIgital
 *  Computer)
 *
 *  The input angle (radian) is added to the previous (set) channel angle. The
 *  s_sine_zero input signal indicates a phase of zero to be added. The cosine
 *  is also available as output signal. The atan lookup table number of elements
 *  should match with the PRECISION parameter, see init_cordic_table!
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module sine_wg_cor #(
/*============================================================================*/
    parameter NR_CHANNELS = 2,
    parameter RADIAN_WIDTH = 28,
    parameter PRECISION = 25 )
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    s_sine_d, // Signed angle (radian -PI, +PI), S2.(RADIAN_WIDTH-3) fraction!
    s_sine_zero, // Phase reset flag. 2.0^(RADIAN_WIDTH-3) == 1.0!
    s_sine_ch, // _ch = channel for sine wave generation
    s_sine_dv, // _dv = data valid
    s_sine_dr, // _dr = data ready
    m_sine_d, // Sine, (-1.0, +1.0), S1.(RADIAN_WIDTH-2) fraction!
    m_cosine_d, // Cosine, (-1.0, +1.0), S1.(RADIAN_WIDTH-2) fraction!
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

input  wire clk;
input  wire rst_n;
input  wire [RADIAN_WIDTH-1:0] s_sine_d;
input  wire s_sine_zero;
input  wire [CHANNEL_WIDTH-1:0] s_sine_ch;
input  wire s_sine_dv;
output wire s_sine_dr;
output wire [RADIAN_WIDTH-1:0] m_sine_d;
output wire [RADIAN_WIDTH-1:0] m_cosine_d;
output wire [CHANNEL_WIDTH-1:0] m_sine_ch;
output wire m_sine_dv;
input  wire m_sine_dr;

localparam RW = RADIAN_WIDTH;

/*============================================================================*/
function signed [RW:0] abs( input signed [RW:0] value );
/*============================================================================*/
    begin
        abs = value;
        if ( value[RW] ) begin
            abs = -value;
        end
    end
endfunction

localparam ATAN_TBL_WIDTH = clog2( PRECISION - 1 );
localparam real FACTOR_1_0 = 2.0 ** ( RW - 3 );
localparam real K_FACTOR = ( FACTOR_1_0 * 2.0 * 0.607252935008881444822748 );
localparam [RW-1:0] FACTOR_1 = FACTOR_1_0;

localparam real MATH_PI = 3.141592653589793115997963;
localparam [RW:0] PI_OVER_2 = ( FACTOR_1_0 * MATH_PI / 2.0 );
localparam [RW:0] PI = PI_OVER_2 << 1; // PI = 2 x PI_OVER_2 exactly!
localparam [RW:0] PI_X_2 = PI << 1;

/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( RADIAN_WIDTH < ( ATAN_TBL_WIDTH + 3 )) begin
        $display( "RADIAN_WIDTH < ( ATAN_TBL_WIDTH + 3 )!" );
        $finish;
    end
    if ( FACTOR_1 != FACTOR_1_0 ) begin
        $display( "FACTOR_1 != FACTOR_1_0!" );
        $finish;
    end
    // Precision should be less (-3) than angle fraction!
    if ( PRECISION > ( RADIAN_WIDTH - 3 )) begin
        $display( "PRECISION > ( RADIAN_WIDTH - 3 )!" );
        $finish;
    end
    // Precision should be greater than 5!
    if ( PRECISION < 6 ) begin
        $display( "PRECISION < 6!" );
        $finish;
    end
end // param_check

reg [RW-4:0] tangle_table[0:PRECISION-1];
reg [1:0] quadrant; // 00 == 1st quadrant, 11 = 4th quadrant
reg [ATAN_TBL_WIDTH:0] n = 0; // Iterator
reg signed [RW-1:0] x = 0;
reg signed [RW-1:0] y = 0;

// Boolean states
reg set_quadrant = 0;
reg check_pi_overflow = 0;
reg cordic_loop = 0;
reg yx = 0;

reg s_sine_dr_i = 1;
reg [RW-1:0] m_sine_d_i = 0;
reg [RW-1:0] m_cosine_d_i = 0;
reg [CHANNEL_WIDTH-1:0] m_sine_ch_i = 0;
reg m_sine_dv_i = 0;

reg [CHANNEL_WIDTH-1:0] sine_ch_i = 0;
reg signed [RW:0] angle_ch[0:NR_CHANNELS-1];
reg signed [RW:0] prev_angle = 0;
reg signed [RW:0] angle = 0;

wire signed [RW:0] s_sine_d_c;
wire signed [RW:0] angle_c;
wire signed [RW:0] abs_angle_c;
wire signed [RW:0] pi_angle_c;
wire signed [RW:0] pi_x_2_angle_c;
wire signed [RW:0] pi_over_2_angle_c;
wire signed [RW:0] tangle;
wire signed [RW-1:0] x_r_shift_n;
wire signed [RW-1:0] y_r_shift_n;

assign s_sine_d_c = {s_sine_d[RW-1], s_sine_d};
assign angle_c = angle_ch[sine_ch_i] + prev_angle;
assign abs_angle_c = abs(angle_c);
assign pi_x_2_angle_c = abs_angle_c - $signed( PI_X_2 );
assign pi_angle_c = abs_angle_c - $signed( PI );
assign pi_over_2_angle_c = abs_angle_c - $signed( PI_OVER_2 );
assign tangle = $signed( {4'h0, tangle_table[n]} );
assign x_r_shift_n = x >>> n; // Signed shift right
assign y_r_shift_n = y >>> n;

/*============================================================================*/
always @(posedge clk) begin : sine_wave_generator
/*============================================================================*/
    m_sine_dv_i <= m_sine_dv_i & ~m_sine_dr;
    check_pi_overflow <= 0; // Pulse
    if ( s_sine_dv && s_sine_dr_i && ( s_sine_ch < NR_CHANNELS )) begin
        s_sine_dr_i <= 0;
        sine_ch_i <= s_sine_ch;
        prev_angle <= angle_ch[s_sine_ch];
        angle_ch[s_sine_ch] <= s_sine_d_c;
        if ( s_sine_zero ) begin
            prev_angle <= 0;
        end
        check_pi_overflow <= 1;
    end
    if ( check_pi_overflow ) begin
        angle_ch[sine_ch_i] <= angle_c;
        prev_angle <= 0; // Reset (for set_quadrant)!
        if ( !pi_angle_c[RW] && |pi_angle_c[RW-1:0] ) begin // Angle > PI
            // 2PI correction!
            angle_ch[sine_ch_i] <= pi_x_2_angle_c;
            // Correction for negative angle
            if ( angle_c[RW] && |pi_x_2_angle_c[RW-1:0] ) begin
                angle_ch[sine_ch_i] <= -pi_x_2_angle_c;
            end
        end
    end
    set_quadrant <= check_pi_overflow;
    if ( set_quadrant ) begin
        angle <= -pi_angle_c;
        quadrant <= {angle_c[RW], ~angle_c[RW]}; // 2nd or 3rd quadrant
        if ( pi_over_2_angle_c[RW] ) begin // 1st or 4th quadrant
            quadrant <= {angle_c[RW], angle_c[RW]};
            angle <= abs_angle_c;
        end
        if ( 0 == pi_angle_c ) begin // Check for zero
            angle <= 0;
        end
        n <= 0;
        x <= K_FACTOR;
        y <= 0;
    end
    cordic_loop <= set_quadrant;
    yx <= 0;
    if ( cordic_loop ) begin
        x <= x - y_r_shift_n;
        y <= y + x_r_shift_n;
        angle <= angle - tangle;
        if ( angle[RW] ) begin // angle < 0
            x <= x + y_r_shift_n;
            y <= y - x_r_shift_n;
            angle <= angle + tangle;
        end
        if (( PRECISION - 1 ) == n ) begin
            yx <= 1; // cordic_loop finished!
        end else begin
            cordic_loop <= 1;
            n <= n + 1;
        end
    end
    if ( yx ) begin
        m_sine_d_i <= y;
        if ( quadrant[1] ) begin // 3rd and 4th quadrant
            m_sine_d_i <= -y;
        end
        m_cosine_d_i <= x;
        if ( ^quadrant ) begin // 2nd and 3rd quadrant
            m_cosine_d_i <= -x;
        end
        m_sine_ch_i <= sine_ch_i;
        s_sine_dr_i <= m_sine_dr;
        m_sine_dv_i <= 1;
        yx <= ~m_sine_dr;
    end
    if ( !rst_n ) begin
        s_sine_dr_i <= 1;
        check_pi_overflow <= 0;
        set_quadrant <= 0;
        yx <= 0;
    end
end // sine_wave_generator

assign s_sine_dr = s_sine_dr_i;
assign m_sine_d = m_sine_d_i;
assign m_cosine_d = m_cosine_d_i;
assign m_sine_ch = m_sine_ch_i;
assign m_sine_dv = m_sine_dv_i;

integer i;
/*============================================================================*/
initial begin : init_arrays
/*============================================================================*/
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
        angle_ch[i] = 0;
    end
end

/*============================================================================*/
initial begin : init_cordic_table // Generate table with e.g. Octave
/*============================================================================*/
// ATAN angle (radian) lookup table.
//
// fid=fopen('cor_tangle_table.txt', 'w+')
// for n=0:24 fprintf( fid, '    tangle_table[%d] = ( FACTOR_1 * %.24f );\n', n, atan( 1 / power( 2, n ))) endfor
// fclose(fid)
    tangle_table[0] = ( FACTOR_1 * 0.785398163397448278999491 );
    tangle_table[1] = ( FACTOR_1 * 0.463647609000806093515479 );
    tangle_table[2] = ( FACTOR_1 * 0.244978663126864143473327 );
    tangle_table[3] = ( FACTOR_1 * 0.124354994546761438156679 );
    tangle_table[4] = ( FACTOR_1 * 0.062418809995957350023055 );
    tangle_table[5] = ( FACTOR_1 * 0.031239833430268277442154 );
    if ( 6  < PRECISION ) tangle_table[6]  = ( FACTOR_1 * 0.015623728620476831294162 );
    if ( 7  < PRECISION ) tangle_table[7]  = ( FACTOR_1 * 0.007812341060101111143987 );
    if ( 8  < PRECISION ) tangle_table[8]  = ( FACTOR_1 * 0.003906230131966971757390 );
    if ( 9  < PRECISION ) tangle_table[9]  = ( FACTOR_1 * 0.001953122516478818758434 );
    if ( 10 < PRECISION ) tangle_table[10] = ( FACTOR_1 * 0.000976562189559319459436 );
    if ( 11 < PRECISION ) tangle_table[11] = ( FACTOR_1 * 0.000488281211194898289926 );
    if ( 12 < PRECISION ) tangle_table[12] = ( FACTOR_1 * 0.000244140620149361771245 );
    if ( 13 < PRECISION ) tangle_table[13] = ( FACTOR_1 * 0.000122070311893670207853 );
    if ( 14 < PRECISION ) tangle_table[14] = ( FACTOR_1 * 0.000061035156174208772594 );
    if ( 15 < PRECISION ) tangle_table[15] = ( FACTOR_1 * 0.000030517578115526095727 );
    if ( 16 < PRECISION ) tangle_table[16] = ( FACTOR_1 * 0.000015258789061315761542 );
    if ( 17 < PRECISION ) tangle_table[17] = ( FACTOR_1 * 0.000007629394531101969981 );
    if ( 18 < PRECISION ) tangle_table[18] = ( FACTOR_1 * 0.000003814697265606496142 );
    if ( 19 < PRECISION ) tangle_table[19] = ( FACTOR_1 * 0.000001907348632810186965 );
    if ( 20 < PRECISION ) tangle_table[20] = ( FACTOR_1 * 0.000000953674316405960844 );
    if ( 21 < PRECISION ) tangle_table[21] = ( FACTOR_1 * 0.000000476837158203088842 );
    if ( 22 < PRECISION ) tangle_table[22] = ( FACTOR_1 * 0.000000238418579101557974 );
    if ( 23 < PRECISION ) tangle_table[23] = ( FACTOR_1 * 0.000000119209289550780681 );
    if ( 24 < PRECISION ) tangle_table[24] = ( FACTOR_1 * 0.000000059604644775390552 );
    if ( 25 < PRECISION ) tangle_table[25] = ( FACTOR_1 * 0.000000029802322387695303 );
    if ( 26 < PRECISION ) tangle_table[26] = ( FACTOR_1 * 0.000000014901161193847655 );
    if ( 27 < PRECISION ) tangle_table[27] = ( FACTOR_1 * 0.000000007450580596923828 );
    if ( 28 < PRECISION ) tangle_table[28] = ( FACTOR_1 * 0.000000003725290298461914 );
    if ( 29 < PRECISION ) tangle_table[29] = ( FACTOR_1 * 0.000000001862645149230957 );
    if ( 30 < PRECISION ) tangle_table[30] = ( FACTOR_1 * 0.000000000931322574615479 );
    if ( 31 < PRECISION ) tangle_table[31] = ( FACTOR_1 * 0.000000000465661287307739 );

    if ( 1'bx === tangle_table[PRECISION-1][0] ) begin
        $display( "ATAN tangle_table[%0d] is unknown!", ( PRECISION - 1 ));
        $finish;
    end

// K-factor lookup table.
//
// fid=fopen('cor_k_table.txt', 'w+')
// for n=1:25 cos_arctan(n)=cos( atan( 1 / power( 2, ( n - 1 )))); endfor
// temp = 1.0; for n=1:32 temp=temp * cos_arctan(n); p(n) = temp; endfor
// for n=1:25 fprintf( fid, '    k_table[%d] = ( FACTOR_1 * %.24f );\n', (n-1), p(n) ) endfor
// fclose(fid)
/*
    k_table[0]  = ( FACTOR_1 * 0.707106781186547572737311 );
    k_table[1]  = ( FACTOR_1 * 0.632455532033675882352952 );
    k_table[2]  = ( FACTOR_1 * 0.613571991077896394806146 );
    k_table[3]  = ( FACTOR_1 * 0.608833912517752429138795 );
    k_table[4]  = ( FACTOR_1 * 0.607648256256168250999394 );
    k_table[5]  = ( FACTOR_1 * 0.607351770141296043448165 );
    k_table[6]  = ( FACTOR_1 * 0.607277644093526136614969 );
    k_table[7]  = ( FACTOR_1 * 0.607259112298892844705733 );
    k_table[8]  = ( FACTOR_1 * 0.607254479332562491222802 );
    k_table[9]  = ( FACTOR_1 * 0.607253321089875286453719 );
    k_table[10] = ( FACTOR_1 * 0.607253031529134457144892 );
    k_table[11] = ( FACTOR_1 * 0.607252959138944947703465 );
    k_table[12] = ( FACTOR_1 * 0.607252941041397265031776 );
    k_table[13] = ( FACTOR_1 * 0.607252936517010399875005 );
    k_table[14] = ( FACTOR_1 * 0.607252935385913628074661 );
    k_table[15] = ( FACTOR_1 * 0.607252935103139490635726 );
    k_table[16] = ( FACTOR_1 * 0.607252935032445928520417 );
    k_table[17] = ( FACTOR_1 * 0.607252935014772510236014 );
    k_table[18] = ( FACTOR_1 * 0.607252935010354155664913 );
    k_table[19] = ( FACTOR_1 * 0.607252935009249594777714 );
    k_table[20] = ( FACTOR_1 * 0.607252935008973482311490 );
    k_table[21] = ( FACTOR_1 * 0.607252935008904426439358 );
    k_table[22] = ( FACTOR_1 * 0.607252935008887217982476 );
    k_table[23] = ( FACTOR_1 * 0.607252935008882888112680 );
    k_table[24] = ( FACTOR_1 * 0.607252935008881777889655 );
    k_table[25] = ( FACTOR_1 * 0.607252935008881555845051 );
    k_table[26] = ( FACTOR_1 * 0.607252935008881444822748 );
    k_table[27] = ( FACTOR_1 * 0.607252935008881444822748 );
    k_table[28] = ( FACTOR_1 * 0.607252935008881444822748 );
    k_table[29] = ( FACTOR_1 * 0.607252935008881444822748 );
    k_table[30] = ( FACTOR_1 * 0.607252935008881444822748 );
    k_table[31] = ( FACTOR_1 * 0.607252935008881444822748 );
*/
end // init_cordic_table

endmodule // sine_wg_cor