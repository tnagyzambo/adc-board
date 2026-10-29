-- Host SPI peripheral: the board's register interface on SPI0.
--
-- SPI mode 0: SCLK idles low, both sides sample on the rising edge and
-- change on the falling edge. The logic runs on SCLK itself, so it keeps up
-- with any SCLK the pins allow and needs no oversampling.
--
--   Read:  CS low, C_HOST_CMD_READ,  address, one dummy byte, then data
--          from address, address + 1, ... for as long as SCLK runs.
--   Write: CS low, C_HOST_CMD_WRITE, address, then data written to
--          address, address + 1, ...
--
-- MISO carries zeros during the command, address and dummy bytes.
--
-- Nothing here has an asynchronous reset. Resetting the SCLK logic from the
-- chip select would make it the design's widest asynchronous reset, which
-- Diamond's synthesis and map then promote to the global set/reset, and GSR
-- releases too slowly for the host's first SCLK edge. Instead a counter
-- clocked by the rising chip select counts frames, and the first SCLK edge
-- that sees the count changed starts from the reset state. The count has
-- long settled by then: the chip select stays high, and then low, for a
-- while before the next SCLK edge. Only sixteen frames in a row with no SCLK
-- edge at all could hide a frame boundary.
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

  -- Chip-select domain: frames finished
  signal frames : unsigned(3 downto 0) := (others => '0');

  -- SCLK domain
  signal frames_seen : unsigned(3 downto 0) := (others => '0');
  signal bit_cnt     : unsigned(2 downto 0) := (others => '0');
  signal byte_idx    : unsigned(1 downto 0) := (others => '0');  -- saturates at 3
  signal shift_in    : std_logic_vector(6 downto 0) := (others => '0');
  signal cmd         : byte_t := (others => '0');
  signal ptr         : unsigned(7 downto 0) := (others => '0');
  signal tx_shift    : byte_t := (others => '0');
  signal miso_q      : std_logic := '0';

  -- Write handshake, SCLK domain
  signal wr_tgl    : std_logic := '0';
  signal wr_addr_s : unsigned(7 downto 0) := (others => '0');
  signal wr_data_s : byte_t := (others => '0');

  -- Write handshake, system domain
  signal tgl_sync : std_logic_vector(2 downto 0) := (others => '0');

begin

  rd_addr <= ptr;
  miso    <= miso_q;
  miso_oe <= not cs_n;

  frame_count : process (cs_n)
  begin
    if rising_edge(cs_n) then
      frames <= frames + 1;
    end if;
  end process;

  -- Receive, address, load the transmit byte and capture writes on the
  -- rising edge.
  rx : process (sclk)
    variable bc : unsigned(2 downto 0);
    variable bi : unsigned(1 downto 0);
    variable si : std_logic_vector(6 downto 0);
    variable c  : byte_t;
    variable p  : unsigned(7 downto 0);
    variable tx : byte_t;
    variable b  : byte_t;
  begin
    if rising_edge(sclk) then
      bc := bit_cnt;
      bi := byte_idx;
      si := shift_in;
      c  := cmd;
      p  := ptr;
      tx := tx_shift;
      -- The first edge of a frame starts from the reset state.
      if frames /= frames_seen then
        bc := (others => '0');
        bi := (others => '0');
        si := (others => '0');
        c  := (others => '0');
        p  := (others => '0');
        tx := (others => '0');
      end if;
      frames_seen <= frames;

      b        := si & mosi;
      shift_in <= b(6 downto 0);
      bit_cnt  <= bc + 1;
      byte_idx <= bi;
      cmd      <= c;
      ptr      <= p;
      tx_shift <= tx(6 downto 0) & '0';

      if bc = 7 then
        if bi /= 3 then
          byte_idx <= bi + 1;
        end if;

        if bi = 0 then
          cmd <= b;
        elsif bi = 1 then
          ptr <= unsigned(b);
        elsif c = C_HOST_CMD_READ then
          -- The byte just finished is the dummy byte or a data byte, and the
          -- next byte out is the register at ptr.
          tx_shift <= rd_data;
          ptr      <= p + 1;
        elsif c = C_HOST_CMD_WRITE then
          -- The byte just finished is data for the register at ptr.
          ptr       <= p + 1;
          wr_addr_s <= p;
          wr_data_s <= b;
          wr_tgl    <= not wr_tgl;
        end if;
      end if;
    end if;
  end process;

  -- Transmit on the falling edge, half a period ahead of the host's sample.
  -- Until the first rising edge of a frame this repeats the previous
  -- frame's last bit, which falls in the command byte, where MISO is unused.
  tx : process (sclk)
  begin
    if falling_edge(sclk) then
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
