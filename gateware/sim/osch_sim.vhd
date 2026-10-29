-- Simulation stand-in for the MachXO2 internal oscillator. Synthesis treats
-- OSCH as a black box for the place-and-route tool; simulation binds the
-- component in e003_top to this entity instead. It runs at C_SYS_CLK_HZ
-- whatever NOM_FREQ says, so keep the two constants in e003_pkg in step.

library ieee;
use ieee.std_logic_1164.all;

use work.e003_pkg.all;

entity OSCH is
  generic (NOM_FREQ : string := "2.08");
  port (
    STDBY    : in  std_logic;
    OSC      : out std_logic;
    SEDSTDBY : out std_logic
  );
end entity;

architecture sim of OSCH is
  constant C_HALF : time := 1 sec / (2 * C_SYS_CLK_HZ);
  signal osc_q : std_logic := '0';
begin
  osc_q    <= not osc_q after C_HALF when STDBY = '0' else '0';
  OSC      <= osc_q;
  SEDSTDBY <= '0';
end architecture;
