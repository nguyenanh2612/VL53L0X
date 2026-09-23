module top(
    input  wire       CLOCK_50,
    input  wire       KEY0,       // active-low reset button

    inout  wire       VL53_SDA,
    output wire       VL53_SCL,

    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,

    output wire [3:0] LED
);

    wire rst = ~KEY0;

    wire       i2c_cmd_valid;
    wire       i2c_cmd_read;
    wire [6:0] i2c_cmd_addr;
    wire [7:0] i2c_cmd_reg;
    wire [7:0] i2c_cmd_wdata;
    wire       i2c_busy;
    wire       i2c_done;
    wire       i2c_ack_error;
    wire [7:0] i2c_rdata;

    wire [15:0] distance_mm;
    wire        distance_valid;
    wire        sensor_error;

    i2c_master #(
        .CLK_FREQ(50_000_000),
        .I2C_FREQ(100_000)
    ) u_i2c (
        .clk(CLOCK_50),
        .rst(rst),
        .cmd_valid(i2c_cmd_valid),
        .cmd_read(i2c_cmd_read),
        .cmd_addr(i2c_cmd_addr),
        .cmd_reg(i2c_cmd_reg),
        .cmd_wdata(i2c_cmd_wdata),
        .busy(i2c_busy),
        .done(i2c_done),
        .ack_error(i2c_ack_error),
        .rdata(i2c_rdata),
        .sda(VL53_SDA),
        .scl(VL53_SCL)
    );

    vl53l0x u_sensor (
        .clk(CLOCK_50),
        .rst(rst),
        .i2c_cmd_valid(i2c_cmd_valid),
        .i2c_cmd_read(i2c_cmd_read),
        .i2c_cmd_addr(i2c_cmd_addr),
        .i2c_cmd_reg(i2c_cmd_reg),
        .i2c_cmd_wdata(i2c_cmd_wdata),
        .i2c_busy(i2c_busy),
        .i2c_done(i2c_done),
        .i2c_ack_error(i2c_ack_error),
        .i2c_rdata(i2c_rdata),
        .distance_mm(distance_mm),
        .valid(distance_valid),
        .error(sensor_error)
    );

    wire [3:0] d0 = distance_mm % 10;
    wire [3:0] d1 = (distance_mm / 10) % 10;
    wire [3:0] d2 = (distance_mm / 100) % 10;
    wire [3:0] d3 = (distance_mm / 1000) % 10;
    wire [3:0] d4 = (distance_mm / 10000) % 10;

    hex_display h0(.value(d0),.hex(HEX0));
    hex_display h1(.value(d1),.hex(HEX1));
    hex_display h2(.value(d2),.hex(HEX2));
    hex_display h3(.value(d3),.hex(HEX3));
    hex_display h4(.value(d4),.hex(HEX4));

    // HEX5 is used as a simple status indicator: "E" on error, blank otherwise.
    assign HEX5 = sensor_error ? 7'b0000110 : 7'b1111111;

    assign LED[0] = distance_valid;
    assign LED[1] = sensor_error;
    assign LED[2] = i2c_busy;
    assign LED[3] = ~KEY0;

endmodule
