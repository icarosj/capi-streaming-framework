library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.psl.all;
  use work.mmio_package.all;

entity mmio is
  port (
    i                   : in  mmio_in;
    o                   : out mmio_out
  );
end entity mmio;

architecture logic of mmio is

  signal q, r           : mmio_int;

begin

  comb : process(i, r)
    variable v          : mmio_int;
  begin

----------------------------------------------------------------------------------------------------------------------- default assignments

    v                   := r;
    v.reg               := i.ac.data;

----------------------------------------------------------------------------------------------------------------------- parse inputs

    v.cfg_read          := i.ha.val and i.ha.cfg and i.ha.rnw;
    v.cfg_write         := i.ha.val and i.ha.cfg and not i.ha.rnw;
    v.mmio_dw           := i.ha.dw;
    v.mmio_write        := i.ha.val and not i.ha.cfg and not i.ha.rnw;
    v.mmio_read         := i.ha.val and not i.ha.cfg and i.ha.rnw;

----------------------------------------------------------------------------------------------------------------------- afu descriptor

    -- register offset x'0 : reg_prog_model and num_of_processes
    --if i.ha.ad(PSL_MMIO_ADDRESS_WIDTH - 1 downto 0) = 24x"0" then
    if i.ha.ad(PSL_MMIO_ADDRESS_WIDTH - 1 downto 0) = x"000000" then
      v.cfg_data        := AFUD_0;
    -- register offset x'30' : per_process_psa_control
    --elsif i.ha.ad(PSL_MMIO_ADDRESS_WIDTH - 1 downto 0) = 24x"c" then
    elsif i.ha.ad(PSL_MMIO_ADDRESS_WIDTH - 1 downto 0) = x"00000c" then
      v.cfg_data        := AFUD_30;
    else
      v.cfg_data        := (others => '0');
    end if;

----------------------------------------------------------------------------------------------------------------------- write

    if v.mmio_write='1' then
      case i.ha.ad is
        -- debug data
        when MMIO_REG_ADDRESS =>
          v.reg         := i.ha.data;
        when others => null;
      end case;
    end if;

----------------------------------------------------------------------------------------------------------------------- read

    -- afu descriptor double word
    if r.cfg_read='1' and r.mmio_dw='1' then
      v.mmio_rdata      := v.cfg_data;
    -- afu descriptor word
    elsif r.cfg_read='1' and i.ha.ad(0)='1' then
      v.mmio_rdata      := v.cfg_data(PSL_WORD_WIDTH - 1 downto 0) & v.cfg_data(PSL_WORD_WIDTH - 1 downto 0);
    -- afu descriptor other word
    elsif r.cfg_read='1' then
      v.mmio_rdata      := v.cfg_data(PSL_WORD_WIDTH - 1 downto 0) & v.cfg_data(PSL_WORD_WIDTH - 1 downto 0);
    -- read register double word
    elsif r.mmio_read='1' and r.mmio_dw='1' then
      case i.ha.ad is
        -- debug data
        when MMIO_REG_ADDRESS =>
          v.mmio_rdata  := v.reg;
        when others => null;
      end case;
    else
      v.mmio_rdata      := (others => '0');
    end if;

----------------------------------------------------------------------------------------------------------------------- output

    v.ack               := r.cfg_read or r.cfg_write or r.mmio_read or r.mmio_write;

    q                   <= v;

    o.ah.ack            <= r.ack;
    o.ah.data           <= r.mmio_rdata;

  end process;

----------------------------------------------------------------------------------------------------------------------- reset & registers

  reg : process(i.cr)
  begin
    if rising_edge(i.cr.clk) then
      if i.cr.rst='1' then
        mmio_reset(r);
      else
        r <= q;
      end if;
    end if;
  end process;

end architecture logic;
