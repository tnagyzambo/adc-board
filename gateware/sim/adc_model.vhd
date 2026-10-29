-- Behavioural model of an ADS127L14 register port, for simulation only.
--
-- It implements the protocol that e003_pkg assumes, not the datasheet: SPI
-- mode 1, a 16-bit frame of command and data, or a 24-bit frame with a
-- CRC byte, and read data returned in the first byte of the next frame. It
-- therefore checks that the gateware does what the package says, and must
-- change with it once the datasheet has been checked. The ID values are
-- invented.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.e003_pkg.all;

entity adc_model is
  generic (
    G_DEV_ID : byte_t;
    G_REV_ID : byte_t
  );
  port (
    sclk       : in  std_logic;
    cs_n       : in  std_logic;
    sdi        : in  std_logic;
    reset_n    : in  std_logic;
    sdo        : out std_logic;
    frames     : out natural;  -- frames accepted
    crc_errors : out natural
  );
end entity;

architecture sim of adc_model is
begin

  process
    variable regs     : byte_array_t(0 to 127);
    variable in_sr    : std_logic_vector(23 downto 0);
    variable out_sr   : std_logic_vector(23 downto 0);
    variable next_out : std_logic_vector(23 downto 0) := (others => '0');
    variable n        : natural;
    variable cmd      : byte_t;
    variable data     : byte_t;
    variable ok       : boolean;
    variable addr     : natural;
    variable n_frames : natural := 0;
    variable n_crc    : natural := 0;
  begin
    regs    := (others => x"00");
    regs(C_ADC_REG_DEV_ID) := G_DEV_ID;
    regs(C_ADC_REG_REV_ID) := G_REV_ID;
    frames     <= 0;
    crc_errors <= 0;

    loop
      sdo <= 'Z';
      wait until cs_n = '0';
      sdo    <= '0';
      in_sr  := (others => '0');
      out_sr := next_out;
      n      := 0;

      loop
        wait until rising_edge(sclk) or cs_n = '1';
        exit when cs_n = '1';
        sdo    <= out_sr(23) after 5 ns;
        out_sr := out_sr(22 downto 0) & '0';
        wait until falling_edge(sclk) or cs_n = '1';
        exit when cs_n = '1';
        in_sr := in_sr(22 downto 0) & sdi;
        n     := n + 1;
      end loop;

      if reset_n = '0' then
        report "adc_model: frame while in reset" severity error;
      else
        ok := true;
        if n = 16 then
          cmd  := in_sr(15 downto 8);
          data := in_sr(7 downto 0);
        elsif n = 24 then
          cmd  := in_sr(23 downto 16);
          data := in_sr(15 downto 8);
          if in_sr(7 downto 0) /= crc8(cmd & data) then
            n_crc := n_crc + 1;
            ok    := false;
            report "adc_model: CRC error" severity error;
          end if;
        else
          ok := false;
          report "adc_model: unexpected frame of " & integer'image(n) & " bits" severity error;
        end if;

        next_out := (others => '0');
        if ok then
          n_frames := n_frames + 1;
          addr     := to_integer(unsigned(cmd(6 downto 0)));
          if (cmd and x"80") = C_ADC_CMD_RREG then
            next_out(23 downto 16) := regs(addr);
          else
            regs(addr) := data;
          end if;
        end if;
        frames     <= n_frames;
        crc_errors <= n_crc;
      end if;
    end loop;
  end process;

end architecture;
