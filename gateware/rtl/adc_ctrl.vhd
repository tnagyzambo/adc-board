-- Channel supply and converter bring-up.
--
-- Powers the channels on the host's command, releases both converters from
-- reset, reads their ID registers and keeps the raw responses. Afterwards
-- the host can send any frame to either converter through the raw-transfer
-- registers. Nothing here writes a converter register on its own, so the
-- converters keep their reset state, in which their GPIO pins, and with them
-- every channel switch, are off.
--
--   S_OFF    supply off, converters in reset
--   S_POWER  supply on, converters held in reset while the 1.8 V rail settles
--   S_RESET  converters out of reset, waiting before the first access
--   S_ID     three frames to each converter: RREG(DEV_ID), RREG(REV_ID),
--            RREG(REV_ID). Read data is assumed to arrive in the frame after
--            the command, so frame 1 carries DEV_ID and frame 2 REV_ID; all
--            three responses are kept in case it arrives in the same frame.
--   S_READY  idle, raw transfers allowed
--   S_RAW    a raw transfer in progress
--
-- Clearing supply_req returns to S_OFF from any state.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.e003_pkg.all;

entity adc_ctrl is
  generic (
    G_POWER_WAIT_CYCLES : positive;
    G_RESET_WAIT_CYCLES : positive;
    G_SPI_HALF_CYCLES   : positive
  );
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    -- Control
    supply_req  : in  std_logic;
    crc_en      : in  std_logic;  -- 24-bit frames with CRC, else 16-bit frames
    id_req      : in  std_logic;  -- pulse: read the IDs again
    raw_go      : in  std_logic;  -- pulse: start a raw transfer
    raw_sel     : in  std_logic;  -- 0: ADC1, 1: ADC2
    raw_len     : in  unsigned(4 downto 0);
    raw_tx      : in  std_logic_vector(23 downto 0);
    -- Status
    raw_rx      : out std_logic_vector(23 downto 0);
    raw_busy    : out std_logic;
    raw_done    : out std_logic;
    id_valid    : out std_logic;
    ready       : out std_logic;
    state_code  : out byte_t;
    -- Responses to the ID frames: ADC1 frames 0 to 2, then ADC2 frames 0
    -- to 2, three bytes each in the order they left SDO.
    id_resp     : out byte_array_t(0 to 17);
    -- Pins
    supply_en   : out std_logic;
    adc_reset_n : out std_logic;
    adc_sclk    : out std_logic_vector(1 downto 0);
    adc_sdi     : out std_logic_vector(1 downto 0);
    adc_cs_n    : out std_logic_vector(1 downto 0);
    adc_sdo     : in  std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of adc_ctrl is

  type state_t is (S_OFF, S_POWER, S_RESET, S_ID_START, S_ID_WAIT, S_READY, S_RAW);
  signal state : state_t := S_OFF;

  type word_array_t is array (0 to 1) of std_logic_vector(23 downto 0);

  signal tmr       : natural range 0 to G_POWER_WAIT_CYCLES + G_RESET_WAIT_CYCLES := 0;
  signal frame_idx : natural range 0 to 2 := 0;
  signal got       : std_logic_vector(1 downto 0) := "00";
  signal resp      : byte_array_t(0 to 17) := (others => x"00");

  signal m_start : std_logic_vector(1 downto 0) := "00";
  signal m_busy  : std_logic_vector(1 downto 0);
  signal m_done  : std_logic_vector(1 downto 0);
  signal m_tx    : word_array_t := (others => (others => '0'));
  signal m_rx    : word_array_t;
  signal m_nbits : unsigned(4 downto 0) := to_unsigned(16, 5);

  signal sel_q      : natural range 0 to 1 := 0;
  signal raw_rx_q   : std_logic_vector(23 downto 0) := (others => '0');
  signal raw_done_q : std_logic := '0';
  signal id_valid_q : std_logic := '0';
  signal supply_q   : std_logic := '0';
  signal reset_n_q  : std_logic := '0';

  -- Read-register frame, left-aligned.
  function rreg_frame(addr : natural; crc : std_logic) return std_logic_vector is
    variable c : byte_t := C_ADC_CMD_RREG or to_byte(addr);
  begin
    if crc = '1' then
      return c & x"00" & crc8(c & x"00");
    else
      return c & x"00" & x"00";
    end if;
  end function;

begin

  raw_rx      <= raw_rx_q;
  raw_done    <= raw_done_q;
  raw_busy    <= '1' when state = S_RAW else '0';
  id_valid    <= id_valid_q;
  ready       <= '1' when state = S_READY else '0';
  id_resp     <= resp;
  supply_en   <= supply_q;
  adc_reset_n <= reset_n_q;

  with state select state_code <=
    x"00" when S_OFF,
    x"01" when S_POWER,
    x"02" when S_RESET,
    x"03" when S_ID_START | S_ID_WAIT,
    x"04" when S_READY,
    x"05" when S_RAW;

  gen_spi : for i in 0 to 1 generate
    u_spi : entity work.adc_spi_master
      generic map (G_HALF_CYCLES => G_SPI_HALF_CYCLES)
      port map (
        clk   => clk,
        rst   => rst,
        start => m_start(i),
        nbits => m_nbits,
        tx    => m_tx(i),
        rx    => m_rx(i),
        busy  => m_busy(i),
        done  => m_done(i),
        sclk  => adc_sclk(i),
        sdi   => adc_sdi(i),
        cs_n  => adc_cs_n(i),
        sdo   => adc_sdo(i)
      );
  end generate;

  process (clk)
    variable g    : std_logic_vector(1 downto 0);
    variable addr : natural;
  begin
    if rising_edge(clk) then
      m_start <= "00";

      if rst = '1' then
        state      <= S_OFF;
        tmr        <= 0;
        supply_q   <= '0';
        reset_n_q  <= '0';
        id_valid_q <= '0';
        raw_done_q <= '0';

      elsif supply_req = '0' and state /= S_OFF then
        state      <= S_OFF;
        supply_q   <= '0';
        reset_n_q  <= '0';
        id_valid_q <= '0';

      else
        case state is

          when S_OFF =>
            supply_q  <= '0';
            reset_n_q <= '0';
            if supply_req = '1' then
              supply_q <= '1';
              tmr      <= G_POWER_WAIT_CYCLES - 1;
              state    <= S_POWER;
            end if;

          when S_POWER =>
            if tmr /= 0 then
              tmr <= tmr - 1;
            else
              reset_n_q <= '1';
              tmr       <= G_RESET_WAIT_CYCLES - 1;
              state     <= S_RESET;
            end if;

          when S_RESET =>
            if tmr /= 0 then
              tmr <= tmr - 1;
            else
              frame_idx <= 0;
              state     <= S_ID_START;
            end if;

          when S_ID_START =>
            -- Wait out a frame that a supply cycle may have interrupted.
            if m_busy = "00" then
              if frame_idx = 0 then
                addr := C_ADC_REG_DEV_ID;
              else
                addr := C_ADC_REG_REV_ID;
              end if;
              m_tx(0) <= rreg_frame(addr, crc_en);
              m_tx(1) <= rreg_frame(addr, crc_en);
              if crc_en = '1' then
                m_nbits <= to_unsigned(24, 5);
              else
                m_nbits <= to_unsigned(16, 5);
              end if;
              m_start <= "11";
              got     <= "00";
              state   <= S_ID_WAIT;
            end if;

          when S_ID_WAIT =>
            for i in 0 to 1 loop
              if m_done(i) = '1' then
                for k in 0 to 2 loop
                  resp(i * 9 + frame_idx * 3 + k) <= m_rx(i)(23 - 8 * k downto 16 - 8 * k);
                end loop;
              end if;
            end loop;
            g   := got or m_done;
            got <= g;
            if g = "11" then
              if frame_idx = 2 then
                id_valid_q <= '1';
                state      <= S_READY;
              else
                frame_idx <= frame_idx + 1;
                state     <= S_ID_START;
              end if;
            end if;

          when S_READY =>
            if id_req = '1' then
              id_valid_q <= '0';
              frame_idx  <= 0;
              state      <= S_ID_START;
            elsif raw_go = '1' then
              raw_done_q <= '0';
              m_nbits    <= raw_len;
              if raw_sel = '0' then
                sel_q      <= 0;
                m_tx(0)    <= raw_tx;
                m_start(0) <= '1';
              else
                sel_q      <= 1;
                m_tx(1)    <= raw_tx;
                m_start(1) <= '1';
              end if;
              state <= S_RAW;
            end if;

          when S_RAW =>
            if m_done(sel_q) = '1' then
              raw_rx_q   <= m_rx(sel_q);
              raw_done_q <= '1';
              state      <= S_READY;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;
