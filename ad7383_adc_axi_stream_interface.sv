`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/19/2024 01:36:05 PM
// Design Name: 
// Module Name: ad7383_adc_axi_stream_wrapper
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


module ad7383_adc_axi_stream_interface(
    input               ACLK,
    input               ARESETN,
    input               M_AXIS_TREADY,

    output logic [31:0] M_AXIS_TDATA,
    output              M_AXIS_TVALID,
    output              M_AXIS_TLAST,
    
    input logic [15:0]  dataA_i,
    input logic [15:0]  dataB_i,
    input               adc_valid_i
    );
    
    logic [31:0]            adc_data_axi;
    assign M_AXIS_TDATA =   adc_data_axi;
    
    logic                   axi_valid;
    logic                   axi_last;
    assign M_AXIS_TVALID =  axi_valid; // DBT:Changed this from assigning M_AXIS_TREADY to assigning M_AXIS_TVALID. TREADY should come from slave data receiver. Want TVALID to go to slave when adc has valid data.
    assign M_AXIS_TLAST  =  axi_last;
    
    //clock-domain crossing synchronization
    logic [15:0]    dataA_buf       [2];
    logic [15:0]    dataB_buf       [2];
    logic           adc_valid_buf   [2];
    
    always_ff @(posedge ACLK) begin
        dataA_buf[0]        <= dataA_i;
        dataB_buf[0]        <= dataB_i;
        adc_valid_buf[0]    <= adc_valid_i;
        
        dataA_buf[1]        <= dataA_buf[0];
        dataB_buf[1]        <= dataB_buf[0];
        adc_valid_buf[1]    <= adc_valid_buf[0];
    end
    
    always_ff @(posedge ACLK) begin
        if(!ARESETN)                            axi_valid <= 0;
        else if(M_AXIS_TREADY || !adc_valid_i) begin // DBT: 
                                                axi_valid <= adc_valid_buf[1]; //update the valid signal if the receiver was ready or if the valid signal is deasserted
                                                axi_last  <= adc_valid_buf[1]; //packets are coming so slowly that each will be a single data point and can just tie valid and last together
        end
    end
        
    always_ff @(posedge ACLK) begin
        if(!ARESETN)                            adc_data_axi <= '0;
        else if(M_AXIS_TREADY && axi_valid)    adc_data_axi <= {dataA_buf[1], dataB_buf[1]}; //update with concatenation of A and B data channels
    end
    
    
    
    
endmodule
