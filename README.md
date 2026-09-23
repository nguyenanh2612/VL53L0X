# VL53L0X
SoC project on FPGA with module VL53L0X

DE10-Standard + VL53L0X, pure Verilog
======================================

Files:
  top.v
  i2c_master.v
  vl53l0x.v
  hex_display.v

Clock:
  CLOCK_50 = 50 MHz

I2C:
  100 kHz
  7-bit VL53L0X address = 0x29
  write byte = 0x52
  read byte  = 0x53

Function:
  - FPGA waits ~100 ms after reset.
  - Checks VL53L0X model ID (0xC0 should return 0xEE).
  - Loads a standard tuning sequence.
  - Starts continuous back-to-back ranging.
  - This compact FPGA driver does not run the optional VHV/phase reference
    calibration sequence; it is intended for common VL53L0X breakout modules
    that retain their factory calibration.
  - Reads RESULT_RANGE_STATUS + 10 => 0x1E/0x1F.
  - Displays distance in mm on HEX4..HEX0.

IMPORTANT HARDWARE:
  1. VL53_SDA is open-drain and requires an external pull-up.
  2. Use a VL53L0X breakout/module whose I/O voltage is compatible with the
     DE10-Standard FPGA bank you use.
  3. Do NOT connect 5-V I2C directly to FPGA pins.
  4. You must assign VL53_SDA and VL53_SCL to the actual DE10-Standard
     GPIO header pins in the Quartus .qsf file.
  5. The exact header pin numbers depend on which DE10-Standard GPIO header
     and adapter wiring you choose.

Quartus:
  Create a new project for the DE10-Standard FPGA device used by your board,
  add the four .v files, set top-level entity to "top", then add the
  appropriate .qsf pin assignments for CLOCK_50, KEY0, HEX0..HEX5, LED[3:0],
  VL53_SDA and VL53_SCL.

Debug:
  - If HEX5 shows "E", the sensor did not ACK or model ID was not 0xEE.
  - Check SDA/SCL pull-ups, common GND, module power, and the selected GPIO
    header.
  - Use a logic analyzer on SDA/SCL if needed.
