LIBRARY ieee;
use ieee.std_logic_1164.all;
USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;
use IEEE.std_logic_arith.all;

library work;

--enable wysokie, kazde tykniecie dodaje do sumy wartosc w datain

-- definicja entity
entity start is
port (
  CLOCK			:	in std_logic;
  RESET			:	in std_logic;

  DATAIN  : in std_logic_vector(11 downto 0);
  DATASUBIN  : in std_logic_vector(11 downto 0);
  
  TRESHOLD_IN  : in std_logic_vector(11 downto 0);

  ENABLESUB_IN : in std_logic;
  ENABLECF_IN : in std_logic;
  ENABLE_IN		:	in std_logic;
  
  SUM_OUT		:	out std_logic_vector(31 downto 0);
  MEAN_OUT		:	out std_logic_vector(11 downto 0);
  CF_A_OUT		:	out std_logic_vector(11 downto 0);
  CF_B_OUT		:	out std_logic_vector(11 downto 0);
  CF_TIME_OUT		:	out std_logic_vector(11 downto 0)
  --CFIN  : out std_logic_vector(7 downto 0)
);
end entity start;


architecture behavioral of start is

attribute HGROUP : string;
attribute HGROUP of Behavioral : architecture is "DSP_MODULE";

-- lokalny sygnal
signal value_temp_sum	:	std_logic_vector(31 downto 0);
signal value_temp_mean	:	std_logic_vector(31 downto 0);
signal mean_counter : std_logic_vector(7 downto 0);
signal cf_counter : std_logic_vector(11 downto 0);
signal value_cf	:	std_logic;
-- 10miejscowy bufor
signal value_bufor	:	std_logic_vector(119 downto 0);
signal value_flag	:	std_logic;
signal value_srednia : std_logic_vector(11 downto 0);

signal value_add1 : std_logic_vector(11 downto 0);
signal value_add2 : std_logic_vector(11 downto 0);
signal value_add3 : std_logic_vector(11 downto 0);

attribute syn_preserve : boolean;
attribute syn_keep : boolean;
attribute syn_keep of value_temp_sum : signal is true;
attribute syn_preserve of value_temp_sum : signal is true;

attribute syn_keep of value_temp_mean : signal is true;
attribute syn_preserve of value_temp_mean : signal is true;

attribute syn_keep of mean_counter : signal is true;
attribute syn_preserve of mean_counter : signal is true;

attribute syn_keep of cf_counter : signal is true;
attribute syn_preserve of cf_counter : signal is true;

attribute syn_keep of value_cf : signal is true;
attribute syn_preserve of value_cf : signal is true;

attribute syn_keep of value_bufor : signal is true;
attribute syn_preserve of value_bufor : signal is true;

attribute syn_keep of value_flag : signal is true;
attribute syn_preserve of value_flag : signal is true;

attribute syn_keep of value_srednia : signal is true;
attribute syn_preserve of value_srednia : signal is true;

attribute syn_keep of value_add1 : signal is true;
attribute syn_preserve of value_add1 : signal is true;

attribute syn_keep of value_add2 : signal is true;
attribute syn_preserve of value_add2 : signal is true;

attribute syn_keep of value_add3 : signal is true;
attribute syn_preserve of value_add3 : signal is true;

begin
  
-- jesli jestemy w trybie CF i srednia juz mamy policzona oraz DATAIN > srednia + treshold to ustawiamy value_flag na 1
-- treshold pobieramy z zewnatrz
-- domyslenie pik idzie do gory
--value_flag <= '1' when ((ENABLECF_IN = '1') AND (mean_counter > x"0F") AND (DATAIN > (x"0" & value_temp_mean(7 downto 4)) + TRESHOLD_IN )) else '0';

-- proces bufora
VALUE_BUFOR_PROC : process(CLOCK) 
begin
  if rising_edge(CLOCK) then -- w ktorym momencie ma sie odswiezyc
    if (RESET = '1') then  -- jesli RESET aktywny to wyzerowanie
      value_bufor <= (others => '0');
  elsif ( RESET = '0' AND ENABLECF_IN = '1') then
      value_bufor(11 downto 0) <= DATAIN;
      for i in 2 to 10 loop
        value_bufor(i*12-1 downto (i-1)*12) <= value_bufor((i-1)*12-1 downto (i-2)*12);
      end loop;
    end if;
  end if;
end process VALUE_BUFOR_PROC;


--value_add1 <= (x"0" & value_temp_mean(7 downto 4)) + DATAIN;
--value_add2 <= '0'&value_add1(11 downto 1);
--value_add3 <= value_add2 - x"080";


SYNC_PROC : process(CLOCK)
begin
  if rising_edge(CLOCK) then
    value_add1 <= DATAIN;
    value_add2 <= '0'&value_add1(11 downto 1);
    value_add3 <= value_add2;

    if ((ENABLECF_IN = '1') AND (mean_counter > x"0F") AND (DATAIN > (x"0" & value_temp_mean(7 downto 4)) + TRESHOLD_IN )) then
      value_flag <= '1';
    else
      value_flag <= '0';
    end if;
  end if;
end process SYNC_PROC;
  
-- cf_in = 0.5 datain(teraz) - datain(wczesniej)  

VALUE_CF_PROC : process(CLOCK) -- podanie sygnaly na ktorym proces ma sie "odswiezac"
begin
  if rising_edge(CLOCK) then -- w ktorym momencie ma sie odswiezyc
    if (RESET = '1') then  -- jesli RESET aktywny to wyzerowanie
      value_cf <= '0';
      cf_counter <= x"000";
    elsif ( RESET = '0' AND ENABLECF_IN = '1' ) then
      cf_counter <= cf_counter + x"001";
  
      --wczesniej = 3 probki wczesniej -- mozna ustawiac dowolnie w zakresie bufora
      -- mamy: 0.5 datain(teraz) - datain(wczesniej) <            srednia
      -- domyslnie pik idzie do gory a potem spada i przechodzi przez zero
      if( ( value_add3 - value_bufor(35 downto 24) < (x"0" & value_temp_mean(7 downto 4)) ) AND (value_flag = '1') AND (value_cf = '0') ) then
        value_cf <= '1';
        CF_A_OUT <= value_bufor(11 downto 0);
        CF_B_OUT <= DATAIN;
        CF_TIME_OUT <= cf_counter;
      end if;
    end if;
  end if;
end process VALUE_CF_PROC;

--liczymy sume

VALUE_TEMP_SUM_PROC : process(CLOCK) -- podanie sygnaly na ktorym proces ma sie "odswiezac"
begin
  if rising_edge(CLOCK) then -- w ktorym momencie ma sie odswiezyc
    if (RESET = '1') then  -- jesli RESET aktywny to wyzerowanie
      value_temp_sum <= (others => '0');
  elsif ( ENABLESUB_IN = '0' AND ENABLE_IN = '1') then
      value_temp_sum <= value_temp_sum + DATAIN;
  elsif ( ENABLESUB_IN = '1' AND ENABLE_IN = '1') then
      -- nie powinno byc liczb ujemnych bo w value_temp_sum jest juz suma 16 dodatnich pozycji
      value_temp_sum <= value_temp_sum + DATAIN - DATASUBIN;    
    end if;
  end if;
end process VALUE_TEMP_SUM_PROC;

-- asynchroniczne przepisywanie wartosci lokalnego sygnalu na port
SUM_OUT <= value_temp_sum;

--liczymy srednia

VALUE_TEMP_MEAN_PROC : process(CLOCK) -- podanie sygnaly na ktorym proces ma sie "odswiezac"
begin
  if rising_edge(CLOCK) then -- w ktorym momencie ma sie odswiezyc
    if (RESET = '1') then  -- jesli RESET aktywny to wyzerowanie
      value_temp_mean <= (others => '0');
      mean_counter <= x"00";
  elsif ( ENABLESUB_IN = '0' AND ENABLE_IN = '1' AND mean_counter <= x"0F") then
      value_temp_mean <= value_temp_mean + DATAIN;
      mean_counter <= mean_counter + x"01";
    end if;
  end if;
end process VALUE_TEMP_MEAN_PROC;

-- asynchroniczne przepisywanie wartosci lokalnego sygnalu na port
MEAN_OUT <= x"00" & value_temp_mean(7 downto 4);


end architecture;