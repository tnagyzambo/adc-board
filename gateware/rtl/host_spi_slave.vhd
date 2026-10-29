-- Host SPI peripheral: the board's register interface on SPI0.
--
-- SPI mode 0: SCLK idles low, both sides sample on the rising edge and
-- change on the falling edge. The logic runs on SCLK itself, held in reset
-- while the chip select is high, so it keeps up with any SCLK the pins
-- allow and needs no oversampling.
--
--   Read:  CS low, C_HOST_CMD_READ,  address, one dummy byte, then data
--          from address, address + 1, ... for as long as SCLK runs.
--   Write: CS low, C_HOST_CMD_WRITE, address, then data written to
--          address, address + 1, ...
--
-- MISO carries zeros during the command, address and dummy bytes.
--
-- The register file lives in the system clock domain. Reads are taken
-- straight from it a full byte before they are shifted out; every register
-- is either static or changes rarely, so a multi-byte value read while it
-- changes can be torn, which the host avoids by reading it twice. Writes
-- cross into the system domain with a toggle handshake.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.e003_pkg.all;

entity host_spi_slave is
  port (
    -- SPI pins
    sclk    : in  std_logic;
    cs_n    : in  std_logic;
    mosi    : in  std_logic;
    miso    : out std_logic;
    miso_oe : out std_logic;
    -- Read port, combinational in the register file
    rd_addr : out unsigned(7 downto 0);
    rd_data : in  byte_t;
    -- Write port, in the system clock domain
    clk     : in  std_logic;
    rst     : in  std_logic;
    wr_stb  : out std_logic;
    wr_addr : out unsigned(7 downto 0);
    wr_data : out byte_t
  );
end entity;

architecture rtl of host_spi_slave is

  -- SCLK domain
  signal bit_cnt  : unsigned(2 downto 0) := (others => '0');
  signal byte_idx : unsigned(1 downto 0) := (others => '0');  -- saturates at 3
  signal shift_in : std_logic_vector(6 downto 0) := (others => '0');
  signal cmd      : byte_t := (others => '0');
  signal ptr      : unsigned(7 downto 0) := (others => '0');
  signal tx_shift : byte_t := (others => '0');
  signal miso_q   : std_logic := '0';

  -- Write handshake, SCLK domain, not reset by the chip select
  signal wr_tgl    : std_logic := '0';
  signal wr_addr_s : unsigned(7 downto 0) := (others => '0');
  signal wr_data_s : byte_t := (others => '0');

  -- Write handshake, system domain
  signal tgl_sync : std_logic_vector(2 downto 0) := (others => '0');

begin

  rd_addr <= ptr;
  miso    <= miso_q;
  miso_oe <= not cs_n;

  -- Receive, address and load the transmit byte on the rising edge.
  rx : process (sclk, cs_n)
    variable b : byte_t;
  begin
    if cs_n = '1' then
      bit_cnt  <= (others => '0');
      byte_idx <= (others => '0');
      shift_in <= (others => '0');
      cmd      <= (others => '0');
      ptr      <= (others => '0');
      tx_shift <= (others => '0');
    elsif rising_edge(sclk) then
      b        := shift_in & mosi;
      shift_in <= b(6 downto 0);
      bit_cnt  <= bit_cnt + 1;
      tx_shift <= tx_shift(6 downto 0) & '0';

      if bit_cnt = 7 then
        if byte_idx /= 3 then
          byte_idx <= byte_idx + 1;
        end if;

        if byte_idx = 0 then
          cmd <= b;
        elsif byte_idx = 1 then
          ptr <= unsigned(b);
        elsif cmd = C_HOST_CMD_READ then
          -- The byte just finished is the dummy byte or a data byte, and the
          -- next byte out is the register at ptr.
          tx_shift <= rd_data;
          ptr      <= ptr + 1;
        elsif cmd = C_HOST_CMD_WRITE then
          -- The byte just finished is data for the register at ptr.
          ptr <= ptr + 1;
        end if;
      end if;
    end if;
  end process;

  -- Write capture, outside the chip-select reset so the toggle survives it.
  wr : process (sclk)
  begin
    if rising_edge(sclk) then
      if cs_n = '0' and bit_cnt = 7 and byte_idx(1) = '1' and cmd = C_HOST_CMD_WRITE then
        wr_addr_s <= ptr;
        wr_data_s <= shift_in & mosi;
        wr_tgl    <= not wr_tgl;
      end if;
    end if;
  end process;

  -- Transmit on the falling edge, half a period ahead of the host's sample.
  tx : process (sclk, cs_n)
  begin
    if cs_n = '1' then
      miso_q <= '0';
    elsif falling_edge(sclk) then
      miso_q <= tx_shift(7);
    end if;
  end process;

  -- Bring each write into the system domain. The address and data were
  -- captured on the same edge as the toggle, and the next write is at least
  -- eight SCLK periods later, so they are stable when the toggle arrives.
  sync : process (clk)
  begin
    if rising_edge(clk) then
      tgl_sync <= tgl_sync(1 downto 0) & wr_tgl;
      wr_stb   <= '0';
      if rst = '1' then
        tgl_sync <= (others => wr_tgl);
      elsif tgl_sync(2) /= tgl_sync(1) then
        wr_stb  <= '1';
        wr_addr <= wr_addr_s;
        wr_data <= wr_data_s;
      end if;
    end if;
  end process;

end architecture;
