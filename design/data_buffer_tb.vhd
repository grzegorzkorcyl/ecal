LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.math_real.all;
USE ieee.numeric_std.ALL;

ENTITY testbench IS
END testbench;

ARCHITECTURE behavior OF testbench IS 

component data_buffer is
    port (
      RESET           : in std_logic;
      CLK             : in std_logic;
      CLEAR           : in std_logic;
      -- data input from ADC
      DATA_IN         : in std_logic_vector(9 downto 0);
      WR_EN_IN        : in std_logic;
      -- data output to the endpoint
      RD_EN_IN        : in std_logic;
      DATA_OUT        : out std_logic_vector(15 downto 0);
      -- trigger input and settings
      TRIGGER_IN      : in std_logic;
      TRIGGER_POS_IN  : in std_logic_vector(9 downto 0);  -- position on trigger determines number of samples before it arrives and after
      MAX_SAMPLES_IN  : in std_logic_vector(9 downto 0);  -- maximum number of samples

      OSC_MODE_IN     : in std_logic;
      SUM_SAMPLES_IN  : in std_logic_vector(31 downto 0);
      EVENT_SAVED_OUT : out std_logic
);
end component;


  SIGNAL CLK :  std_logic;
  SIGNAL RESET :  std_logic;      -- data input from ADC
SIGNAL CLEAR : std_logic;
 SIGNAL     DATA_IN         : std_logic_vector(9 downto 0);
 SIGNAL     WR_EN_IN        :  std_logic;
      -- data output to the endpoint
 SIGNAL     RD_EN_IN        :  std_logic;
 SIGNAL     DATA_OUT        :  std_logic_vector(15 downto 0);
      -- trigger input and settings
 SIGNAL     TRIGGER_IN      :  std_logic;
  SIGNAL    TRIGGER_POS_IN  :  std_logic_vector(9 downto 0);  -- position on trigger determines number of samples before it arrives and after
  SIGNAL    MAX_SAMPLES_IN  :  std_logic_vector(9 downto 0);  -- maximum number of samples
  SIGNAL    EVENT_SAVED_OUT :  std_logic;

    signal  OSC_MODE_IN     : std_logic;
    signal  SUM_SAMPLES_IN  : std_logic_vector(31 downto 0);
BEGIN

-- Please check and add your generic clause manually
  uut: data_buffer
    port map(
      RESET           =>  RESET,
      CLK             => CLK,
      CLEAR           => CLEAR,
      -- data input from ADC
      DATA_IN         => DATA_IN,
      WR_EN_IN        => WR_EN_IN,
      -- data output to the endpoint
      RD_EN_IN        => RD_EN_IN,
      DATA_OUT        => DATA_OUT,
      -- trigger input and settings
      TRIGGER_IN      => TRIGGER_IN,
      TRIGGER_POS_IN  => TRIGGER_POS_IN,
      MAX_SAMPLES_IN  => MAX_SAMPLES_IN,

      OSC_MODE_IN     => OSC_MODE_IN,
      SUM_SAMPLES_IN  => SUM_SAMPLES_IN,
      EVENT_SAVED_OUT => EVENT_SAVED_OUT
);



-- 100 MHz system clock
CLOCK_GEN_PROC: process
begin
  clk <= '1'; wait for 5.0 ns;
  clk <= '0'; wait for 5.0 ns;
end process CLOCK_GEN_PROC;

-- Testbench
TESTBENCH_PROC: process
begin
    -- Setup signals
  reset <= '0';
  wait for 22 ns;
  reset <= '1';
clear <= '1';
  
TRIGGER_IN <= '0';
--   TRIGGER_POS_IN <= "0000010000";
--   MAX_SAMPLES_IN <= "0000100001";
TRIGGER_POS_IN   <= "0000000100";
  MAX_SAMPLES_IN <= "0000001000";
OSC_MODE_IN <= '1';
SUM_SAMPLES_IN <= X"0000_0008";
DATA_IN <= "0000000001";
rd_en_in <= '0';
wr_en_in <= '0';



  wait for 50 ns;
  reset <= '0';
  
  CLEAR <= '0';


wait for 100 ns;
  
  WR_EN_IN <= '1';
  
  wait for 500 ns;
  TRIGGER_IN <= '1';
  wait for 10 ns;
  TRIGGER_IN <= '0';
  
  
  
  wait for 500 ns;
  
  RD_EN_IN <= '1';


wait for 500 ns;
  
  CLEAR <= '1';
  wait for 10 ns;
  CLEAR <= '0';
  
  wait for 70 ns;
  TRIGGER_IN <= '1';
  wait for 10 ns;
  TRIGGER_IN <= '0';
  
  
  wait;


end process TESTBENCH_PROC;

END;

