library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.adcmv3_components.all;

entity pulse_sync is
port(
	CLK_A_IN        : in    std_logic;
	RESET_A_IN      : in    std_logic;
	PULSE_A_IN      : in    std_logic;
	CLK_B_IN        : in    std_logic;
	RESET_B_IN      : in    std_logic;
	PULSE_B_OUT     : out   std_logic
);
end;

architecture behavioral of pulse_sync is

-- normal signals
signal toggle_ff        : std_logic;
signal sync_q           : std_logic;
signal sync_qq          : std_logic;
signal sync_qqq         : std_logic;
signal pulse_b          : std_logic;

begin

-- toggle flip flop in clock domain A
THE_TOGGLE_FF_PROC: process( clk_a_in )
begin
	if( rising_edge(clk_a_in) ) then
		if   ( reset_a_in = '1' ) then
			toggle_ff <= '0';
		elsif( pulse_a_in = '1' ) then
			toggle_ff <= not toggle_ff;
		end if;
	end if;
end process THE_TOGGLE_FF_PROC;

-- synchronizing stage for clock domain B
THE_SYNC_STAGE_PROC: process( clk_b_in )
begin
	if( rising_edge(clk_b_in) ) then
		if( reset_b_in = '1' ) then
			sync_q <= '0'; sync_qq <= '0'; sync_qqq <= '0';
		else
			sync_qqq <= sync_qq;
			sync_qq  <= sync_q;
			sync_q   <= toggle_ff;
		end if;
	end if;
end process THE_SYNC_STAGE_PROC;

-- output pulse registering
THE_OUTPUT_PULSE_PROC: process( clk_b_in )
begin
	if( rising_edge(clk_b_in) ) then
		if( reset_b_in = '1' ) then
			pulse_b <= '0';
		else
			pulse_b <= sync_qqq xor sync_qq;
		end if;
	end if;
end process THE_OUTPUT_PULSE_PROC;

-- output signals
pulse_b_out   <= pulse_b;

end behavioral;
