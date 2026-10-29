-- Testbench for the bring-up gateware: drives the host SPI lane as the ECU
-- MCU board would and checks every register the bring-up procedure uses.
-- Ends with "tb_e003_top: PASS", or stops at the first failure.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.e003_pkg.all;

entity tb_e003_top is
end entity;

architecture sim of tb_e003_top is

  constant C_SPI_HALF  : time := 125 ns;      -- 4 MHz host SCLK
  constant C_SYNC_HALF : time := 61.035 ns;   -- 8.192 MHz SYNC_CLK

  constant C_ADC1_DEV_ID : byte_t := x"A4";   -- invented, see adc_model
  constant C_ADC1_REV_ID : byte_t := x"02";
  constant C_ADC2_DEV_ID : byte_t := x"B5";
  constant C_ADC2_REV_ID : byte_t := x"13";

  signal sync_clk   : std_logic := '0';
  signal sync_start : std_logic := '1';
  signal cs_n       : std_logic := '1';
  signal sclk       : std_logic := '0';
  signal mosi       : std_logic := '0';
  signal miso       : std_logic;
  signal adc_en     : std_logic;
  signal adc_flt_n  : std_logic := '1';

  signal adc1_sclk, adc1_sdi, adc1_cs_n, adc1_sdo, adc1_reset_n : std_logic;
  signal adc2_sclk, adc2_sdi, adc2_cs_n, adc2_sdo, adc2_reset_n : std_logic;
  signal adc1_clk, adc2_clk, adc1_start, adc2_start              : std_logic;
  signal adc1_frames, adc2_frames, adc1_crc_err, adc2_crc_err    : natural;

begin

  sync_clk <= not sync_clk after C_SYNC_HALF;

  -- The FPGA's input pull-downs on SDO
  adc1_sdo <= 'L';
  adc2_sdo <= 'L';

  dut : entity work.e003_top
    generic map (
      G_BUILD_ID      => 16#0123ABC#,
      G_POWER_WAIT_US => 50,
      G_RESET_WAIT_US => 20
    )
    port map (
      sync_clk_i     => sync_clk,
      sync_start_i   => sync_start,
      host_cs_n_i    => cs_n,
      host_sclk_i    => sclk,
      host_mosi_i    => mosi,
      host_miso_o    => miso,
      adc_en_o       => adc_en,
      adc_flt_n_i    => adc_flt_n,
      adc1_clk_o     => adc1_clk,
      adc1_start_o   => adc1_start,
      adc1_sclk_o    => adc1_sclk,
      adc1_sdi_o     => adc1_sdi,
      adc1_cs_n_o    => adc1_cs_n,
      adc1_sdo_i     => adc1_sdo,
      adc1_dout_i    => '0',
      adc1_fsync_i   => '0',
      adc1_reset_n_o => adc1_reset_n,
      adc2_clk_o     => adc2_clk,
      adc2_start_o   => adc2_start,
      adc2_sclk_o    => adc2_sclk,
      adc2_sdi_o     => adc2_sdi,
      adc2_cs_n_o    => adc2_cs_n,
      adc2_sdo_i     => adc2_sdo,
      adc2_dout_i    => '0',
      adc2_fsync_i   => '0',
      adc2_reset_n_o => adc2_reset_n
    );

  adc1 : entity work.adc_model
    generic map (G_DEV_ID => C_ADC1_DEV_ID, G_REV_ID => C_ADC1_REV_ID)
    port map (
      sclk => adc1_sclk, cs_n => adc1_cs_n, sdi => adc1_sdi, reset_n => adc1_reset_n,
      sdo => adc1_sdo, frames => adc1_frames, crc_errors => adc1_crc_err
    );

  adc2 : entity work.adc_model
    generic map (G_DEV_ID => C_ADC2_DEV_ID, G_REV_ID => C_ADC2_REV_ID)
    port map (
      sclk => adc2_sclk, cs_n => adc2_cs_n, sdi => adc2_sdi, reset_n => adc2_reset_n,
      sdo => adc2_sdo, frames => adc2_frames, crc_errors => adc2_crc_err
    );

  stim : process

    variable rx : byte_array_t(0 to 63);

    -- One host SPI byte, mode 0.
    procedure xfer(tx : in byte_t; r : out byte_t) is
      variable v : byte_t;
    begin
      for i in 7 downto 0 loop
        mosi <= tx(i);
        wait for C_SPI_HALF;
        sclk <= '1';
        v(i) := to_x01(miso);
        wait for C_SPI_HALF;
        sclk <= '0';
      end loop;
      r := v;
    end procedure;

    procedure read_regs(addr : in natural; n : in positive) is
      variable d : byte_t;
    begin
      cs_n <= '0';
      wait for C_SPI_HALF;
      xfer(C_HOST_CMD_READ, d);
      xfer(to_byte(addr), d);
      xfer(x"00", d);
      for i in 0 to n - 1 loop
        xfer(x"00", d);
        rx(i) := d;
      end loop;
      wait for C_SPI_HALF;
      cs_n <= '1';
      wait for 1 us;
    end procedure;

    procedure write_regs(addr : in natural; data : in byte_array_t) is
      variable d : byte_t;
    begin
      cs_n <= '0';
      wait for C_SPI_HALF;
      xfer(C_HOST_CMD_WRITE, d);
      xfer(to_byte(addr), d);
      for i in data'range loop
        xfer(data(i), d);
      end loop;
      wait for C_SPI_HALF;
      cs_n <= '1';
      wait for 1 us;
    end procedure;

    procedure write_reg(addr : in natural; data : in byte_t) is
    begin
      write_regs(addr, (0 => data));
    end procedure;

    procedure expect(got, want : byte_t; what : string) is
    begin
      assert got = want
        report what & ": got 0x" & to_hstring(got) & ", expected 0x" & to_hstring(want)
        severity failure;
    end procedure;

    -- Poll STATUS until the bits in mask are set.
    procedure wait_status(mask : byte_t; timeout : time) is
      variable t0 : time := now;
    begin
      loop
        read_regs(16#06#, 1);
        exit when (rx(0) and mask) = mask;
        assert now - t0 < timeout
          report "timeout waiting for STATUS and 0x" & to_hstring(mask) &
                 ", STATUS = 0x" & to_hstring(rx(0))
          severity failure;
        wait for 10 us;
      end loop;
    end procedure;

    variable khz : natural;

  begin
    wait for 5 us;

    assert miso = 'Z' report "MISO driven while deselected" severity failure;

    -- Identity
    read_regs(16#00#, 6);
    expect(rx(0), char_byte('E'), "MAGIC0");
    expect(rx(1), char_byte('0'), "MAGIC1");
    expect(rx(2), char_byte('0'), "MAGIC2");
    expect(rx(3), char_byte('3'), "MAGIC3");
    expect(rx(4), to_byte(C_GW_VERSION_MAJOR), "VERSION_MAJOR");
    expect(rx(5), to_byte(C_GW_VERSION_MINOR), "VERSION_MINOR");

    read_regs(16#0C#, 4);
    expect(rx(0), x"00", "BUILD_ID[31:24]");
    expect(rx(1), x"12", "BUILD_ID[23:16]");
    expect(rx(2), x"3A", "BUILD_ID[15:8]");
    expect(rx(3), x"BC", "BUILD_ID[7:0]");

    -- Hello, world
    read_regs(16#40#, 64);
    for i in C_HELLO'range loop
      expect(rx(i - C_HELLO'low), char_byte(C_HELLO(i)), "HELLO(" & integer'image(i) & ")");
    end loop;
    expect(rx(C_HELLO'length), x"00", "HELLO terminator");

    -- Scratch register
    write_reg(16#0A#, x"C3");
    read_regs(16#0A#, 1);
    expect(rx(0), x"C3", "SCRATCH");

    -- Channel supply is off after configuration
    assert adc_en = '0' report "ADC_EN high at start" severity failure;
    read_regs(16#10#, 1);
    expect(rx(0), x"00", "ADC_STATE at start");

    -- SYNC_CLK frequency, once two 1 ms gates have passed
    wait for 2.2 ms;
    read_regs(16#08#, 2);
    khz := to_integer(unsigned(rx(0))) * 256 + to_integer(unsigned(rx(1)));
    report "SYNC_CLK measured at " & integer'image(khz) & " kHz";
    assert khz >= 8180 and khz <= 8204 report "SYNC_CLK measurement wrong" severity failure;
    read_regs(16#06#, 1);
    assert rx(0)(6) = '1' report "STATUS.SYNC_OK clear" severity failure;

    -- Supply on: the IDs are read without further commands (16-bit frames)
    write_reg(16#07#, x"01");
    wait for 2 us;
    assert adc_en = '1' report "ADC_EN low after CTRL.SUPPLY_EN" severity failure;
    wait_status(x"88", 1 ms);  -- READY and ID_VALID
    read_regs(16#11#, 4);
    expect(rx(0), C_ADC1_DEV_ID, "ADC1 DEV_ID");
    expect(rx(1), C_ADC1_REV_ID, "ADC1 REV_ID");
    expect(rx(2), C_ADC2_DEV_ID, "ADC2 DEV_ID");
    expect(rx(3), C_ADC2_REV_ID, "ADC2 REV_ID");
    read_regs(16#20#, 9);
    expect(rx(3), C_ADC1_DEV_ID, "ADC1 frame 1 byte 0");
    expect(rx(6), C_ADC1_REV_ID, "ADC1 frame 2 byte 0");

    -- Raw transfers to ADC2: RREG(DEV_ID), then any frame to collect it
    write_regs(16#18#, (x"01", x"10", C_ADC_CMD_RREG or to_byte(C_ADC_REG_DEV_ID), x"00", x"00"));
    write_reg(16#17#, x"00");
    wait_status(x"A0", 1 ms);  -- READY and RAW_DONE
    write_reg(16#17#, x"00");
    wait for 2 us;
    wait_status(x"A0", 1 ms);
    read_regs(16#1D#, 3);
    expect(rx(0), C_ADC2_DEV_ID, "RAW_RX byte 0");

    -- 24-bit frames with CRC, and an explicit re-read
    write_reg(16#07#, x"07");
    wait for 2 us;
    wait_status(x"88", 1 ms);
    read_regs(16#11#, 4);
    expect(rx(0), C_ADC1_DEV_ID, "ADC1 DEV_ID with CRC");
    expect(rx(3), C_ADC2_REV_ID, "ADC2 REV_ID with CRC");
    assert adc1_crc_err = 0 and adc2_crc_err = 0 report "CRC errors at the converters" severity failure;

    -- An eFuse fault is reported live and held
    adc_flt_n <= '0';
    wait for 1 us;
    read_regs(16#06#, 1);
    assert rx(0)(1) = '1' and rx(0)(2) = '1' report "eFuse fault not reported" severity failure;
    adc_flt_n <= '1';
    wait for 1 us;
    write_reg(16#07#, x"0B");  -- clear the sticky flag, supply and CRC stay on
    read_regs(16#06#, 1);
    assert rx(0)(1) = '0' and rx(0)(2) = '0' report "eFuse fault not cleared" severity failure;

    -- Supply off
    write_reg(16#07#, x"00");
    wait for 2 us;
    assert adc_en = '0' and adc1_reset_n = '0' and adc2_reset_n = '0'
      report "supply or reset not released" severity failure;

    report "converter frames: ADC1 " & integer'image(adc1_frames) &
           ", ADC2 " & integer'image(adc2_frames);
    report "tb_e003_top: PASS";
    finish;
  end process;

end architecture;
