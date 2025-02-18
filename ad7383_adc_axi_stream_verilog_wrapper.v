`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/14/2025 10:34:52 AM
// Design Name: 
// Module Name: ad7383_adc_axi_stream_verilog_wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ad7383_adc_axi_stream_verilog_wrapper #(
    parameter   ADC_CLK_FREQ    = 50_000_000,
    parameter   SAMPLE_RATE     = 2_500_000
    ) (
    input               ACLK,
    input               ARESETN,
    input               M_AXIS_TREADY,
    output [31:0]   M_AXIS_TDATA,
    output              M_AXIS_TVALID,
    output              M_AXIS_TLAST,

    output              adc_ready_o,
    input               adc_clk_i,
    input               init_i,

    input               adc_sdiA_i,
    input               adc_sdiB_i,
    output              adc_cs_o,
    output              adc_sclk_o,
    output              adc_sdo_o
    );
    
    wire [15:0]   adc_dataA, adc_dataB;
    wire   adc_valid;
    
    ad7383_adc_axi_stream_interface axi_stream_interface(
        .ACLK           (   ACLK            ),
        .ARESETN        (   ARESETN         ),
        .M_AXIS_TREADY  (   M_AXIS_TREADY   ),
        .M_AXIS_TDATA   (   M_AXIS_TDATA    ),
        .M_AXIS_TVALID  (   M_AXIS_TVALID   ),
        .M_AXIS_TLAST   (   M_AXIS_TLAST    ),
        .dataA_i        (   adc_dataA       ),
        .dataB_i        (   adc_dataB       ),
        .adc_valid_i    (   adc_valid       )      
    );      
    
    ad7383_adc_interface #(.CLK_FREQ(ADC_CLK_FREQ), .SAMPLE_RATE(SAMPLE_RATE) ) adc_interface(
        .clk_i          (   adc_clk_i   ),
        .rst_i          (   !ARESETN    ),
        .init_i         (   init_i      ),
        .ready_o        (   adc_ready_o ),
        .dataA_o        (   adc_dataA   ),
        .dataB_o        (   adc_dataB   ),
        .valid_o        (   adc_valid   ),
        .sdiA_i         (   adc_sdiA_i  ),
        .sdiB_i         (   adc_sdiB_i  ),
        .cs_o           (   adc_cs_o    ),
        .sclk_o         (   adc_sclk_o  ),   ////testing
        .sdo_o          (   adc_sdo_o   )
    );    
    
endmodule
