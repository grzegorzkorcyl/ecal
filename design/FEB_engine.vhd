----------------------------------------------------------------------------------
-- FEB_engine generates control sequence to Front End Boards (FEBs) on the detector
-- FEB_CLOCK has 300 ns period
-- FEB_CLK_PIPED is FEB_CLOCK delayed by 8 ADC clocks to compensate for ADC pipe line
-- ADC clock period is 50 ns
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--use work.shower_components.all;

entity FEB_engine is


        port( RESET                 : in std_logic;
              CLOCK                 : in std_logic;         -- 100 MHz

			-- hold received from the connector
				REAL_HOLD_IN	              : in std_logic;

			-- lvl1 trigger handling
				LVL1_VALID_NOTIMING_TRG_IN  : in std_logic;
				LVL1_INVALID_TRG_IN         : in std_logic;
				LVL1_TRG_DATA_VALID_IN      : in std_logic;
				LVL1_TRG_TYPE_IN            : in std_logic_vector(3  downto 0);
				LVL1_TRG_INFORMATION_IN     : in std_logic_vector(23  downto 0);

			-- defines end of BUSY from ShowerAddOn
				FEE_TRG_RELEASE_OUT         : out std_logic;
        FEB_64TH_PEDESTAL_IN        : in std_logic;

			-- 10ns pulse indicating that FEB multiplexed another channel at the output
        FEB_MUX_NEW_CHAN_RDY_OUT	  : out std_logic;
        ADC_VALID_SYNCH_IN          : in std_logic;

			-- hardware output signal driving front-ends
              INT_HOLD_OUT          : out std_logic;
              FEB_CLOCK_OUT         : out std_logic;
              FEB_RESET_OUT         : out std_logic;
              FEB_RBITIN_OUT        : out std_logic;
              FEB_ENABLE_OUT        : out std_logic;
              FEB_EVEN_OUT          : out std_logic;
              FEB_ODD_OUT           : out std_logic;

        ENGINE_STATE_OUT            : out std_logic_vector(7 downto 0);  -- gk 02.11.10
        PED_PAUSE_IN                : in std_logic_vector(31 downto 0); -- gk 10.11.10
        PED_NUM_OF_SAMPLES_IN       : in std_logic_vector(6 downto 0);  -- gk 10.11.10

				DEBUG_OUT			: out std_logic_vector(15 downto 0)
				);

end FEB_engine;

architecture Behavioral of FEB_engine is

type engine_type is (idle, one, two, three, four, five, six, seven, eight, reset_febs, cal_1, cal_2, cal_3, cal_4, cal_5, wait_500ns, final_end_or_pedestal_calcul, final_end, synch_trigger, clear_flags);  -- separate_reset,
signal engine_state : engine_type;
--attribute HGROUP : string;
--attribute HGROUP of Behavioral : architecture is "FEB_eng";

--attribute syn_encoding: string;
--attribute syn_encoding of engine_state: signal is "safe,gray";

type piped_state_type is (zero_piped, one_piped, two_piped, three_piped, four_piped, five_piped, six_piped);
signal piped_state : piped_state_type;

signal PAD_COUNTER, PIPED_PAD_COUNTER : std_logic_vector(4 downto 0);
signal WAIT_COUNTER : std_logic_vector(5 downto 0);
signal PIPE_COUNTER : std_logic_vector(6 downto 0);
signal pedestal_event_counter : std_logic_vector( 5 downto 0);

signal slow_down_counter : std_logic_vector(2 downto 0);
signal a_50ns_counter    : std_logic_vector(2 downto 0);
signal start_waiting, passed_500ns, even_odd, start_ADC_PIPE : std_logic;
signal calibration: std_logic;
signal pedestal_calculation : std_logic;

signal local_feb_mux_new_chan_rdy_out : std_logic;

signal start, start_synch : std_logic;

-- gk 02.11.10
signal engine_state_num : std_logic_vector(7 downto 0);

-- gk 09.11.10
signal pause_between_triggers : std_logic_vector(7 downto 0);

begin

ENGINE_STATE_OUT <= engine_state_num;  -- gk 02.11.10

DEBUG_OUT <= x"1234";

FEB_MUX_NEW_CHAN_RDY_OUT <= local_feb_mux_new_chan_rdy_out;

passed_500ns <= '1' when WAIT_COUNTER = "100000" else '0';
FEB_RESET_OUT <= '0' when engine_state = reset_febs else '1';
FEB_RBITIN_OUT <= '0' when engine_state = three or engine_state = four or engine_state = five or
					engine_state = six or engine_state = seven or engine_state = eight else '1';

INT_HOLD_OUT <= '1' when (calibration = '1' or pedestal_calculation = '1') and (engine_state =  cal_5 or engine_state = one or engine_state = two) else '0';

FEB_ENABLE_OUT <= '1' when (calibration = '1') and (engine_state = cal_1 or engine_state = cal_2 or engine_state = cal_3
			or engine_state = cal_4 or engine_state = wait_500ns) else '0';
FEB_EVEN_OUT <= even_odd when (calibration = '1') and (engine_state = cal_3 or engine_state =cal_4 or engine_state = wait_500ns or engine_state =  cal_5) else '0';
FEB_ODD_OUT <= not even_odd when (calibration = '1') and (engine_state =  cal_3 or engine_state = cal_4 or engine_state = wait_500ns or engine_state =  cal_5) else '0';

start_waiting <= '1' when engine_state =  wait_500ns else '0';

LOCAL_RELEASE_PROCESS: process (RESET, CLOCK, engine_state) begin
if rising_edge(CLOCK) then
	if(RESET = '1') then
		 FEE_TRG_RELEASE_OUT <= '0';
      even_odd <= '0';
	elsif engine_state = final_end then
		FEE_TRG_RELEASE_OUT <= '1';
    even_odd <= not even_odd;
	else
		FEE_TRG_RELEASE_OUT <= '0';
	end if;
end if;
end process LOCAL_RELEASE_PROCESS;

LOCAL_START_PROCESS: process (RESET, CLOCK, REAL_HOLD_IN, LVL1_VALID_NOTIMING_TRG_IN) begin
if rising_edge (CLOCK) then
	if (RESET = '1') then
		start_synch <= '0';
	else
		if (start = '1') then
			start_synch <= '0';
		elsif (start = '0') then
			if (REAL_HOLD_IN = '1' or LVL1_VALID_NOTIMING_TRG_IN = '1') then
				start_synch <= '1';
			end if;
		end if;
	end if;
end if;
end process LOCAL_START_PROCESS;

LOCAL_START_SYNCH_PROCESS: process (RESET, CLOCK, engine_state) begin
if rising_edge (CLOCK) then
  if (RESET = '1') then
    start <= '0';
  else
    if (engine_state = final_end) then
      start <= '0';
    elsif (start = '0') then
      if (start_synch = '1' and ADC_VALID_SYNCH_IN = '1') then
        start <= '1';
      end if;
    end if;
  end if;
end if;
end process LOCAL_START_SYNCH_PROCESS;

TRG_TYPE_PROCESS: process (RESET, CLOCK, LVL1_TRG_DATA_VALID_IN, LVL1_TRG_TYPE_IN, engine_state) begin
if rising_edge (CLOCK) then
	if (RESET = '1') then
		calibration <= '0';
    pedestal_calculation <= '0';
	elsif (LVL1_TRG_DATA_VALID_IN = '1') then
      case LVL1_TRG_TYPE_IN is
        when x"A" =>  calibration <= '1';
--                    even_odd <= LVL1_TRG_INFORMATION_IN(12);
        when x"B" => pedestal_calculation <= '1';
        when others =>  calibration <= '0';
                        pedestal_calculation <= '0';
      end case;
	end if;
  if engine_state = clear_flags then
     pedestal_calculation <= '0';
     calibration <= '0';
  end if;
end if;
end process TRG_TYPE_PROCESS;

FEB_CLOCK_REG: process(RESET, CLOCK, engine_state) begin
if rising_edge(CLOCK) then
	if(RESET = '1') then
		FEB_CLOCK_OUT <= '1';
	elsif(engine_state = two or engine_state = three or engine_state = four or engine_state = five) then
		FEB_CLOCK_OUT <= '0';
	else
		FEB_CLOCK_OUT <= '1';
	end if;
end if;
end process FEB_CLOCK_REG;

SLOW_DOWN_CLOCK: process (RESET, CLOCK, START) begin
if rising_edge(CLOCK) then
	if(RESET = '1') then
		slow_down_counter <= "000";
	elsif START = '1' then
		slow_down_counter <= slow_down_counter + 1;
	else
		slow_down_counter <= "000";
	end if;
end if;
end process SLOW_DOWN_CLOCK;

A_50NS_CLOCK: process (RESET, CLOCK, START) begin
if rising_edge(CLOCK) then
	if(RESET = '1' or engine_state = two) then
		a_50ns_counter <= "000";
	else
		if START = '1' then
			if a_50ns_counter = "100" then
				a_50ns_counter <= "000";
			else
				a_50ns_counter <= a_50ns_counter + 1;
			end if;
		else
				a_50ns_counter <= "000";
		end if;
	end if;
end if;
end process A_50NS_CLOCK;

RUN_FEBS: process (RESET, CLOCK, START, pedestal_calculation, FEB_64TH_PEDESTAL_IN) begin
if rising_edge(CLOCK) then
	if(RESET = '1') then
		engine_state <= idle;
		PAD_COUNTER <= (others => '1');
	else
		case engine_state is

			when idle	=>
        engine_state_num <= x"01";
      	if START = '1' then
					if calibration = '1' then
						engine_state <= cal_1;
					elsif
            pedestal_calculation = '1' then
              engine_state <= cal_5;
            else
							engine_state <= one;
					end if;
				end if;
				PAD_COUNTER <= "11111";

			when one	=>
              engine_state_num <= x"02";
              if slow_down_counter = "111" then
								engine_state <= two;
							end if;

			when two	=>
              engine_state_num <= x"03"; 
              if slow_down_counter = "111" then
								engine_state <= three;
							end if;

			when three	=>
              engine_state_num <= x"04";
              if a_50ns_counter = "011" then
								engine_state <= four;
							end if;

			when four 	=>
              engine_state_num <= x"05";
              if a_50ns_counter = "011" then
								engine_state <= five;
								PAD_COUNTER <= PAD_COUNTER + 1;
							end if;

			when five 	=>
              engine_state_num <= x"06";
               if a_50ns_counter = "011" then
								engine_state <= six;
							end if;

			when six	=>
              engine_state_num <= x"07";
              if a_50ns_counter = "011" then
								engine_state <= seven;
							end if;

			when seven	=>
              engine_state_num <= x"08";
              if a_50ns_counter = "011" then
								engine_state <= eight;
							end if;

			when eight	=>
              engine_state_num <= x"09";
              if a_50ns_counter = "011" then
								if PAD_COUNTER = "11111" then
									engine_state <= reset_febs;
								else
									engine_state <= three;
								end if;
							end if;

			when reset_febs =>
                engine_state_num <= x"0a";
                if slow_down_counter = "011" then
									engine_state <= final_end_or_pedestal_calcul;
--                  engine_state <= separate_reset;
								end if;

			when cal_1	=>
              engine_state_num <= x"0b";
              if slow_down_counter = "011" then
								engine_state <= cal_2;
							end if;

			when cal_2	=>
              engine_state_num <= x"0c";
              if slow_down_counter = "011" then
								engine_state <= cal_3;
							end if;

			when cal_3	=>
              engine_state_num <= x"0d";
              if slow_down_counter = "011" then
								engine_state <= cal_4;
							end if;

			when cal_4	=>
              engine_state_num <= x"0e";
              if slow_down_counter = "011" then
								engine_state <= wait_500ns;
							end if;

			when wait_500ns =>
                engine_state_num <= x"0f";
                if passed_500ns = '1' then
									engine_state <= cal_5;
								end if;

			when cal_5	=>
              engine_state_num <= x"10";
              if slow_down_counter = "011" then
								engine_state <= one;
							end if;
--      when separate_reset  =>  if slow_down_counter = "011" then
--                  engine_state <= final_end_or_pedestal_calcul;
--              end if;
      when final_end_or_pedestal_calcul =>
              engine_state_num <= x"11";
              --if (pedestal_calculation = '0') or (pedestal_event_counter = "111111") then
              if (pedestal_calculation = '0') or (pedestal_event_counter = (PED_NUM_OF_SAMPLES_IN - x"1")) then
                engine_state <= final_end;
              else
                -- gk 09.11.10
                if (pause_between_triggers = PED_PAUSE_IN) then
                  engine_state <= cal_5;
                else
                  engine_state <= final_end_or_pedestal_calcul;
                end if;
              end if;

      when final_end  =>
              engine_state_num <= x"12";
              engine_state <= synch_trigger;

			when synch_trigger =>
              engine_state_num <= x"13";
              if LVL1_TRG_DATA_VALID_IN = '0' then
								engine_state <= clear_flags;
              end if;

      when clear_flags  =>
              engine_state_num <= x"14";
              engine_state <= idle;

			when others	=> engine_state <= idle;

		end case;
	end if;
end if;
end process RUN_FEBS;

-- gk 09.11.10
PAUSE_BETWEEN_TRIGGERS_PROC : process(CLOCK)
begin
  if rising_edge(CLOCK) then
    if (RESET = '1') or (engine_state = reset_febs) then
      pause_between_triggers <= (others => '0');
    elsif (engine_state = final_end_or_pedestal_calcul) and (pedestal_calculation = '1') then
      pause_between_triggers <= pause_between_triggers + x"1";
    end if;
  end if;
end process PAUSE_BETWEEN_TRIGGERS_PROC;

COUNT_PED_TRIGGERS: process(RESET, CLOCK, engine_state, pedestal_calculation, slow_down_counter) begin
if rising_edge(CLOCK) then
  if (RESET = '1') then
    pedestal_event_counter <= (others => '1'); 
  else
    if engine_state = reset_febs and slow_down_counter = "001" and pedestal_calculation = '1' then
      pedestal_event_counter <= pedestal_event_counter + 1;
    else
      if engine_state = final_end then
        pedestal_event_counter <= (others => '1'); 
      end if;
    end if;
  end if;
end if;
end process COUNT_PED_TRIGGERS;


process(RESET, CLOCK, start_waiting) begin
if rising_edge(CLOCK) then
	if(RESET = '1') then
		WAIT_COUNTER <= (others => '0');
	elsif start_waiting = '1' then
		WAIT_COUNTER <= WAIT_COUNTER + 1;
		else
		WAIT_COUNTER <= (others => '0');
		end if;
end if;
end process;


START_PULSE: process(RESET, CLOCK, engine_state, local_feb_mux_new_chan_rdy_out,a_50ns_counter ) begin
if rising_edge(CLOCK) then
	if(RESET = '1') then
		local_feb_mux_new_chan_rdy_out <= '0';
	else
		if local_feb_mux_new_chan_rdy_out = '0' then
			if engine_state = six and a_50ns_counter = "001" then  -- generate puls when FEB multiplexes new channel (FEB clock 0->1)
				local_feb_mux_new_chan_rdy_out <= '1';
			end if;
		else
			local_feb_mux_new_chan_rdy_out <= '0';
		end if;
	end if;
end if;
end process START_PULSE;

end Behavioral;
