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

module interpolator_tb;

localparam NR_CHANNELS = 3;
localparam INPUT_WIDTH = 24;
localparam FRACTION_WIDTH = 32;

localparam
    INW   = INPUT_WIDTH, // Input  width
    OUTW  = INPUT_WIDTH, // Output width
    CHW   = $clog2( NR_CHANNELS ), // Channel width
    CHN   = NR_CHANNELS, // Number of channels
    CNTRW = FRACTION_WIDTH; // Fraction and counter width

reg clk = 0;
reg rst_n = 0; // Synchronous reset, high when clk is stable!

wire [INW-1:0]   s_intrp_d;
wire [CHW-1:0]   s_intrp_ch;
wire             s_intrp_dv;
wire             s_intrp1_dr;
reg  [CNTRW-1:0] fraction; // 1.CNTRW-1 fraction value
wire [OUTW-1:0]  m_intrp1_d;
wire [CHW-1:0]   m_intrp1_ch;
wire             m_intrp1_dv;
reg              m_intrp1_dr;
wire             overflow1;

interpolator intrp1(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(s_intrp_ch),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp1_dr),
    .fraction(fraction),
    .m_intrp_d(m_intrp1_d),
    .m_intrp_ch(m_intrp1_ch),
    .m_intrp_dv(m_intrp1_dv),
    .m_intrp_dr(m_intrp1_dr),
    .overflow(overflow1));

defparam intrp1.POLYNOMIAL = "3RD_ORDER";
defparam intrp1.NR_CHANNELS = NR_CHANNELS;
defparam intrp1.INPUT_WIDTH = INPUT_WIDTH;
defparam intrp1.FRACTION_WIDTH = FRACTION_WIDTH;

wire             s_intrp2_dr;
wire [OUTW-1:0]  m_intrp2_d;
wire             m_intrp2_dv;
reg              m_intrp2_dr;
wire             overflow2;

interpolator intrp2(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp2_dr),
    .fraction(fraction),
    .m_intrp_d(m_intrp2_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp2_dv),
    .m_intrp_dr(m_intrp2_dr),
    .overflow(overflow2));

defparam intrp2.POLYNOMIAL = "3RD_ORDER";
defparam intrp2.NR_CHANNELS = 1;
defparam intrp2.INPUT_WIDTH = INPUT_WIDTH;
defparam intrp2.FRACTION_WIDTH = FRACTION_WIDTH;

wire             s_intrp3_dr;
wire [OUTW-1:0]  m_intrp3_d;
wire             m_intrp3_dv;
reg              m_intrp3_dr;
wire             overflow3;

interpolator intrp3(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp3_dr),
    .fraction(fraction),
    .m_intrp_d(m_intrp3_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp3_dv),
    .m_intrp_dr(m_intrp3_dr),
    .overflow(overflow3));

defparam intrp3.POLYNOMIAL = "4TH_ORDER";
defparam intrp3.NR_CHANNELS = 1;
defparam intrp3.INPUT_WIDTH = INPUT_WIDTH;
defparam intrp3.FRACTION_WIDTH = FRACTION_WIDTH;

wire             s_intrp4_dr;
wire [OUTW-1:0]  m_intrp4_d;
wire             m_intrp4_dv;
reg              m_intrp4_dr;
wire             overflow4;

interpolator intrp4(
    .clk(clk),
    .rst_n(rst_n),
    .s_intrp_d(s_intrp_d),
    .s_intrp_ch(1'b0),
    .s_intrp_dv(s_intrp_dv),
    .s_intrp_dr(s_intrp4_dr),
    .fraction(fraction),
    .m_intrp_d(m_intrp4_d),
    .m_intrp_ch(),
    .m_intrp_dv(m_intrp4_dv),
    .m_intrp_dr(m_intrp4_dr),
    .overflow(overflow4));

defparam intrp4.POLYNOMIAL = "5TH_ORDER";
defparam intrp4.NR_CHANNELS = 1;
defparam intrp4.INPUT_WIDTH = INPUT_WIDTH;
defparam intrp4.FRACTION_WIDTH = FRACTION_WIDTH;

always #5 clk = ~clk; // 100 MHz clock

reg sg_enabled; // Sine generator
reg swg_enabled; // Sweep generator
reg mute;
reg pos_minus_6dB; // To test continuous DC -6dB positive value
reg neg_minus_6dB; // To test continuous DC -6dB negative value

/*============================================================================*/
initial begin
/*============================================================================*/
    rst_n = 0;
    m_intrp1_dr = 0;
    m_intrp2_dr = 0;
    m_intrp3_dr = 0;
    m_intrp4_dr = 0;
    fraction = 0;
    sg_enabled = 1;
    swg_enabled = 0;
    mute = 0;
    pos_minus_6dB = 1;
    neg_minus_6dB = 0;
    $display( "Interpolator simulation started" );
    #100 // 0.1us
    wait ( clk ) @( negedge clk );
    $display( "Sine generator enabled" );
    rst_n = 1;
    m_intrp1_dr = 1;
    fraction[CNTRW-2] = 1; // fraction = 0.5
    wait ( s_intrp_dv );
    wait ( !s_intrp1_dr );
    fraction = 0; // fraction = 0;
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    pos_minus_6dB = 0;
    neg_minus_6dB = 1;
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    wait ( !s_intrp1_dr ) @( negedge s_intrp1_dr );
    pos_minus_6dB = 0;
    neg_minus_6dB = 0;
    #100000 // 100us
    mute = 1;
    $display( "Mute" );
    #5000 // 5us
    m_intrp2_dr = 1;
    m_intrp3_dr = 1;
    m_intrp4_dr = 1;
    sg_enabled = 0;
    swg_enabled = 1;
    mute = 0;
    $display( "Sweep generator enabled" );
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
    if ( s_intrp_dv  ) begin
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
    if ( sg_enabled ) begin
        if ( m_intrp1_dv ) begin
            case ( m_intrp1_ch )
                0 : begin
                    data_intrp_out_0 <= m_intrp1_d;
                end
                1 : begin
                    data_intrp_out_1 <= m_intrp1_d;
                end
                2 : begin
                    data_intrp_out_2 <= m_intrp1_d;
                end
            endcase
        end
    end
    else begin
        if ( m_intrp2_dv ) begin
            data_intrp_out_0 <= m_intrp2_d;
        end
        if ( m_intrp3_dv ) begin
            data_intrp_out_1 <= m_intrp3_d;
        end
        if ( m_intrp4_dv ) begin
            data_intrp_out_2 <= m_intrp4_d;
        end
    end
end

////////////////// Sine generator for NR_CHANNELS-1 channels ///////////////////
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
        sg_dv <= sg_dv & ~s_intrp1_dr;
        if ( !sg_dv ) begin
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
        else if ( s_intrp1_dr && !( pos_minus_6dB || neg_minus_6dB )) begin
            sg_ch <= sg_ch + 1;
            if (( NR_CHANNELS - 1 ) == sg_ch ) begin
                sg_ch <= 0;
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
reg swg_dv = 0;

/*============================================================================*/
always @(posedge clk) begin : sweep_generator
/*============================================================================*/
    if ( swg_enabled ) begin
        if ( swg_step < NR_STEPS ) begin
            swg_dv <= swg_dv & ~( s_intrp2_dr & s_intrp3_dr & s_intrp4_dr );
            if ( !swg_dv ) begin
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
assign s_intrp_dv = sg_dv | ( swg_dv & s_intrp2_dr & s_intrp3_dr & s_intrp4_dr );

/*============================================================================*/
initial begin // Generate VCD file for GTKwave
/*============================================================================*/
`ifdef GTK_WAVE
    $dumpfile( "interpolator_tb.vcd" );
    $dumpvars( 0 );
`endif
end

endmodule
