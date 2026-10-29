-- Measures SYNC_CLK against the system clock (GW-10, in its simplest form).
--
-- A two-bit counter on SYNC_CLK makes a square wave at a quarter of its
-- frequency, slow enough for the system clock to sample. Each edge of that
-- wave is two SYNC_CLK cycles, so counting its edges over a 1 ms gate gives
-- the frequency in kHz as twice the count, with a resolution of 2 kHz. The
-- gate is timed by the internal oscillator and is accurate to its +-5.5 %.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_meter is
  generic (
    G_GATE_CYCLES : positive  -- system clocks in 1 ms
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    meas_clk : in  std_logic;
    khz      : out unsigned(15 downto 0)  -- 0 when the clock is absent
  );
end entity;

architecture rtl of clk_meter is

  signal div   : unsigned(1 downto 0) := (others => '0');
  signal s     : std_logic_vector(2 downto 0) := (others => '0');
  signal gate  : natural range 0 to G_GATE_CYCLES - 1 := 0;
  signal edges : unsigned(14 downto 0) := (others => '0');
  signal khz_q : unsigned(15 downto 0) := (others => '0');

begin

  khz <= khz_q;

  process (meas_clk)
  begin
    if rising_edge(meas_clk) then
      div <= div + 1;
    end if;
  end process;

  process (clk)
    variable edge : std_logic;
  begin
    if rising_edge(clk) then
      s    <= s(1 downto 0) & div(1);
      edge := s(2) xor s(1);

      if rst = '1' then
        gate  <= 0;
        edges <= (others => '0');
        khz_q <= (others => '0');
      elsif gate = G_GATE_CYCLES - 1 then
        gate  <= 0;
        khz_q <= shift_left(resize(edges, 16), 1);
        if edge = '1' then
          edges <= to_unsigned(1, edges'length);
        else
          edges <= (others => '0');
        end if;
      else
        gate <= gate + 1;
        if edge = '1' and edges /= 2**edges'length - 1 then
          edges <= edges + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;
