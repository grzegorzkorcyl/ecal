library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.all;
use STD.TEXTIO.all;
use IEEE.STD_LOGIC_TEXTIO.all;
-- use work.support.all;
--library UNISIM;
--use UNISIM.VCOMPONENTS.all;

entity display is
  
  generic (
    NUMBER_OF_LETTERS : positive
    );
  port (
    CLK      : in  std_logic;
    RESET    : in  std_logic;
    DISP_A   : out  std_logic_vector(1 downto 0);
    DISP_D   : out std_logic_vector(6 downto 0);
    DISP_WR  : out std_logic;
    SENTENCE : in  std_logic_vector(NUMBER_OF_LETTERS*8-1 downto 0)
    );

end display;
architecture display of display is
  signal counter_for_display : std_logic_vector(6 downto 0);
  signal disp_counter : std_logic_vector(1 downto 0);
  constant WAIT_DISPLAY_TIME : integer := 25;
  signal display_wait_counter : std_logic_vector(WAIT_DISPLAY_TIME downto 0);
  signal next_state_pulse : std_logic;
  signal display_address : std_logic_vector(1 downto 0);
  signal write_once_counter : std_logic_vector(3 downto 0):=x"0";
begin
  
    WAIT_ONE_SEC: process (CLK, RESET)
  begin 
    if rising_edge(CLK) then
      if RESET = '1' or display_wait_counter(WAIT_DISPLAY_TIME)= '1'then   
        display_wait_counter <= (others => '0');
      else
        display_wait_counter <= display_wait_counter + 1;
      end if;
    end if;
  end process WAIT_ONE_SEC;

  CLOCK_DISPLAY: process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        counter_for_display <= (others => '0');
        next_state_pulse <= '0';
      elsif counter_for_display = "1111111" then
        counter_for_display <= (others => '0');
        next_state_pulse <= '1';
      elsif write_once_counter < x"f" then
        counter_for_display <= counter_for_display + 1;
        next_state_pulse <= '0';
      end if;
    end if;
  end process CLOCK_DISPLAY;
  
  WRITE_ONCE_COUNTER_PROC: process (CLK, RESET)
  begin  -- process WRITE_ONCE_COUNTER
    if rising_edge(CLK) then
      if RESET = '1' or display_wait_counter(WAIT_DISPLAY_TIME) = '1' then
        write_once_counter <= (others => '0');
      elsif next_state_pulse = '1' and write_once_counter < x"f" then
        write_once_counter <= write_once_counter + 1;
      end if;
    end if;
  end process WRITE_ONCE_COUNTER_PROC;
  
  DISP_COUNTER_PROC: process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' or display_wait_counter(WAIT_DISPLAY_TIME)= '1' then 
        disp_counter <= "00";
        DISP_WR <= '0';
      elsif next_state_pulse = '1' then
        disp_counter <= disp_counter + 1;
        DISP_WR <= disp_counter(1);
      end if;
    end if;
  end process DISP_COUNTER_PROC;

  DISP_ADDRESS: process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' or display_wait_counter(WAIT_DISPLAY_TIME)= '1'then       
        display_address <= "11";
      elsif next_state_pulse ='1' and disp_counter=x"3" then
        display_address <= display_address - 1;
      end if;
    end if;
  end process DISP_ADDRESS;

  SYNCH_OUT: process (CLK, RESET)
  begin 
    if rising_edge(CLK) then
      if RESET = '1' then
        DISP_A <= "00";
      else
        DISP_A <= display_address;
      end if;
    end if;
  end process SYNCH_OUT;
  
  DISPLAY_DATA_PROC  : process (CLK, RESET)
    variable data_counter : integer :=0;
    variable shift_counter : integer := 0;
  begin 
    if rising_edge(CLK) then
      if RESET = '1' or shift_counter = NUMBER_OF_LETTERS - 3 then  
        DISP_D <= SENTENCE(NUMBER_OF_LETTERS*8-2 downto NUMBER_OF_LETTERS*8-8);
        data_counter := 0;
        shift_counter := 0;
      elsif display_wait_counter(WAIT_DISPLAY_TIME)= '1' then
        data_counter := data_counter;
        shift_counter := shift_counter + 1;
        DISP_D <= SENTENCE((NUMBER_OF_LETTERS - shift_counter - data_counter mod 4)*8 -2 downto ((NUMBER_OF_LETTERS- shift_counter - data_counter mod 4)*8-8));
      elsif next_state_pulse = '1' and disp_counter = x"1" then
        DISP_D <= SENTENCE((NUMBER_OF_LETTERS - shift_counter - data_counter mod 4)*8 -2 downto ((NUMBER_OF_LETTERS- shift_counter - data_counter mod 4)*8-8));
        data_counter := data_counter+1;
        shift_counter := shift_counter;
      end if;
    end if;
  end process DISPLAY_DATA_PROC;
  
end display;
