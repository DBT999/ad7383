`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/13/2024 01:08:38 PM
// Design Name: 
// Module Name: ad7383_adc_interface
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

//whole module needs to feed into a FIFO for master system, needs dedicated 80MHz clock

module ad7383_adc_interface #(
    parameter   CLK_FREQ        = 80_000_000,
    parameter   SAMPLE_RATE     = 4_000_000 //sample rate of the ADC
    ) (
    
    input               clk_i,
    input               rst_i,
          
    input               init_i,         //request to initialize ADC
    output              ready_o,        //ADC is initialized
    
    output logic [15:0] dataA_o,
    output logic [15:0] dataB_o,
    
    output logic        valid_o,
    
    input               sdiA_i, //serial data signals from chip
    input               sdiB_i,
    
    output              cs_o,    
    output              sclk_o,
    output              sdo_o, //data signal to chip
    
    input               debug_clk

    );
    
    //SPI clock needs to be gated by the other signals, but will ultimately be the same as the other device clocks, so no need for oversampling or edge detection  
    logic clk;
    assign clk = clk_i;  //basic signal renaming, port name is a clue to restrict input clock appropriately, internal clock name shorter for readibility
    
    logic cs, sclk, data_valid;
    logic [15:0] dataA_reg;
    logic [15:0] dataB_reg;
    logic [15:0] sdata_reg; //register for output data (commands)
    
    assign cs_o = cs;
    assign sclk_o = sclk;
    assign sdo_o = sdata_reg[15];
    
    assign dataA_o = dataA_reg;
    assign dataB_o = dataB_reg;
    
    assign valid_o = data_valid;
    
    assign sclk = clk | cs; //when chip select is high, sclk should be held high, when low, should be in time with clk, because cs is in sync with clk, this should result in a falling edge being first after the chip select, with a one half period time between
    
    localparam CLOCKS_PER_SAMPLE = CLK_FREQ / SAMPLE_RATE; //number of clock cylces that represent a single sample, for 4 MSa/s, this is 250ns per sample, 250ns is 20 clocks per sample for 80 MHz master clock
    
    logic [$clog2(CLOCKS_PER_SAMPLE)-1:0]   frame_timer; //register for timing the sample requests, also used for counting the bits received/sent
    
    localparam logic [15:0] WRITE_CMD_TEMPLATE   = {1'b1,3'b000,12'h000}; //first bit is set to initiate write command, next three bits are address of register, remaining 12 are contents
    localparam logic [15:0] READ_CMD_TEMPLATE    = {1'b0,3'b000,12'h000}; //first bit is reset to initiate read command, next three bits are address of register
    
    localparam logic [15:0] READ_HIGH_THRESH     = {1'b0,3'b101,12'h000}; //read the high threashold alert register, its reset value is 0x07FF, so good for testing initialization
    localparam logic [15:0] READ_LOW_THRESH      = {1'b0,3'b100,12'h000}; //read the low threashold alert register, its reset value is 0x0800, so good for testing initialization
    
    localparam logic [15:0] READ_ALERT_REG       = {1'b0,3'b011,12'h000}; //read the alert register for any set up issues
    
    localparam logic [15:0] NOP_CMD              = {1'b0,3'b000,12'h000}; //set to a read command, but address is 0x0, 0x6, or 0x7 therefore normal conversion readback is the result on next cycle
    localparam logic [15:0] READ_REG_1           = {1'b0,3'b001,12'h000}; //read the contents of CONFIGURATION1
    localparam logic [15:0] READ_REG_2           = {1'b0,3'b010,12'h000}; //read the contents of CONFIGURATION2
    localparam logic [15:0] WRITE_REG_1          = {1'b1,3'b001,12'b00_1_000_0_0_0_0_1_0}; //initial write command to CONFIGURATION1
    //                                                 |     |       | |  |  | | | | | | 
    //                                                 |     |       | |  |  | | | | | |--- normal mode, not shutdown
    //                              write register  ---|     |       | |  |  | | | | |--- select external ADC reference
    //                           CONFIGURATRION1 address  ---|       | |  |  | | | |--- normal resolution
    //                                              reserved bits ---| |  |  | | |--- alert enable 0 means that SDOB is used, and the alert function isn't
    //                                           oversampling mode  ---|  |  | |--- CRC Read disabled 
    //                                              oversampling ratio ---|  |--- CRC write disabled 
    localparam logic [15:0] SOFT_RESET           = {1'b1,3'b010,12'b000_0_0011_1100}; //write soft reset vector to CONFIGURATION2
    localparam logic [15:0] CLEAR_RESET          = {1'b1,3'b010,12'b000_0_0000_0000};
    
    logic readback_valid; //check if contents of readback register is equal to the contents it should be
    
    assign readback_valid = dataA_reg == (WRITE_REG_1 & 16'h0FFF);
    
    typedef enum
        {   Idle,
            SoftReset,
            ClearReset,
            Init,
            Readback,
            CheckReg,
            Sample  }   state_e;    
    (* mark_debug = "true" *)/*(* fsm_encoding ="auto" *)*/  state_e state, next;
    
    always_comb
        case(state)
            Idle:           if(init_i)                                      next = SoftReset;
                            else                                            next = Idle;
            SoftReset:      if(frame_timer == CLOCKS_PER_SAMPLE-1)          next = ClearReset;
                            else                                            next = SoftReset;  
            ClearReset:     if(frame_timer == CLOCKS_PER_SAMPLE-1)          next = Init;
                            else                                            next = ClearReset;              
            Init:           if(frame_timer == CLOCKS_PER_SAMPLE-1)          next = Readback;         
                            else                                            next = Init;
            Readback:       if(frame_timer == CLOCKS_PER_SAMPLE-1)          next = CheckReg;
                            else                                            next = Readback;
            CheckReg:       if(frame_timer == CLOCKS_PER_SAMPLE-1)
                                if(readback_valid)                          next = Sample;
                                else                                        next = SoftReset;
                            else                                            next = CheckReg;
            Sample:                                                         next = Sample;
            default:                                                        next = Idle;
        endcase
    
    assign ready_o = state == Sample;
    
    assign cs =     (state == Idle) ||         //assignment of chip select signal, want it to be high when Idle
                    (frame_timer >= 16 ) ;      //also want it to be high when the frame timer is waiting for next frame, but after bits have been accounted for
            
    always_ff @(posedge clk) begin
        if(state == Idle)                                   sdata_reg <= SOFT_RESET;
        else 
            if(frame_timer == CLOCKS_PER_SAMPLE-1)
                //sdata_reg <= READ_REG_1_;
                case(next)
                    Idle:                                   sdata_reg <= SOFT_RESET;
                    SoftReset:                              sdata_reg <= SOFT_RESET;
                    ClearReset:                             sdata_reg <= CLEAR_RESET;
                    Init:                                   sdata_reg <= WRITE_REG_1;
                    Readback:                               sdata_reg <= READ_REG_1;
                    CheckReg:                               sdata_reg <= NOP_CMD;
                    Sample:                                 sdata_reg <= NOP_CMD;
                    default:                                sdata_reg <= READ_REG_1;

                endcase
            else                                            sdata_reg <= sdata_reg << 1;
    end
            
    always_ff @(posedge clk)
        if(state == Idle) begin
              dataA_reg <= '0;
              dataB_reg <= '0;
        end
        else if(~cs) begin
            dataA_reg <= {dataA_reg, sdiA_i};
            dataB_reg <= {dataB_reg, sdiB_i};
        end
    
    always_ff @(posedge clk)
        if(ready_o) begin
            if(frame_timer == 16)                           data_valid <= 1;   //strobe data valid when last bit is clocked in
            else                                            data_valid <= 0;  
        end
        else                                                data_valid <= 0;   //data should not be marked valid if ADC isn't initialized   
    
    always_ff @(posedge clk)
        if(state == Idle)                               frame_timer <= '0;
        else if(frame_timer == CLOCKS_PER_SAMPLE-1)     frame_timer <= '0;
        else                                            frame_timer <= frame_timer + 1'b1;
    
    always_ff @(posedge clk)
        if(rst_i)   state <= Idle;
        else        state <= next;
    
    
endmodule
