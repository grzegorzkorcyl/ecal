----------------------------------------------------------------------------------
-- serpar receives serial DDR data stream from ADC and produces 10-bit result
-- odd  number result bits come on positive edges of ADC_CLOCK
-- even number result bits come on negative edges of ADC_CLOCK
-- positive edge of FRAME_CLOCK comes after LSB of the ADC result
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.numeric_std.ALL;
use work.shower_components.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_ARITH.all;

entity serpar2 is
    port (
      RESET          : in std_logic;
      ADC_CLOCK      : in std_logic;
      SYS_CLOCK      : in std_logic;
      ADC_INPUT      : in std_logic_vector(15 downto 0);
      FRAME_CLOCK    : in std_logic_vector(1 downto 0);
      ADC_RESULT_OUT : out std_logic_vector(79 downto 0);
      ADC_RESULT_VALID_OUT : out std_logic;
      fifo_full		: out std_logic;
      fifo_empty	: out std_logic;
      debug       : out std_logic_vector(31 downto 0)
);
end serpar2;

architecture Behavioral of serpar2 is
-- directives for placer:
attribute HGROUP : string;
attribute HGROUP of Behavioral : architecture is "ADC_serpar_group";

  signal FIFO_DATA_INPUT      : std_logic_vector(17 downto 0);
  signal DDR_DATA             : std_logic_vector(17 downto 0);
  signal fifo_write           : std_logic;
  signal fifo_valid_read : std_logic;
  signal fifo_data        : std_logic_vector(17 downto 0);
  signal check_frame_risingedge_ff   : std_logic_vector(1 downto 0);
  signal adc_parallel_data, ADC_RESULT_TEMP, adc_parallel_data1, ADC_RESULT_TEMP1 : std_logic_vector(79 downto 0);
  signal counter : std_logic_vector(2 downto 0);
  signal word_counter : std_logic_vector(3 downto 0);
  signal fifo_almost_empty : std_logic;
  signal even_odd           : std_logic;
  signal adc_result_valid_local : std_logic;
  signal adc_valid_synch_tmp : std_logic;

  signal saved_even_odd : std_logic;  -- gk 05.07.11

begin

debug <= x"00" & word_counter & "00" & fifo_data;

--   THE_ADC_DATA_FIFO : fifo_af_dc_18x8
--       port map(
--           Data     => FIFO_DATA_INPUT,
--           WrClock  => ADC_CLOCK,
--           RdClock  => SYS_CLOCK,
--           WrEn     => fifo_write,
--           RdEn     => fifo_valid_read,
--           Reset    => RESET,
--           RPReset  => RESET,
--           Q        => fifo_data,
--           RCNT     => word_counter,
--           Empty    => fifo_empty,
--           Full     => fifo_full,
--           AlmostEmpty => fifo_almost_empty
--           );
-- 

  process(ADC_CLOCK, counter)
    begin
      if rising_edge(ADC_CLOCK) then
        if (RESET = '1') then
            adc_result_valid_local <= '0';
        else
          if counter = "010"  then
              adc_result_valid_local <= '1';
          else
              adc_result_valid_local <= '0';
          end if;
        end if;
      end if;
    end process;

process (SYS_CLOCK, RESET, adc_result_valid_local)
begin
  if RESET = '1' then
    ADC_RESULT_VALID_OUT <= '0';
  elsif rising_edge (SYS_CLOCK) then
      if (ADC_RESULT_VALID_OUT = '0') then -- and (counter = "010") then  -- gk 05.07.11 added counter clause in order to prohibit taking the same data twice by read_ADC
        adc_valid_synch_tmp <= adc_result_valid_local;
        ADC_RESULT_VALID_OUT <= adc_valid_synch_tmp;
      else
        ADC_RESULT_VALID_OUT <= '0';
      end if;
  end if;
end process;
--   process(SYS_CLOCK)
--     begin
--       if rising_edge(SYS_CLOCK) then
--         DDR_DATA <= FRAME_CLOCK & ADC_INPUT;
--       end if;
--     end process;

  process(ADC_CLOCK)
    begin
      if rising_edge(ADC_CLOCK) then
        FIFO_DATA_INPUT <= FRAME_CLOCK & ADC_INPUT;
      end if;
    end process;

  process(SYS_CLOCK)
    begin
      if rising_edge(SYS_CLOCK) then
    if (RESET = '1') then
      fifo_write <= '0';
    else
       fifo_write <= (not RESET);
    end if;
      end if;
 end process;

  process(SYS_CLOCK)
    begin
      if rising_edge(SYS_CLOCK) then
    if (RESET = '1') then
      fifo_valid_read <= '0';
    else
       fifo_valid_read <= (not fifo_empty);
    end if;
      end if;
    end process;

  process(ADC_CLOCK)
    begin
      if rising_edge(ADC_CLOCK) then
          if (RESET = '1') then
              check_frame_risingedge_ff <= "00";
          else
              check_frame_risingedge_ff <= fifo_data_input(17 downto 16);
          end if;
      end if;
    end process;

   process(ADC_CLOCK)
    begin
      if rising_edge(ADC_CLOCK) then
          if (RESET = '1') then
                adc_parallel_data <= (others => '0');
                adc_parallel_data1 <= (others => '0');
                counter <= "100";
                even_odd <= '0';
          else
--        if  fifo_valid_read  = '1' then
            if (check_frame_risingedge_ff = "00" and  fifo_data_input(17 downto 16) = "11") then
                counter <= "011";
                if even_odd = '1' then
                    adc_parallel_data1(79 downto 64) <= fifo_data_input(15 downto 0);
                    ADC_RESULT_OUT <= ADC_RESULT_TEMP;
                else
                    adc_parallel_data(79 downto 64) <= fifo_data_input(15 downto 0);
                    ADC_RESULT_OUT <= ADC_RESULT_TEMP1;
                end if;
            else
              if even_odd = '1' then
                      case counter is
                          when "011" => adc_parallel_data1(48+15 downto 48) <= fifo_data_input(15 downto 0);
                                    counter <= "010";
                          when "010" => adc_parallel_data1(32+15 downto 32) <= fifo_data_input(15 downto 0);
                                counter <= "001";
                          when "001" => adc_parallel_data1(16+15 downto 16) <= fifo_data_input(15 downto 0);
                                counter <= "000";
                          when "000" => adc_parallel_data1(   15 downto  0) <= fifo_data_input(15 downto 0);
                                counter <= "011";
                                even_odd <= not even_odd;
                          when others => counter <= "100";
                      end case;
              else
                      case counter is
                          when "011" => adc_parallel_data(48+15 downto 48) <= fifo_data_input(15 downto 0);
                                    counter <= "010";
                          when "010" => adc_parallel_data(32+15 downto 32) <= fifo_data_input(15 downto 0);
                                counter <= "001";
                          when "001" => adc_parallel_data(16+15 downto 16) <= fifo_data_input(15 downto 0);
                                counter <= "000";
                          when "000" => adc_parallel_data(   15 downto  0) <= fifo_data_input(15 downto 0);
                                counter <= "011";
                                even_odd <= not even_odd;
                          when others => counter <= "100";
                      end case;
              end if;
          
--                adc_parallel_data(conv_integer(counter)*16+15 downto conv_integer(counter)*16) <= fifo_data(15 downto 0);
              --counter <= counter - 1;
            end if;
--        end if;
        end if;
      end if;
    end process;

 gen_output : for i in 0 to 7 generate
    ADC_RESULT_TEMP(i*10+9 downto i*10) <= adc_parallel_data(i*2+1+64 downto i*2+64) &
                            adc_parallel_data(i*2+1+48 downto i*2+48) & adc_parallel_data(i*2+1+32 downto i*2+32) &
                            adc_parallel_data(i*2+16+1 downto i*2+16) & adc_parallel_data(i*2+1 downto i*2);
    ADC_RESULT_TEMP1(i*10+9 downto i*10) <= adc_parallel_data1(i*2+1+64 downto i*2+64) &
                            adc_parallel_data1(i*2+1+48 downto i*2+48) & adc_parallel_data1(i*2+1+32 downto i*2+32) &
                            adc_parallel_data1(i*2+16+1 downto i*2+16) & adc_parallel_data1(i*2+1 downto i*2);
  end generate;

end Behavioral;

