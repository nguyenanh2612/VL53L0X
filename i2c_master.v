module i2c_master #(
    parameter integer CLK_FREQ = 50_000_000,
    parameter integer I2C_FREQ = 100_000
)(
    input  wire       clk,
    input  wire       rst,

    input  wire       cmd_valid,
    input  wire       cmd_read,
    input  wire [6:0] cmd_addr,
    input  wire [7:0] cmd_reg,
    input  wire [7:0] cmd_wdata,

    output reg        busy,
    output reg        done,
    output reg        ack_error,
    output reg [7:0]  rdata,

    inout  wire       sda,
    output wire       scl
);

    localparam integer DIVIDER = CLK_FREQ/(I2C_FREQ*2);

    reg [15:0] divcnt;
    wire tick = (divcnt == DIVIDER-1);

    always @(posedge clk) begin
        if (rst) divcnt <= 0;
        else if (tick) divcnt <= 0;
        else divcnt <= divcnt + 1'b1;
    end

    // Open-drain SDA: drive 0 or release. External pull-up is required.
    reg sda_oe;
    reg sda_do;
    assign sda = (sda_oe && !sda_do) ? 1'b0 : 1'bz;

    reg scl_r;
    assign scl = scl_r;

    localparam [5:0]
        ST_IDLE       = 0,
        ST_START1     = 1,
        ST_START2     = 2,
        ST_ADDRW_L    = 3,
        ST_ADDRW_H    = 4,
        ST_ADDRW_ACKL = 5,
        ST_ADDRW_ACKH = 6,
        ST_REG_L      = 7,
        ST_REG_H      = 8,
        ST_REG_ACKL   = 9,
        ST_REG_ACKH   = 10,
        ST_DATA_L     = 11,
        ST_DATA_H     = 12,
        ST_DATA_ACKL  = 13,
        ST_DATA_ACKH  = 14,
        ST_RESTART1   = 15,
        ST_RESTART2   = 16,
        ST_ADDRR_L    = 17,
        ST_ADDRR_H    = 18,
        ST_ADDRR_ACKL = 19,
        ST_ADDRR_ACKH = 20,
        ST_READ_L     = 21,
        ST_READ_H     = 22,
        ST_NACK_L     = 23,
        ST_NACK_H     = 24,
        ST_STOP1      = 25,
        ST_STOP2      = 26,
        ST_STOP3      = 27;

    reg [5:0] state;
    reg [3:0] bitcnt;
    reg [7:0] addr_reg, reg_reg, data_reg;
    reg       read_reg;
    reg       err_reg;

    always @(posedge clk) begin
        if (rst) begin
            state      <= ST_IDLE;
            busy       <= 1'b0;
            done       <= 1'b0;
            ack_error  <= 1'b0;
            rdata      <= 8'h00;
            scl_r      <= 1'b1;
            sda_oe     <= 1'b0;
            sda_do     <= 1'b0;
            bitcnt     <= 4'd7;
            addr_reg   <= 0;
            reg_reg    <= 0;
            data_reg   <= 0;
            read_reg   <= 0;
            err_reg    <= 0;
        end else begin
            done <= 1'b0;

            if (state == ST_IDLE) begin
                scl_r  <= 1'b1;
                sda_oe <= 1'b0;
                busy   <= 1'b0;
                if (cmd_valid) begin
                    busy      <= 1'b1;
                    addr_reg  <= {cmd_addr,1'b0};
                    reg_reg   <= cmd_reg;
                    data_reg  <= cmd_wdata;
                    read_reg  <= cmd_read;
                    err_reg   <= 1'b0;
                    bitcnt    <= 4'd7;
                    state     <= ST_START1;
                end
            end else if (tick) begin
                case (state)
                    ST_START1: begin
                        // START: SDA goes low while SCL is high.
                        scl_r  <= 1'b1;
                        sda_oe <= 1'b1;
                        sda_do <= 1'b0;
                        state  <= ST_START2;
                    end
                    ST_START2: begin
                        scl_r  <= 1'b0;
                        bitcnt <= 4'd7;
                        state  <= ST_ADDRW_L;
                    end

                    ST_ADDRW_L: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_do <= addr_reg[bitcnt];
                        state  <= ST_ADDRW_H;
                    end
                    ST_ADDRW_H: begin
                        scl_r <= 1'b1;
                        if (bitcnt == 0) 
                            state <= ST_ADDRW_ACKL;
                        else 
                        begin 
                            bitcnt <= bitcnt - 1'b1; 
                            state <= ST_ADDRW_L;
                        end
                    end
                    ST_ADDRW_ACKL: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b0;
                        state  <= ST_ADDRW_ACKH;
                    end
                    ST_ADDRW_ACKH: begin
                        scl_r <= 1'b1;
                        if (sda !== 1'b0) begin
                            err_reg <= 1'b1;
                            state <= ST_STOP1;
                        end else begin
                            scl_r  <= 1'b0;
                            bitcnt <= 4'd7;
                            state  <= ST_REG_L;
                        end
                    end

                    ST_REG_L: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_do <= reg_reg[bitcnt];
                        state  <= ST_REG_H;
                    end
                    ST_REG_H: begin
                        scl_r <= 1'b1;
                        if (bitcnt == 0) 
                            state <= ST_REG_ACKL;
                        else begin 
                            bitcnt <= bitcnt - 1'b1; 
                            state <= ST_REG_L; 
                        end
                    end
                    ST_REG_ACKL: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b0;
                        state  <= ST_REG_ACKH;
                    end
                    ST_REG_ACKH: begin
                        scl_r <= 1'b1;
                        if (sda !== 1'b0) begin
                            err_reg <= 1'b1;
                            state <= ST_STOP1;
                        end else if (read_reg) begin
                            state <= ST_RESTART1;
                        end else begin
                            bitcnt <= 4'd7;
                            state <= ST_DATA_L;
                        end
                    end

                    ST_DATA_L: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_do <= data_reg[bitcnt];
                        state  <= ST_DATA_H;
                    end
                    ST_DATA_H: begin
                        scl_r <= 1'b1;
                        if (bitcnt == 0) 
                            state <= ST_DATA_ACKL;
                        else begin 
                            bitcnt <= bitcnt - 1'b1; 
                            state <= ST_DATA_L; 
                        end
                    end
                    ST_DATA_ACKL: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b0;
                        state  <= ST_DATA_ACKH;
                    end
                    ST_DATA_ACKH: begin
                        scl_r <= 1'b1;
                        if (sda !== 1'b0) err_reg <= 1'b1;
                        state <= ST_STOP1;
                    end

                    // Repeated START for a read.
                    ST_RESTART1: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b0;
                        state  <= ST_RESTART2;
                    end
                    ST_RESTART2: begin
                        scl_r  <= 1'b1;
                        sda_oe <= 1'b1;
                        sda_do <= 1'b0;
                        bitcnt <= 4'd7;
                        state  <= ST_ADDRR_L;
                    end

                    ST_ADDRR_L: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_do <= (bitcnt == 0) ? 1'b1 : addr_reg[bitcnt];
                        state  <= ST_ADDRR_H;
                    end
                    ST_ADDRR_H: begin
                        scl_r <= 1'b1;
                        if (bitcnt == 0) state <= ST_ADDRR_ACKL;
                        else begin bitcnt <= bitcnt - 1'b1; state <= ST_ADDRR_L; end
                    end
                    ST_ADDRR_ACKL: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b0;
                        state  <= ST_ADDRR_ACKH;
                    end
                    ST_ADDRR_ACKH: begin
                        scl_r <= 1'b1;
                        if (sda !== 1'b0) begin
                            err_reg <= 1'b1;
                            state <= ST_STOP1;
                        end else begin
                            bitcnt <= 4'd7;
                            rdata  <= 8'h00;
                            state  <= ST_READ_L;
                        end
                    end

                    ST_READ_L: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b0;
                        state  <= ST_READ_H;
                    end
                    ST_READ_H: begin
                        scl_r <= 1'b1;
                        rdata[bitcnt] <= sda;
                        if (bitcnt == 0) state <= ST_NACK_L;
                        else begin bitcnt <= bitcnt - 1'b1; state <= ST_READ_L; end
                    end
                    ST_NACK_L: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_do <= 1'b1; // NACK
                        state  <= ST_NACK_H;
                    end
                    ST_NACK_H: begin
                        scl_r <= 1'b1;
                        state <= ST_STOP1;
                    end

                    ST_STOP1: begin
                        scl_r  <= 1'b0;
                        sda_oe <= 1'b1;
                        sda_do <= 1'b0;
                        state  <= ST_STOP2;
                    end
                    ST_STOP2: begin
                        scl_r <= 1'b1;
                        state <= ST_STOP3;
                    end
                    ST_STOP3: begin
                        scl_r  <= 1'b1;
                        sda_oe <= 1'b0;
                        busy   <= 1'b0;
                        done   <= 1'b1;
                        ack_error <= err_reg;
                        state  <= ST_IDLE;
                    end
                    default: state <= ST_IDLE;
                endcase
            end
        end
    end
endmodule
