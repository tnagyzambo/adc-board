-- SPI controller for one ADS127L14's register port.
--
-- SPI mode 1: SCLK idles low, the controller changes SDI on the rising edge
-- and both sides sample on the falling edge, where the converter has had
-- half a period to update SDO. One frame of 1 to 24 bits per start, MSB
-- first. tx and rx are left-aligned: bit 23 is the first bit on the wire,
-- whatever the frame length.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_spi_master is
  generic (
    G_HALF_CYCLES : positive  -- half an SCLK period, in clk cycles; at least 4
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;
    nbits : in  unsigned(4 downto 0);  -- 0 or above 24 means 24
    tx    : in  std_logic_vector(23 downto 0);
    rx    : out std_logic_vector(23 downto 0);
    busy  : out std_logic;
    done  : out std_logic;  -- one clk when rx is valid
    -- Pins
    sclk  : out std_logic;
    sdi   : out std_logic;
    cs_n  : out std_logic;
    sdo   : in  std_logic
  );
end entity;

architecture rtl of adc_spi_master is

  type state_t is (S_IDLE, S_LOW, S_HIGH, S_HOLD, S_GAP);
  signal state : state_t := S_IDLE;

  signal tmr   : natural range 0 to 2 * G_HALF_CYCLES := 0;
  signal len   : natural range 1 to 24 := 24;
  signal left  : natural range 0 to 24 := 0;
  signal tx_sr : std_logic_vector(23 downto 0) := (others => '0');
  signal rx_sr : std_logic_vector(23 downto 0) := (others => '0');
  signal rx_q  : std_logic_vector(23 downto 0) := (others => '0');

  signal sdo_meta : std_logic := '0';
  signal sdo_sync : std_logic := '0';

  signal sclk_q : std_logic := '0';
  signal sdi_q  : std_logic := '0';
  signal cs_q   : std_logic := '1';

begin

  sclk <= sclk_q;
  sdi  <= sdi_q;
  cs_n <= cs_q;
  rx   <= rx_q;
  busy <= '0' when state = S_IDLE else '1';

  process (clk)
    variable n : natural range 0 to 31;
  begin
    if rising_edge(clk) then
      sdo_meta <= sdo;
      sdo_sync <= sdo_meta;
      done     <= '0';

      if rst = '1' then
        state  <= S_IDLE;
        tmr    <= 0;
        sclk_q <= '0';
        sdi_q  <= '0';
        cs_q   <= '1';
      else
        case state is

          when S_IDLE =>
            if start = '1' then
              n := to_integer(nbits);
              if n = 0 or n > 24 then
                n := 24;
              end if;
              len   <= n;
              left  <= n;
              tx_sr <= tx;
              rx_sr <= (others => '0');
              cs_q  <= '0';
              tmr   <= G_HALF_CYCLES - 1;
              state <= S_LOW;
            end if;

          when S_LOW =>
            if tmr /= 0 then
              tmr <= tmr - 1;
            else
              -- Rising edge: present the next bit.
              sclk_q <= '1';
              sdi_q  <= tx_sr(23);
              tx_sr  <= tx_sr(22 downto 0) & '0';
              tmr    <= G_HALF_CYCLES - 1;
              state  <= S_HIGH;
            end if;

          when S_HIGH =>
            if tmr /= 0 then
              tmr <= tmr - 1;
            else
              -- Falling edge: the converter latches SDI, and SDO has been
              -- stable since the rising edge.
              sclk_q <= '0';
              rx_sr  <= rx_sr(22 downto 0) & sdo_sync;
              left   <= left - 1;
              tmr    <= G_HALF_CYCLES - 1;
              if left = 1 then
                state <= S_HOLD;
              else
                state <= S_LOW;
              end if;
            end if;

          when S_HOLD =>
            -- Half a period from the last falling edge to CS high.
            if tmr /= 0 then
              tmr <= tmr - 1;
            else
              cs_q  <= '1';
              sdi_q <= '0';
              tmr   <= 2 * G_HALF_CYCLES - 1;
              state <= S_GAP;
            end if;

          when S_GAP =>
            -- A full period with CS high before the next frame may start.
            if tmr /= 0 then
              tmr <= tmr - 1;
            else
              rx_q  <= std_logic_vector(shift_left(unsigned(rx_sr), 24 - len));
              done  <= '1';
              state <= S_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;
