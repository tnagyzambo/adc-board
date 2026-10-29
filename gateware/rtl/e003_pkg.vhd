-- e003-adc-board bring-up gateware: shared constants and helpers.
--
-- Everything that depends on a datasheet fact that has not yet been checked
-- on hardware lives here, so a correction is a one-line change. Each such
-- constant is marked VERIFY.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package e003_pkg is

  subtype byte_t is std_logic_vector(7 downto 0);
  type byte_array_t is array (natural range <>) of byte_t;

  -- Reported at registers 0x04 and 0x05.
  constant C_GW_VERSION_MAJOR : natural := 0;
  constant C_GW_VERSION_MINOR : natural := 1;

  -- System clock: the MachXO2 internal oscillator (OSCH). The two constants
  -- must name the same frequency; OSCH accepts only the values listed in
  -- the MachXO2 sysCLOCK guide, of which 24.18 MHz is one. The oscillator is
  -- accurate to about +-5.5 %, which sets the accuracy of every interval the
  -- gateware times, the SYNC_CLK measurement included.
  constant C_OSCH_NOM_FREQ : string  := "24.18";
  constant C_SYS_CLK_HZ    : natural := 24_180_000;

  -- Host SPI: byte 0 of every frame. The board's single chip select also
  -- selects the FPGA's configuration port, which treats byte 0 as a
  -- configuration command (GW-13, OI-9), so neither value may be a MachXO2
  -- sysCONFIG command (FPGA-TN-02155 / FPGA-TN-02163). VERIFY against the
  -- command table before the configuration port is enabled in an image.
  constant C_HOST_CMD_READ  : byte_t := x"A5";
  constant C_HOST_CMD_WRITE : byte_t := x"5A";

  -- ADS127L14 register access over its SPI port (SPI mode 1).
  --
  -- VERIFY: the encoding below is an assumption, not taken from the
  -- datasheet. The ADS127L14's registers run past 0x50, so a command byte
  -- needs a 7-bit address, and the assumption is one read/write bit in
  -- bit 7 followed by the address. The ADS127L11, the single-channel
  -- relative, instead uses 0x40 + address to read and 0x80 + address to
  -- write. The raw-transfer registers (0x17 to 0x1F) and `e003_probe.py scan`
  -- try the alternatives on hardware without rebuilding.
  constant C_ADC_CMD_RREG   : byte_t  := x"80";  -- read:  C_ADC_CMD_RREG or address
  constant C_ADC_CMD_WREG   : byte_t  := x"00";  -- write: C_ADC_CMD_WREG or address
  constant C_ADC_REG_DEV_ID : natural := 16#00#;
  constant C_ADC_REG_REV_ID : natural := 16#01#;
  -- Which byte of the response frame carries the register's contents, 0
  -- being the first byte clocked out on SDO. VERIFY.
  constant C_ADC_RESP_BYTE  : natural := 0;
  -- SPI CRC: CRC-8, x^8 + x^2 + x + 1, seeded with 0xFF, over the two
  -- command bytes, MSB first. VERIFY.
  constant C_ADC_CRC_POLY   : byte_t  := x"07";
  constant C_ADC_CRC_INIT   : byte_t  := x"FF";
  -- Half an SCLK period in system clocks: 12 gives about 1 MHz, a quarter of
  -- the 4 MHz that the design summary plans for, to leave margin at bring-up.
  constant C_ADC_SPI_HALF_CYCLES : positive := 12;

  -- Returned at registers 0x40 to 0x7F, NUL padded.
  constant C_HELLO : string := "Hello, world! e003-adc-board gateware";

  function crc8(data : std_logic_vector) return byte_t;
  function to_byte(n : natural) return byte_t;
  function char_byte(c : character) return byte_t;
  function hello_rom return byte_array_t;

end package;

package body e003_pkg is

  function crc8(data : std_logic_vector) return byte_t is
    variable d   : std_logic_vector(data'length - 1 downto 0) := data;
    variable crc : byte_t := C_ADC_CRC_INIT;
    variable fb  : std_logic;
  begin
    for i in d'high downto 0 loop
      fb  := crc(7) xor d(i);
      crc := crc(6 downto 0) & '0';
      if fb = '1' then
        crc := crc xor C_ADC_CRC_POLY;
      end if;
    end loop;
    return crc;
  end function;

  function to_byte(n : natural) return byte_t is
  begin
    return std_logic_vector(to_unsigned(n mod 256, 8));
  end function;

  function char_byte(c : character) return byte_t is
  begin
    return to_byte(character'pos(c));
  end function;

  function hello_rom return byte_array_t is
    variable rom : byte_array_t(0 to 63) := (others => x"00");
  begin
    -- The last byte stays NUL so the string is always terminated.
    for i in C_HELLO'range loop
      if i - C_HELLO'low < 63 then
        rom(i - C_HELLO'low) := char_byte(C_HELLO(i));
      end if;
    end loop;
    return rom;
  end function;

end package body;
