LIBRARY ieee;
use ieee.std_logic_1164.all;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;

library work;
use work.trb_net_std.all;
--use work.version.all;


entity gbe_setup is
port(
  CLK                       : in std_logic;
  RESET                     : in std_logic;

  -- interface to regio bus
  BUS_ADDR_IN               : in std_logic_vector(7 downto 0);
  BUS_DATA_IN               : in std_logic_vector(31 downto 0);
  BUS_DATA_OUT              : out std_logic_vector(31 downto 0);
  BUS_WRITE_EN_IN           : in std_logic;
  BUS_READ_EN_IN            : in std_logic;
  BUS_ACK_OUT               : out std_logic;

--inputs
--   LVL1_STATE_IN             : in std_logic_vector(2 downto 0);
--   ADC_WR_STATE_IN           : in std_logic_vector(31 downto 0);
--   FEB_ENGINE_STATE_IN       : in std_logic_vector(7 downto 0);
  DESYNC_IN                 : in std_logic_vector(5 downto 0);

--outputs
  OSC_MODE_OUT              : out std_logic;
  SUM_SAMPLES_OUT           : out std_logic_vector(31 downto 0);
  TRIGGER_POS_OUT           : out std_logic_vector(9 downto 0);
  THRESHOLD_OUT             : out std_logic_vector(11 downto 0);
  POSITION_OUT		: out std_logic_vector(3 downto 0);
  MAX_SAMPLES_OUT           : out std_logic_vector(9 downto 0)
);
end entity;

architecture gbe_setup of gbe_setup is

signal reset_values       : std_logic;
signal ack                : std_logic;
signal ack_q              : std_logic;
signal data_out           : std_logic_vector(31 downto 0);
signal trigger_pos        : std_logic_vector(9 downto 0);
signal max_samples        : std_logic_vector(9 downto 0);
signal osc_mode           : std_logic;
signal sum_samples        : std_logic_vector(31 downto 0);
signal threshold : std_logic_vector(11 downto 0);
signal position : std_logic_vector(3 downto 0);


begin

OUT_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    ack_q                  <= ack;
    BUS_ACK_OUT            <= ack_q;
    BUS_DATA_OUT           <= data_out;
    TRIGGER_POS_OUT        <= trigger_pos;
    MAX_SAMPLES_OUT        <= max_samples;
    OSC_MODE_OUT           <= osc_mode;
    SUM_SAMPLES_OUT        <= sum_samples;
    THRESHOLD_OUT <= threshold;
    POSITION_OUT <= position;
  end if;
end process OUT_PROC;

-- gk 26.04.10
ACK_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') then
      ack <= '0';
    elsif ((BUS_WRITE_EN_IN = '1') or (BUS_READ_EN_IN = '1')) then
      ack <= '1';
    else
      ack <= '0';
    end if;
  end if;
end process ACK_PROC;

WRITE_PROC : process(CLK)
begin

  if rising_edge(CLK) then
    if ( (RESET = '1') or (reset_values = '1') ) then
      trigger_pos        <= "0000010000";  -- default 16 pre samples
      max_samples        <= "0000100000";  -- default 32 total samples
      osc_mode           <= '1';
      reset_values       <= '0';
      sum_samples        <= x"0000_0008";
      threshold          <= x"010";
      position           <= x"2";

    elsif (BUS_WRITE_EN_IN = '1') then
      case BUS_ADDR_IN is

        when x"10" =>
          trigger_pos <= BUS_DATA_IN(9 downto 0);

        when x"11" =>
          max_samples <= BUS_DATA_IN(9 downto 0);

        when x"12" =>
          if (BUS_DATA_IN = x"0000_0001") then
            osc_mode  <= '1';
          elsif (BUS_DATA_IN = x"0000_0000") then
            osc_mode    <= '0';
            trigger_pos <= "0000010000";  -- set default 16 pre samples for normal mode
            max_samples <= "0000100000";  -- set default 32 total samples for normal mode
          end if;

        when x"13" =>
          sum_samples <= BUS_DATA_IN;

	when x"14" =>
	  threshold <= BUS_DATA_IN(11 downto 0);

	when x"15" =>
	  position <= BUS_DATA_IN(3 downto 0);

        when x"ff" =>
          if (BUS_DATA_IN = x"ffff_ffff") then
            reset_values <= '1';
          else
            reset_values <= '0';
          end if;

        when others =>
          reset_values       <= reset_values;
          trigger_pos        <= trigger_pos;
          max_samples        <= max_samples;
          osc_mode           <= osc_mode;
          sum_samples        <= sum_samples;
	  threshold <= threshold;
	  position <= position;
      end case;
    else
      reset_values      <= '0';
    end if;
  end if;
end process WRITE_PROC;


READ_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') then
      data_out <= (others => '0');
    elsif (BUS_READ_EN_IN = '1') then
      case BUS_ADDR_IN is

        when x"00" =>
          data_out <= x"deadface";

--         when x"01" =>
--           data_out(2 downto 0)  <= LVL1_STATE_IN;
--           data_out(31 downto 3) <= (others => '0');
-- 
--         when x"02" =>
--           data_out(3 downto 0)  <= ADC_WR_STATE_IN(3 downto 0);
--           data_out(31 downto 4) <= (others => '0');
-- 
--         when x"03" =>
--           data_out(3 downto 0)  <= ADC_WR_STATE_IN(7 downto 4);
--           data_out(31 downto 4) <= (others => '0');
-- 
--         when x"04" =>
--           data_out(3 downto 0)  <= ADC_WR_STATE_IN(11 downto 8);
--           data_out(31 downto 4) <= (others => '0');
-- 
--         when x"05" =>
--           data_out(3 downto 0)  <= ADC_WR_STATE_IN(15 downto 12);
--           data_out(31 downto 4) <= (others => '0');
-- 
--         when x"06" =>
--           data_out(3 downto 0)  <= ADC_WR_STATE_IN(19 downto 16);
--           data_out(31 downto 4) <= (others => '0');
-- 
--         when x"07" =>
--           data_out(3 downto 0)  <= ADC_WR_STATE_IN(23 downto 20);
--           data_out(31 downto 4) <= (others => '0');
-- 
--         when x"08" =>
--           data_out(7 downto 0)  <= FEB_ENGINE_STATE_IN;
--           data_out(31 downto 8) <= (others => '0');

        when x"10" =>
          data_out(9 downto 0)   <= trigger_pos;
          data_out(31 downto 10) <= (others => '0');

        when x"11" =>
          data_out(9 downto 0)   <= max_samples;
          data_out(31 downto 10) <= (others => '0');

        when x"12" =>
          data_out(0) <= osc_mode;
          data_out(31 downto 1) <= (others => '0');

        when x"13" =>
          data_out <= sum_samples;


	when x"14" =>
	  data_out(11 downto 0) <= threshold;
	  data_out(31 downto 12) <= (others => '0');  

	when x"15" =>
	  data_out(3 downto 0) <= position;
	  data_out(31 downto 4) <= (others => '0');  

-- 	when x"16" =>
-- 	  data_out(5 downto 0) <= DESYNC_IN;
-- 	  data_out(31 downto 6) <= (others => '0');

        when others =>
          data_out <= (others => '0');
      end case;
    end if;
  end if;
end process READ_PROC;

end architecture;