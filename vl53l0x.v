module vl53l0x #(
    parameter integer CLK_FREQ = 50_000_000
)(
    input  wire       clk,
    input  wire       rst,

    output reg        i2c_cmd_valid,
    output reg        i2c_cmd_read,
    output reg [6:0]  i2c_cmd_addr,
    output reg [7:0]  i2c_cmd_reg,
    output reg [7:0]  i2c_cmd_wdata,
    input  wire       i2c_busy,
    input  wire       i2c_done,
    input  wire       i2c_ack_error,
    input  wire [7:0] i2c_rdata,

    output reg [15:0] distance_mm,
    output reg        valid,
    output reg        error
);

    localparam [6:0] DEV_ADDR = 7'h29;

    // Default tuning sequence used by common VL53L0X drivers.
    localparam integer N_TUNE = 76;
    reg [7:0] tune_reg [0:N_TUNE-1];
    reg [7:0] tune_val [0:N_TUNE-1];

    integer k;
    initial begin
        // index: register, value
        tune_reg[0]=8'hFF; tune_val[0]=8'h01;
        tune_reg[1]=8'h00; tune_val[1]=8'h00;
        tune_reg[2]=8'hFF; tune_val[2]=8'h00;
        tune_reg[3]=8'h09; tune_val[3]=8'h00;
        tune_reg[4]=8'h10; tune_val[4]=8'h00;
        tune_reg[5]=8'h11; tune_val[5]=8'h00;
        tune_reg[6]=8'h24; tune_val[6]=8'h01;
        tune_reg[7]=8'h25; tune_val[7]=8'hFF;
        tune_reg[8]=8'h75; tune_val[8]=8'h00;
        tune_reg[9]=8'hFF; tune_val[9]=8'h01;
        tune_reg[10]=8'h4E; tune_val[10]=8'h2C;
        tune_reg[11]=8'h48; tune_val[11]=8'h00;
        tune_reg[12]=8'h30; tune_val[12]=8'h20;
        tune_reg[13]=8'hFF; tune_val[13]=8'h00;
        tune_reg[14]=8'h30; tune_val[14]=8'h09;
        tune_reg[15]=8'h54; tune_val[15]=8'h00;
        tune_reg[16]=8'h31; tune_val[16]=8'h04;
        tune_reg[17]=8'h32; tune_val[17]=8'h03;
        tune_reg[18]=8'h40; tune_val[18]=8'h83;
        tune_reg[19]=8'h46; tune_val[19]=8'h25;
        tune_reg[20]=8'h60; tune_val[20]=8'h00;
        tune_reg[21]=8'h27; tune_val[21]=8'h00;
        tune_reg[22]=8'h50; tune_val[22]=8'h06;
        tune_reg[23]=8'h51; tune_val[23]=8'h00;
        tune_reg[24]=8'h52; tune_val[24]=8'h96;
        tune_reg[25]=8'h56; tune_val[25]=8'h08;
        tune_reg[26]=8'h57; tune_val[26]=8'h30;
        tune_reg[27]=8'h61; tune_val[27]=8'h00;
        tune_reg[28]=8'h62; tune_val[28]=8'h00;
        tune_reg[29]=8'h64; tune_val[29]=8'h00;
        tune_reg[30]=8'h65; tune_val[30]=8'h00;
        tune_reg[31]=8'h66; tune_val[31]=8'hA0;
        tune_reg[32]=8'hFF; tune_val[32]=8'h01;
        tune_reg[33]=8'h22; tune_val[33]=8'h32;
        tune_reg[34]=8'h47; tune_val[34]=8'h14;
        tune_reg[35]=8'h49; tune_val[35]=8'hFF;
        tune_reg[36]=8'h4A; tune_val[36]=8'h00;
        tune_reg[37]=8'hFF; tune_val[37]=8'h00;
        tune_reg[38]=8'h7A; tune_val[38]=8'h0A;
        tune_reg[39]=8'h7B; tune_val[39]=8'h00;
        tune_reg[40]=8'h78; tune_val[40]=8'h21;
        tune_reg[41]=8'hFF; tune_val[41]=8'h01;
        tune_reg[42]=8'h23; tune_val[42]=8'h34;
        tune_reg[43]=8'h42; tune_val[43]=8'h00;
        tune_reg[44]=8'h44; tune_val[44]=8'hFF;
        tune_reg[45]=8'h45; tune_val[45]=8'h26;
        tune_reg[46]=8'h46; tune_val[46]=8'h05;
        tune_reg[47]=8'h40; tune_val[47]=8'h40;
        tune_reg[48]=8'h0E; tune_val[48]=8'h06;
        tune_reg[49]=8'h20; tune_val[49]=8'h1A;
        tune_reg[50]=8'h43; tune_val[50]=8'h40;
        tune_reg[51]=8'hFF; tune_val[51]=8'h00;
        tune_reg[52]=8'h34; tune_val[52]=8'h03;
        tune_reg[53]=8'h35; tune_val[53]=8'h44;
        tune_reg[54]=8'hFF; tune_val[54]=8'h01;
        tune_reg[55]=8'h31; tune_val[55]=8'h04;
        tune_reg[56]=8'h4B; tune_val[56]=8'h09;
        tune_reg[57]=8'h4C; tune_val[57]=8'h05;
        tune_reg[58]=8'h4D; tune_val[58]=8'h04;
        tune_reg[59]=8'hFF; tune_val[59]=8'h00;
        tune_reg[60]=8'h44; tune_val[60]=8'h00;
        tune_reg[61]=8'h45; tune_val[61]=8'h20;
        tune_reg[62]=8'h47; tune_val[62]=8'h08;
        tune_reg[63]=8'h48; tune_val[63]=8'h28;
        tune_reg[64]=8'h67; tune_val[64]=8'h00;
        tune_reg[65]=8'h70; tune_val[65]=8'h04;
        tune_reg[66]=8'h71; tune_val[66]=8'h01;
        tune_reg[67]=8'h72; tune_val[67]=8'hFE;
        tune_reg[68]=8'h76; tune_val[68]=8'h00;
        tune_reg[69]=8'h77; tune_val[69]=8'h00;
        tune_reg[70]=8'hFF; tune_val[70]=8'h01;
        tune_reg[71]=8'h0D; tune_val[71]=8'h01;
        tune_reg[72]=8'hFF; tune_val[72]=8'h00;
        tune_reg[73]=8'h80; tune_val[73]=8'h01;
        tune_reg[74]=8'h01; tune_val[74]=8'hF8;
        tune_reg[75]=8'hFF; tune_val[75]=8'h00;
    end

    localparam integer DLY_100MS = CLK_FREQ/10;
    reg [31:0] delay_cnt;

    localparam [5:0]
        S_BOOT      = 0,
        S_ID_CMD    = 1,
        S_ID_WAIT   = 2,
        S_BASE0     = 3,
        S_BASE1     = 4,
        S_BASE2     = 5,
        S_BASE3     = 6,
        S_STOP_RD   = 7,
        S_STOP_WAIT = 8,
        S_BASE4     = 9,
        S_BASE5     = 10,
        S_BASE6     = 11,
        S_TUNE_CMD  = 12,
        S_TUNE_WAIT = 13,
        S_CFG0      = 14,
        S_CFG1      = 15,
        S_CFG2      = 16,
        S_CFG3      = 17,
        S_CFG4      = 18,
        S_CFG5      = 19,
        S_CAL0      = 20,
        S_CAL0_WAIT = 21,
        S_CAL1      = 22,
        S_CAL1_WAIT = 23,
        S_RUN_PRE0  = 24,
        S_RUN_PRE1  = 25,
        S_RUN_PRE2  = 26,
        S_RUN_PRE3  = 27,
        S_START     = 28,
        S_START_WAIT= 29,
        S_STATUS    = 30,
        S_STATUS_W  = 31,
        S_RANGE_H   = 32,
        S_RANGE_HW  = 33,
        S_RANGE_L   = 34,
        S_RANGE_LW  = 35,
        S_CLEAR     = 36,
        S_CLEAR_W   = 37,
        S_RESTART   = 38,
        S_RESTART_W = 39,
        S_ERROR     = 40;

    reg [5:0] state;
    reg [7:0] stop_variable;
    reg [7:0] msb_range;
    reg [7:0] status_byte;
    reg [7:0] tune_index;

    task automatic issue_write(input [7:0] rr, input [7:0] vv);
    begin
        i2c_cmd_valid <= 1'b1;
        i2c_cmd_read  <= 1'b0;
        i2c_cmd_addr  <= DEV_ADDR;
        i2c_cmd_reg   <= rr;
        i2c_cmd_wdata <= vv;
    end
    endtask

    task automatic issue_read(input [7:0] rr);
    begin
        i2c_cmd_valid <= 1'b1;
        i2c_cmd_read  <= 1'b1;
        i2c_cmd_addr  <= DEV_ADDR;
        i2c_cmd_reg   <= rr;
        i2c_cmd_wdata <= 8'h00;
    end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            i2c_cmd_valid <= 0;
            i2c_cmd_read  <= 0;
            i2c_cmd_addr  <= DEV_ADDR;
            i2c_cmd_reg   <= 0;
            i2c_cmd_wdata <= 0;
            distance_mm  <= 0;
            valid        <= 0;
            error        <= 0;
            state        <= S_BOOT;
            delay_cnt    <= 0;
            tune_index   <= 0;
            stop_variable<= 8'h3C;
        end else begin
            i2c_cmd_valid <= 1'b0;
            valid <= 1'b0;

            case (state)
                S_BOOT: begin
                    if (delay_cnt < DLY_100MS) delay_cnt <= delay_cnt + 1;
                    else begin
                        delay_cnt <= 0;
                        state <= S_ID_CMD;
                    end
                end

                S_ID_CMD: begin
                    if (!i2c_busy) begin issue_read(8'hC0); state <= S_ID_WAIT; end
                end
                S_ID_WAIT: if (i2c_done) begin
                    if (i2c_ack_error || i2c_rdata != 8'hEE) begin error<=1; state<=S_ERROR; end
                    else state<=S_BASE0;
                end

                // DataInit sequence.
                S_BASE0: if(!i2c_busy) begin issue_write(8'h88,8'h00); state<=S_BASE1; end
                S_BASE1: if(!i2c_busy) begin issue_write(8'h80,8'h01); state<=S_BASE2; end
                S_BASE2: if(!i2c_busy) begin issue_write(8'hFF,8'h01); state<=S_BASE3; end
                S_BASE3: if(!i2c_busy) begin issue_write(8'h00,8'h00); state<=S_STOP_RD; end
                S_STOP_RD: if(!i2c_busy) begin issue_read(8'h91); state<=S_STOP_WAIT; end
                S_STOP_WAIT: if(i2c_done) begin
                    if(i2c_ack_error) begin error<=1; state<=S_ERROR; end
                    else begin stop_variable<=i2c_rdata; state<=S_BASE4; end
                end
                S_BASE4: if(!i2c_busy) begin issue_write(8'h00,8'h01); state<=S_BASE5; end
                S_BASE5: if(!i2c_busy) begin issue_write(8'hFF,8'h00); state<=S_BASE6; end
                S_BASE6: if(!i2c_busy) begin issue_write(8'h80,8'h00); state<=S_TUNE_CMD; tune_index<=0; end

                S_TUNE_CMD: begin
                    if(!i2c_busy) begin
                        issue_write(tune_reg[tune_index], tune_val[tune_index]);
                        state <= S_TUNE_WAIT;
                    end
                end
                S_TUNE_WAIT: if(i2c_done) begin
                    if(i2c_ack_error) begin error<=1; state<=S_ERROR; end
                    else if(tune_index == N_TUNE-1) state<=S_CFG0;
                    else begin tune_index<=tune_index+1'b1; state<=S_TUNE_CMD; end
                end

                // New-sample interrupt and sequence configuration.
                S_CFG0: if(!i2c_busy) begin issue_write(8'h0A,8'h04); state<=S_CFG1; end
                S_CFG1: if(!i2c_busy) begin issue_write(8'h0B,8'h01); state<=S_CFG2; end
                S_CFG2: if(!i2c_busy) begin issue_write(8'h01,8'hE8); state<=S_CFG3; end
                // Restore stop variable into private state.
                S_CFG3: if(!i2c_busy) begin issue_write(8'h80,8'h01); state<=S_CFG4; end
                S_CFG4: if(!i2c_busy) begin issue_write(8'hFF,8'h01); state<=S_CFG5; end
                S_CFG5: if(!i2c_busy) begin issue_write(8'h00,8'h00); state<=S_RUN_PRE0; end
                S_RUN_PRE0: if(!i2c_busy) begin issue_write(8'h91,stop_variable); state<=S_RUN_PRE1; end
                S_RUN_PRE1: if(!i2c_busy) begin issue_write(8'h00,8'h01); state<=S_RUN_PRE2; end
                S_RUN_PRE2: if(!i2c_busy) begin issue_write(8'hFF,8'h00); state<=S_RUN_PRE3; end
                S_RUN_PRE3: if(!i2c_busy) begin issue_write(8'h80,8'h00); state<=S_CAL0; end

                // Start continuous back-to-back ranging.
                // The tuning sequence leaves the device in normal register context.
                S_CAL0: if(!i2c_busy) begin issue_write(8'h00,8'h02); state<=S_CAL0_WAIT; end
                S_CAL0_WAIT: if(i2c_done) begin
                    if(i2c_ack_error) begin error<=1; state<=S_ERROR; end
                    else state<=S_STATUS;
                end

                // Poll data-ready.
                S_STATUS: if(!i2c_busy) begin issue_read(8'h13); state<=S_STATUS_W; end
                S_STATUS_W: if(i2c_done) begin
                    if(i2c_ack_error) begin error<=1; state<=S_ERROR; end
                    else if((i2c_rdata & 8'h07)!=0) state<=S_RANGE_H;
                    else state<=S_STATUS;
                end

                S_RANGE_H: if(!i2c_busy) begin issue_read(8'h1E); state<=S_RANGE_HW; end
                S_RANGE_HW: if(i2c_done) begin
                    if(i2c_ack_error) begin error<=1; state<=S_ERROR; end
                    else begin msb_range<=i2c_rdata; state<=S_RANGE_L; end
                end
                S_RANGE_L: if(!i2c_busy) begin issue_read(8'h1F); state<=S_RANGE_LW; end
                S_RANGE_LW: if(i2c_done) begin
                    if(i2c_ack_error) begin error<=1; state<=S_ERROR; end
                    else begin
                        distance_mm <= {msb_range,i2c_rdata};
                        valid <= 1'b1;
                        state <= S_CLEAR;
                    end
                end
                S_CLEAR: if(!i2c_busy) begin issue_write(8'h0B,8'h01); state<=S_CLEAR_W; end
                S_CLEAR_W: if(i2c_done) begin
                    if(i2c_ack_error) begin error<=1; state<=S_ERROR; end
                    else state<=S_STATUS;
                end

                S_ERROR: begin
                    // Stay here until external reset.
                    state <= S_ERROR;
                end
                default: state <= S_ERROR;
            endcase
        end
    end
endmodule
