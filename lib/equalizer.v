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
 *  The purpose of an equalizer is to amplify or attenuate (multiple) frequency
 *  bands. Based on IIR (cascaded) biquad normalized difference equation:
 *
 *      y(n) = b0x(n) + b1x(n-1) + b2x(n-2) - a1(y-1) - a2(y-2)
 *
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*============================================================================*/
module equalizer #(
/*============================================================================*/
    parameter NR_CHANNELS = 4,
    parameter INPUT_WIDTH = 24,
    parameter NR_EQ_BANDS = 8,
    parameter EQ_COEFF_WIDTH = 32,
    parameter EQ_HEADROOM_BITS = 6 )
    (
    clk, rst_n, // Synchronous reset, high when clk is stable!
    eq_coeff, eq_coeff_addr,
    s_tdata, s_tid, s_tvalid, s_tready,
    m_tdata, m_tid, m_tvalid, m_tready,
    overflow
    );

/*============================================================================*/
function integer clog2( input [63:0] value ); // Xilinx ISE verilog 2001 support has no $clog2
/*============================================================================*/
    reg [63:0] depth;
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

localparam NR_EQ_BAND_COEFF = 5; // A0, A1, A2, -B1 and -B2
localparam NR_EQ_COEFF = NR_CHANNELS * NR_EQ_BANDS * NR_EQ_BAND_COEFF;
localparam EQ_COEFF_ADDR_WIDTH = clog2( NR_EQ_COEFF );
localparam CHANNEL_WIDTH = clog2( NR_CHANNELS );

input  wire clk;
input  wire rst_n;
input  wire [EQ_COEFF_WIDTH-1:0] eq_coeff;
output wire [EQ_COEFF_ADDR_WIDTH-1:0] eq_coeff_addr;
input  wire [INPUT_WIDTH-1:0] s_tdata;
input  wire [CHANNEL_WIDTH-1:0] s_tid;
input  wire s_tvalid;
output wire s_tready;
output wire [INPUT_WIDTH-1:0] m_tdata;
output wire [CHANNEL_WIDTH-1:0] m_tid;
output wire m_tvalid;
input  wire m_tready;
output wire overflow;

// Feed forward coefficients
localparam A0 = 1;
localparam A1 = 2;
localparam A2 = 3; // Number of feed forward coefficients
// Feed backward coefficients
localparam B1 = 4;
localparam B2 = 5; // Number of band coefficients

localparam EQ_SAMPLE_WIDTH = EQ_COEFF_WIDTH;
localparam NR_EQ_BAND_ELEMENTS = ( A2 * ( NR_EQ_BANDS + 1 )); // +1 for last Y0, Y1, Y2
localparam NR_EQ_ELEMENTS = NR_CHANNELS * NR_EQ_BAND_ELEMENTS;
localparam NR_EQ_ELEMENTS_WIDTH = clog2( NR_EQ_ELEMENTS );

reg s_tready_i = 1;
reg [CHANNEL_WIDTH-1:0] i_tid = 0;
reg [EQ_COEFF_ADDR_WIDTH-1:0] i_eq_coeff_addr = 0;
reg [INPUT_WIDTH-1:0] m_tdata_i = 0;
reg [CHANNEL_WIDTH-1:0] m_tid_i = 0;
reg m_tvalid_i = 0;
reg overflow_i = 0;
reg out_tvalid_i = 0;
reg signed [EQ_SAMPLE_WIDTH-1:0] out_tdata_r = 0;
reg signed [EQ_SAMPLE_WIDTH-1:0] out_tdata_c = 0;
reg signed [EQ_SAMPLE_WIDTH-1:0] input_data = 0;
reg signed [EQ_SAMPLE_WIDTH-1:0] eq_ram_wr_data = 0;
reg signed [EQ_SAMPLE_WIDTH-1:0] eq_ram_rd_data = 0;
reg [NR_EQ_ELEMENTS_WIDTH-1:0] eq_ram_rd_index = 0;
reg [NR_EQ_ELEMENTS_WIDTH-1:0] eq_ram_wr_index = 0;
reg [NR_EQ_ELEMENTS_WIDTH-1:0] Y0_index = 0;
reg [NR_EQ_ELEMENTS_WIDTH-1:0] Y0_out_index = 0;
reg eq_ram_wr = 0;
reg init = 0;
reg first_iteration = 0;
reg store = 0;
reg store_and_shift = 0;
reg store_sum = 0;
reg calc_eq_band = 0;
reg multiply = 0;
reg accumulate = 0;
reg a0 = 0;
reg a1 = 0;
reg a2 = 0;
reg b1 = 0;
reg b2 = 0;
reg b2_done = 0;
reg signed [( 2 * EQ_COEFF_WIDTH )-1:0] sum = 0;
reg signed [( 2 * EQ_COEFF_WIDTH )-1:0] product = 0;
reg signed [EQ_SAMPLE_WIDTH-1:0] eq_ram[NR_EQ_ELEMENTS-1:0];

integer i = 0;

localparam NOISE_BITS = EQ_COEFF_WIDTH - INPUT_WIDTH-EQ_HEADROOM_BITS;
localparam COEFF_HEADROOM = 3; // coefficient gain range = -8.0 to 8.0 (3-bit headroom)
localparam EQ_SUM_HEADROOM = COEFF_HEADROOM + 1; // +1 for duplicate sign bit (signed multiplication)
localparam MAX_EQ_COEFF_WIDTH = 36;
localparam signed [MAX_EQ_COEFF_WIDTH-1:0] ALL_ZERO = 0; // 00000...
localparam signed [MAX_EQ_COEFF_WIDTH-1:0] ALL_ONES = -1; // 11111...

/*============================================================================*/
initial begin // Parameter checks
/*============================================================================*/
    if (( EQ_COEFF_WIDTH < INPUT_WIDTH ) || ( EQ_COEFF_WIDTH > MAX_EQ_COEFF_WIDTH )) begin
        $display( "EQ_COEFF_WIDTH error" );
        $stop;
    end
    if ( NOISE_BITS < 0 ) begin
        $display( "NOISE_BITS error" );
        $stop;
    end
end

/*============================================================================*/
initial begin // Initialize block RAM
/*============================================================================*/
    for ( i = 0; i < NR_EQ_ELEMENTS; i = i + 1 ) begin
        eq_ram[i] = 0;
    end
end

/*============================================================================*/
always @(posedge clk) begin : block_ram // Equalizer block RAM
/*============================================================================*/
    if ( eq_ram_wr ) begin
        eq_ram[eq_ram_wr_index] <= eq_ram_wr_data;
    end
    // Read-first mode
    eq_ram_rd_data <= eq_ram[eq_ram_rd_index];
end

/*============================================================================*/
always @(posedge clk) begin : biquad // Equalizer biquad algorithm
/*============================================================================*/
    // eq_ram_wr ... multiply are pulses - set to 1 for one clock cycle!
    eq_ram_wr <= 0;
    out_tvalid_i <= 0;
    b2_done <= 0;
    init <= 0;
    multiply <= 0;
    if ( s_tvalid && s_tready_i && ( s_tid < NR_CHANNELS )) begin
        // Fit AUDIO_WIDTH sample into EQ_COEFF_WIDTH equalizer sample
        input_data[EQ_COEFF_WIDTH-1:NOISE_BITS] <= $signed( s_tdata );
        input_data[NOISE_BITS-1:0] <= 0;
        i_tid <= s_tid;
        for ( i = 0; i < NR_CHANNELS; i = i + 1 )
            if ( i == s_tid ) begin
                i_eq_coeff_addr <= NR_EQ_BANDS * NR_EQ_BAND_COEFF * i;
                eq_ram_rd_index <= NR_EQ_BAND_ELEMENTS * i;
            end
        s_tready_i <= 0;
        init <= 1;
    end
    if ( init ) begin
        Y0_index <= eq_ram_rd_index;
        Y0_out_index <= eq_ram_rd_index + ( A2 * NR_EQ_BANDS );
        eq_ram_rd_index <= eq_ram_rd_index + 1;
        first_iteration <= 1;
    end
    store <= init;
    if ( store ) begin
        // Point to X0/Y0
        eq_ram_wr_index <= eq_ram_rd_index;
        eq_ram_wr_data <= eq_ram_rd_data;
        eq_ram_wr <= 1;
        if ( b2_done ) begin // Last band MAC operation done, rounding might cause negative sign could become positive!
            // EQ band sum 2*EQ_COEFF_WIDTH => EQ sample EQ_COEFF_WIDTH summed bands to zero rounding
            sum <= sum + {{( EQ_COEFF_WIDTH + EQ_SUM_HEADROOM ){1'b0}}, {( EQ_COEFF_WIDTH - EQ_SUM_HEADROOM ){ sum[( EQ_SAMPLE_WIDTH * 2 )-1] }}};
        end
    end
    store_and_shift <= store;
    if ( store_and_shift ) begin
        // X1/Y1 = X0/Y0
        eq_ram_wr_index <= eq_ram_wr_index + 1;
        eq_ram_wr_data <= eq_ram_rd_data;
        eq_ram_wr <= 1;
    end
    store_sum <= store_and_shift;
    if ( store_sum ) begin
        // X2/Y2 = X1/Y2
        eq_ram_rd_index <= Y0_index; // Point again to X0/Y0
        eq_ram_wr_index <= Y0_index;
        eq_ram_wr_data[EQ_SAMPLE_WIDTH-1] <= sum[( EQ_SAMPLE_WIDTH * 2 )-1]; // Copy sign bit and normalize
        // Check for positive and negative overflow
        if ( !sum[( EQ_SAMPLE_WIDTH * 2 )-1] && ( sum[(( EQ_SAMPLE_WIDTH * 2 )- 2 ):( EQ_SAMPLE_WIDTH * 2) - EQ_SUM_HEADROOM - 1] != ALL_ZERO[EQ_SUM_HEADROOM-1:0])) begin
            eq_ram_wr_data[EQ_SAMPLE_WIDTH-2:0] <= ALL_ONES; // Positive maximum
        end
        else if ( sum[( EQ_SAMPLE_WIDTH * 2 )-1] && ( sum[(( EQ_SAMPLE_WIDTH * 2 ) - 2 ):( EQ_SAMPLE_WIDTH * 2 ) - EQ_SUM_HEADROOM - 1] != ALL_ONES[EQ_SUM_HEADROOM-1:0])) begin
            eq_ram_wr_data[EQ_SAMPLE_WIDTH-2:0] <= ALL_ZERO; // Negative maximum
        end
        else begin
            eq_ram_wr_data[EQ_SAMPLE_WIDTH-2:0] <= sum[(( EQ_SAMPLE_WIDTH * 2 ) - EQ_SUM_HEADROOM - 2 ):( EQ_SAMPLE_WIDTH-EQ_SUM_HEADROOM )];
        end
        if ( first_iteration ) begin // First iteration after s_tvalid event
            eq_ram_wr_data <= input_data; // Copy input sample
            first_iteration <= 0;
        end
        eq_ram_wr <= 1;
    end
    calc_eq_band <= store_sum;
    if ( calc_eq_band ) begin
        Y0_index <= Y0_index + A2; // Point to X0/Y0 (next) band
        sum <= 0;
        if ( eq_ram_rd_index == Y0_out_index ) begin
            out_tdata_r <= eq_ram_wr_data;
            m_tid_i <= i_tid;
            out_tvalid_i <= 1;
            s_tready_i <= 1;
        end
        else begin
            multiply <= 1;
            a0 <= 1;
            eq_ram_rd_index <= eq_ram_rd_index + 1;
        end
    end
    if ( multiply ) begin
        if ( i_eq_coeff_addr != ( NR_EQ_COEFF - 1 )) begin
            i_eq_coeff_addr <= i_eq_coeff_addr + 1;
        end
        product <= $signed( eq_coeff ) * eq_ram_wr_data; // Multiply
        if ( b2 ) begin // All band coefficients processed
            eq_ram_rd_index <= Y0_index; // Point to X0/Y0 (= Y0 previous sample = Y1!)
        end
        else begin
            eq_ram_rd_index <= eq_ram_rd_index + 1;
    end
    end
    accumulate <= multiply;
    if ( accumulate ) begin
        sum <= sum + product; // Accumulate
        eq_ram_wr_data <= eq_ram_rd_data; // Get next X/Y sample
        if ( b2 ) begin
            eq_ram_rd_index <= eq_ram_rd_index + 1;
            store <= 1;
        end
        else begin
            multiply <= 1;
        end
        a0 <= 0; // Reset calc_eq_band assignment!
        a1 <= a0;
        a2 <= a1;
        b1 <= a2;
        b2 <= b1;
        b2_done <= b2;
    end
    // Reset
    if ( !rst_n ) begin
        init <= 0;
        store <= 0;
        store_and_shift <= 0;
        store_sum <= 0;
        calc_eq_band <= 0;
        multiply <= 0;
        accumulate <= 0;
        s_tready_i <= 1;
        m_tdata_i <= 0;
        m_tid_i <= 0;
        sum <= 0;
    end
end

/*============================================================================*/
always @(posedge clk) begin : output_process // Equalizer output, check for overflow and rounding
/*============================================================================*/
    m_tvalid_i <= m_tvalid_i & ~m_tready;
    overflow_i <= out_tvalid_i;
    if ( out_tvalid_i ) begin
        // EQ_SAMPLE_WIDTH => INPUT_WIDTH to zero rounding, negative sign could become positive!
        out_tdata_c = out_tdata_r + {{( EQ_COEFF_WIDTH - INPUT_WIDTH ){1'b0}}, {( NOISE_BITS ){ out_tdata_r[EQ_SAMPLE_WIDTH-1] }}};
        m_tdata_i[INPUT_WIDTH-1] <= out_tdata_c[EQ_SAMPLE_WIDTH-1]; // Sign bit
        // Check for positive and negative overflow
        if ( !out_tdata_c[EQ_SAMPLE_WIDTH-1] && out_tdata_c[EQ_SAMPLE_WIDTH-2:EQ_SAMPLE_WIDTH-EQ_HEADROOM_BITS-1] != ALL_ZERO[EQ_HEADROOM_BITS-1:0] ) begin
            m_tdata_i[INPUT_WIDTH-2:0] <= ALL_ONES; // Positive maximum
        end
        else if ( out_tdata_c[EQ_SAMPLE_WIDTH-1] && out_tdata_c[EQ_SAMPLE_WIDTH-2:EQ_SAMPLE_WIDTH-EQ_HEADROOM_BITS-1] != ALL_ONES[EQ_HEADROOM_BITS-1:0] ) begin
            m_tdata_i[INPUT_WIDTH-2:0] <= ALL_ZERO; // Negative maximum
        end
        else begin
            m_tdata_i[INPUT_WIDTH-2:0] <= out_tdata_c[EQ_SAMPLE_WIDTH-EQ_HEADROOM_BITS-2:NOISE_BITS];
            overflow_i <= 0;
        end
        m_tvalid_i <= 1;
    end
end

assign s_tready = rst_n & s_tready_i;
assign eq_coeff_addr = i_eq_coeff_addr;
assign m_tdata = m_tdata_i;
assign m_tid = m_tid_i;
assign m_tvalid = m_tvalid_i;
assign overflow = overflow_i;

endmodule
