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
 *  Description: Limiter, signal attenuation above -6dB (is considered RMS level
 *               - continuous output). Companding signal 37-bit -> 33-bit,
 *               maximum 24dB attenuation. Optional signal attenuation by
 *               fraction to minimize distortion.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module limiter #(
    parameter NR_CHANNELS = 2,
    parameter INPUT_WIDTH = 32,
    parameter OUTPUT_WIDTH = 24,
    parameter [0:0] ATTENUATION = 0, // 1 = Signal attenuation by fraction
    parameter [3:0] MAX_ATTACK_SHIFT = 10, // Fraction adjusted by ATTACK_SHIFT
    parameter [3:0] MAX_RELEASE_SHIFT = 10, // Fraction adjusted by RELEASE_SHIFT
    parameter [1:0] MAX_AVG_SHIFT = 3  // 2^3 = 8 samples at 48kHz ~ 0.2ms
    )                                  // spike filter response
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    signal_d, signal_ch, // _d = data, _ch = channel
    signal_dv, signal_dr, // _dv = data valid, _dr = data ready
    attack_shift, release_shift, avg_shift,
    lim_d, lim_ch, lim_dv
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

localparam CHW = clog2( NR_CHANNELS ); // Channel width
localparam INW = INPUT_WIDTH;
localparam OUTW = OUTPUT_WIDTH;
localparam COMPANDING_WIDTH = INPUT_WIDTH - OUTPUT_WIDTH + 1;
localparam COMW = ( COMPANDING_WIDTH > 5 ) ? 5 : COMPANDING_WIDTH;
localparam OVERFLOW_WIDTH = INPUT_WIDTH - OUTPUT_WIDTH - COMW + 1;
localparam OVW = ( OVERFLOW_WIDTH > 0 ) ? OVERFLOW_WIDTH : 0;
localparam ATTACK_SHIFT_WIDTH = clog2( MAX_ATTACK_SHIFT );
localparam RELEASE_SHIFT_WIDTH = clog2( MAX_RELEASE_SHIFT );
localparam AVG_SHIFT_WIDTH = clog2( MAX_AVG_SHIFT );
localparam AVGW = MAX_AVG_SHIFT + COMW;

input  wire clk;
input  wire rst_n; // Synchronous reset, high when clk is stable!
input  wire [INW-1:0] signal_d;
input  wire [CHW-1:0] signal_ch;
input  wire signal_dv;
output wire signal_dr;
input  wire [ATTACK_SHIFT_WIDTH-1:0] attack_shift; // Attack response timing!
input  wire [RELEASE_SHIFT_WIDTH-1:0] release_shift; // Release response timing!
input  wire [AVG_SHIFT_WIDTH-1:0] avg_shift; // Spike filter response!
output reg  [OUTW-1:0] lim_d = 0;
output reg  [CHW-1:0] lim_ch = 0;
output reg  lim_dv = 0;

/*============================================================================*/
initial begin : param_check
/*============================================================================*/
    if ( NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )) begin
        $display( "NR_CHANNELS > (( 2 ** MAX_CLOG2_WIDTH ) - 1 )!" );
        $finish;
    end
    if ( COMPANDING_WIDTH < 1 ) begin
        $display( "COMPANDING WIDTH < 1!" );
        $finish;
    end
    if ( ATTENUATION && ( MAX_ATTACK_SHIFT < 6 )) begin
        $display( "ATTACK_SHIFT < 6!" );
        $finish;
    end
    if ( ATTENUATION && ( MAX_RELEASE_SHIFT < 6 )) begin
        $display( "RELEASE_SHIFT < 6!" );
        $finish;
    end
    if ( ATTENUATION && ( MAX_AVG_SHIFT < 1 )) begin
        $display( "MAX_AVG_SHIFT < 1!" );
        $finish;
    end
end // param_check

wire [COMW-1:0] lim_chord;
wire [COMW-1:0] lim_shift;
wire signed [OUTW-1:0] lim_d_i;
wire lim_overflow;

generate
if ( ATTENUATION ) begin

localparam [INW-2:0] FRACTION_1_0 = 2 ** ( INW - 2 );

reg signed [INW-1:0] signal_d_i = 0;
reg signal_dv_i = 0;
reg [CHW-1:0] lim_ch_i = 0;
reg lim_dv_i = 0;
reg [INW-2:0] fraction[0:NR_CHANNELS-1];
reg [AVGW-1:0] avg_lim_shift[0:NR_CHANNELS-1];
reg [AVGW-1:0] avg_attn_lim_shift[0:NR_CHANNELS-1];

wire [COMW-1:0] lim_chord_i;
wire [COMW-1:0] lim_shift_i;
wire [ATTACK_SHIFT_WIDTH-1:0] attack_shift_c;
assign attack_shift_c = ( attack_shift > MAX_ATTACK_SHIFT ) ? MAX_ATTACK_SHIFT : attack_shift;
wire [MAX_RELEASE_SHIFT-1:0] release_shift_c;
assign release_shift_c = ( release_shift > MAX_RELEASE_SHIFT ) ? MAX_RELEASE_SHIFT : release_shift;
wire [AVG_SHIFT_WIDTH-1:0] avg_shift_c;
assign avg_shift_c = ( avg_shift > MAX_AVG_SHIFT ) ? MAX_AVG_SHIFT : avg_shift;
wire signal_dv_c;
assign signal_dv_c = signal_dv && signal_dr && ( signal_ch < NR_CHANNELS );
wire [CHW-1:0] lim_ch_c;
assign lim_ch_c = signal_dv_c ? signal_ch : lim_ch_i;
wire [INW-2:0] fraction_c;
assign fraction_c = fraction[lim_ch_c];
wire [INW-2:0] fraction_attack_shift_c;
assign fraction_attack_shift_c = fraction_c >> attack_shift_c;
wire [INW-2:0] fraction_release_shift_c;
assign fraction_release_shift_c = fraction_c >> release_shift_c;
wire [INW-2:0] fraction_plus_shift_c;
assign fraction_plus_shift_c = fraction_c + fraction_release_shift_c;
wire [AVGW-1:0] avg_lim_shift_c;
assign avg_lim_shift_c = avg_lim_shift[lim_ch_c];
wire [AVGW-1:0] avg_attn_lim_shift_c;
assign avg_attn_lim_shift_c = avg_attn_lim_shift[lim_ch_c];
wire [COMW-1:0] avg_lim_shift_sc;
assign avg_lim_shift_sc = avg_lim_shift_c >> avg_shift_c;
wire [COMW-1:0] avg_attn_lim_shift_sc;
assign avg_attn_lim_shift_sc = avg_attn_lim_shift_c >> avg_shift_c;

reg [CHW-1:0] i = 0;
/*============================================================================*/
initial begin
/*============================================================================*/
    for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin // Initialize data memory
        fraction[i] = FRACTION_1_0;
        avg_lim_shift[i] = 0;
        avg_attn_lim_shift[i] = 0;
    end
end

/*============================================================================*/
function [AVGW-1:0] moving_average(
    input [AVGW-1:0] avg,
    input [COMW-1:0] lim_shift,
    input [AVG_SHIFT_WIDTH-1:0] shift );
/*============================================================================*/
begin
    if (( 0 == lim_shift ) && !( |avg[AVGW-1:COMW] ) && |avg[COMW-1:0] ) begin
        moving_average = avg - 1;
    end else begin
        moving_average = avg - ( avg >> shift ) + {{(MAX_AVG_SHIFT){1'b0}}, lim_shift};
    end
end
endfunction // moving_average

assign lim_chord = signal_d[( OUTW + COMW - 3 ):OUTW-2];
assign lim_shift = signal_d[INW-1] ? ~lim_chord : lim_chord;
assign lim_chord_i = signal_d_i[( OUTW + COMW - 3 ):OUTW-2];
assign lim_shift_i = signal_d_i[INW-1] ? ~lim_chord_i : lim_chord_i;

/*============================================================================*/
always @(posedge clk) begin : lim_shift_average
/*============================================================================*/
    if ( signal_dv_c ) begin
        avg_lim_shift[lim_ch_c] <= moving_average( avg_lim_shift_c, lim_shift, avg_shift_c );
    end
    if ( signal_dv_i ) begin
        avg_attn_lim_shift[lim_ch_c] <= moving_average( avg_attn_lim_shift_c, lim_shift_i, avg_shift_c );
    end
end // lim_shift_average

reg signed [( 2 * INW )-1:0] signal_attn;

/*============================================================================*/
always @(*) begin : signal_attenuation
/*============================================================================*/
    signal_attn = $signed( signal_d ) * $signed( {1'b0, fraction_c} ) +
        // Round to zero (for negative values)!
        $signed( {{( INW + 2 ){1'b0}}, {( INW - 2 ){signal_d[INW-1]}}} );
end // signal_attenuation

assign signal_dr = ~signal_dv_i;
assign lim_d_i = {~signal_d_i[INW-1], signal_d_i[INW-1], signal_d_i[OUTW-3:0]};
assign lim_overflow = ( 0 == OVW ) ? 0 : signal_d_i[INW-2:INW-OVW-1] != {(OVW){signal_d_i[INW-1]}};

/*============================================================================*/
always @(posedge clk) begin : limit_signal
/*============================================================================*/
    signal_dv_i <= 0;
    lim_dv <= signal_dv_i;
    if ( signal_dv_c ) begin
        signal_d_i <= {signal_attn[( 2 * INW )-1], signal_attn[( 2 * INW )-4:INW-2]};
        lim_ch_i <= signal_ch;
        signal_dv_i <= 1;
    end
    if ( signal_dv_i ) begin
        lim_d <= lim_d_i >>> lim_shift_i; // Signed shift
        lim_d[OUTW-1] <= signal_d_i[INW-1]; // Sign
        if ( &lim_shift ) begin // Maximum shift!
            lim_d[0] <= signal_d_i[OUTW-3];
        end
        if ( lim_overflow ) begin // Maximum signed value!
            lim_d[OUTW-2:0] <= ~{(OUTW-1){signal_d_i[INW-1]}};
        end
        lim_ch <= lim_ch_i;
        if ( avg_attn_lim_shift_sc > 0 ) begin
            // Decrease fraction
            fraction[lim_ch_c] <= fraction_c - fraction_attack_shift_c;
        end
        if ( !fraction_c[INW-2] ) begin // Fraction < 1 ?
            if ( 0 == avg_attn_lim_shift_sc ) begin
                // Increase fraction
                fraction[lim_ch_c] <= fraction_plus_shift_c;
            end
            if ( fraction_plus_shift_c[INW-2] ) begin // New fraction >= 1 ?
                fraction[lim_ch_c] <= FRACTION_1_0;
            end
        end
    end
    if ( !rst_n ) begin
        signal_dv_i <= 0;
        lim_dv <= 0;
        for ( i = 0; i < NR_CHANNELS; i = i + 1 ) begin
            fraction[i] = FRACTION_1_0;
            avg_lim_shift[i] <= 0;
            avg_attn_lim_shift[i] <= 0;
        end
    end
end // limit_signals

end else begin // !ATTENUATION

assign signal_dr = 1;
assign lim_chord = signal_d[( OUTW + COMW - 3 ):OUTW-2];
assign lim_shift = signal_d[INW-1] ? ~lim_chord : lim_chord;
assign lim_d_i = {~signal_d[INW-1], signal_d[INW-1], signal_d[OUTW-3:0]};
assign lim_overflow = ( 0 == OVW ) ? 0 : signal_d[INW-2:INW-OVW-1] != {(OVW){signal_d[INW-1]}};

/*============================================================================*/
always @(posedge clk) begin : limit_signal
/*============================================================================*/
    lim_ch <= signal_ch;
    lim_dv <= signal_dv;
    if ( signal_dv ) begin
        lim_d <= lim_d_i >>> lim_shift; // Signed shift
        lim_d[OUTW-1] <= signal_d[INW-1]; // Sign
        if ( &lim_shift ) begin // Maximum shift!
            lim_d[0] <= signal_d[OUTW-3];
        end
        if ( lim_overflow ) begin // Maximum signed value!
            lim_d[OUTW-2:0] <= ~{(OUTW-1){signal_d[INW-1]}};
        end
    end
end

end // if ( ATTENUATION )
endgenerate

endmodule // limiter
