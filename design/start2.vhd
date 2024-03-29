LIBRARY ieee;
use ieee.std_logic_1164.all;
--USE IEEE.numeric_std.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;
use IEEE.std_logic_arith.all;

use work.shower_components.all;

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
  POSITION_IN	: in std_logic_vector(3 downto 0);

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

-- lokalny sygnal
signal value_temp_sum	:	std_logic_vector(31 downto 0);
signal value_temp_mean	:	std_logic_vector(31 downto 0);
signal mean_counter : std_logic_vector(7 downto 0);
signal cf_counter : std_logic_vector(11 downto 0);
signal value_cf	:	std_logic;
-- 10miejscowy bufor
signal value_bufor	:	std_logic_vector(119 downto 0);
signal value_flag	:	std_logic;
--signal value_srednia : std_logic_vector(11 downto 0);

--signal value_add1 : std_logic_vector(11 downto 0);
--signal value_add2 : std_logic_vector(11 downto 0);
signal value_half_mean : std_logic_vector(11 downto 0);
signal position_int : integer range 0 to 15;

signal temp_cfa, temp_cfb : std_logic_vector(11 downto 0);

--signal tmp_cf_out_a : std_logic_vector(11 downto 0);
--signal tmp_cf_out_b : std_logic_vector(11 downto 0);

begin
  
-- jesli jestemy w trybie CF i srednia juz mamy policzona oraz DATAIN > srednia + treshold to ustawiamy value_flag na 1
-- treshold pobieramy z zewnatrz
-- domyslenie pik idzie do gory
value_flag <= '1' when ((ENABLECF_IN = '1') AND (mean_counter > x"0F") AND (DATAIN > (value_temp_mean(15 downto 4)) + TRESHOLD_IN )) else '0';

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


-- liczymy srednia (dzielimy przez 16) i dodatkowo dzielimy przez 2
value_half_mean <= '0'&value_temp_mean(15 downto 5);
  
-- niepotrzebne, tymczasowe zmienne do debugowania
--tmp_cf_out_a <= value_bufor(23 downto 13) + value_add3 - value_bufor(47 downto 36);
--tmp_cf_out_b <= value_bufor(35 downto 24) - value_add2 - value_add3;

-- cf_in = 0.5 datain(teraz) - datain(wczesniej) + srednia

VALUE_CF_PROC : process(CLOCK) -- podanie sygnaly na ktorym proces ma sie "odswiezac"
begin
  if rising_edge(CLOCK) then -- w ktorym momencie ma sie odswiezyc
    if (RESET = '1') then  -- jesli RESET aktywny to wyzerowanie
      value_cf <= '0';
      cf_counter <= x"000";
    elsif ( RESET = '0' AND ENABLECF_IN = '1' ) then
      cf_counter <= cf_counter + x"001";
  
      --wczesniej = 2 probki wczesniej -- mozna ustawiac dowolnie w zakresie bufora
      -- mamy: 0.5 datain(teraz) - datain(wczesniej) + srednia < 0.5 srednia
      -- mamy: 0.5 datain(teraz) - 0.5 srednia < datain(wczesniej) - srednia
      -- mamy: 0.5 datain(teraz) + 0.5 srednia < datain(wczesniej)
      -- domyslnie pik idzie do gory a potem spada i przechodzi przez zero
      
      -- x = przesuniecie o x probek
      
      --     sygnal w aktualnej chwili +     srednia       <  sygnal ( 12(x+1)-1 downto 12*x )
      if( ( ( value_bufor(11 downto 1) + value_half_mean ) < value_bufor(35 downto 24)) AND (value_flag = '1') AND (value_cf = '0') ) then
        
        value_cf <= '1';
        
        --          sygnal ( 12*x-1 downto 12(x-1)+1 ) +   ...  -  sygnal ( 12(x+2)-1 downto 12(x+1) )
        --CF_A_OUT <= value_bufor(23 downto 13) + value_half_mean - value_bufor(47 downto 36);

	temp_cfa <= value_bufor(23 downto 13) + value_half_mean;

-- 	for i in 11 downto 0 loop
-- 	  CF_A_OUT <= value_bufor((12 * (position_int - 1)) + 1 + i) + value_half_mean - value_bufor((12 * (position_int + 1)) + i);
-- 	  if (i < 11) then
-- 	    CF_B_OUT <= value_bufor((12 * position_int) + i) - value_bufor(1 + i) - value_half_mean;
-- 	  else
-- 	    CF_B_OUT <= value_bufor((12 * position_int) + i) - value_half_mean;
-- 	  end if;
-- 	end loop;
        
        --          sygnal ( 12(x+1)-1 downto 12*x ) - sygnal w chwili obecnej - ...
        --CF_B_OUT <= value_bufor(35 downto 24) - value_bufor(11 downto 1) - value_half_mean;
	temp_cfb <= value_bufor(11 downto 1) + value_half_mean;
        
        CF_TIME_OUT <= cf_counter;
        
      end if;
    end if;
  end if;
end process VALUE_CF_PROC;

sub1 : substractor
    port map(
        DataA  => temp_cfa,
        DataB  => value_bufor(47 downto 36),
        Result => CF_A_OUT
);

sub2 : substractor
    port map(
        DataA(10 downto 0)  => value_bufor(11 downto 1),
	DataA(11) => '0',
        DataB  => temp_cfb,
        Result => CF_B_OUT
);

-- convert_proc : process(CLOCK)
-- begin
--   if rising_edge(CLOCK) then
--     position_int <= conv_integer(unsigned(POSITION_IN));
--   end if;
-- end process convert_proc;

--liczymy sume

VALUE_TEMP_SUM_PROC : process(CLOCK) -- podanie sygnaly na ktorym proces ma sie "odswiezac"
begin
  if rising_edge(CLOCK) then -- w ktorym momencie ma sie odswiezyc
    if (RESET = '1') then  -- jesli RESET aktywny to wyzerowanie
      value_temp_sum <= (others => '0');
  elsif ( ENABLESUB_IN = '0' AND ENABLE_IN = '1') then
      value_temp_sum <= value_temp_sum + DATAIN;
  -- nie pamietam po co mialo byc to odejmowanie
  -- to jest sterowane zewnetrznym sygnalem z enablesub_in
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

  -- tutaj definiujemy z ilu probek zliczamy srednia - 16 = x"0F"
  elsif ( ENABLESUB_IN = '0' AND ENABLE_IN = '1' AND mean_counter <= x"0F") then
      value_temp_mean <= value_temp_mean + DATAIN;
      mean_counter <= mean_counter + x"01";
    end if;
  end if;
end process VALUE_TEMP_MEAN_PROC;

-- asynchroniczne przepisywanie wartosci lokalnego sygnalu na port
-- dzielimy srednia przez 16 bo z tylu probek liczmy srednia
-- patrz licznik w powyzszej procedurze -> x"0F"

MEAN_OUT <= value_temp_mean(15 downto 4);


end architecture;