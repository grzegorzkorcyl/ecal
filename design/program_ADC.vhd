----------------------------------------------------------------------------------
-- program_ADC 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.shower_components.all;

entity program_ADC is
	port( RESET				: in std_logic;
        CLOCK				: in std_logic;
        START_IN		    	: in std_logic;
        ADC_READY_OUT	  	: out std_logic;
        CSB_OUT				    : out std_logic;
        SDIO_INOUT		  	: inout std_logic;
        SCLK_OUT 			    : out std_logic;
        ADC_SELECT_IN	  	: in std_logic;
        MEMORY_ADDRESS_IN	: in std_logic_vector(7 downto 0);
        DATA_IN		        : in std_logic_vector(31 downto 0);
        DATA_OUT		      : out std_logic_vector(31 downto 0));
end program_ADC;

architecture Behavioral of program_ADC is

type SPI_type is (idle, select_adc, wait_after_cs, adr_clock_high, adr_clock_high1, adr_clock_low, send_adr, send_data, 
                  send_clock_high, send_clock_high1, send_clock_low, read_data, read_clock_high, read_clock_high1, 
                  read_clock_low, wait_for_finish);

signal spi_state, next_spi_state : SPI_type;
signal ADC_ADDR_AND_DATA_REGISTER : std_logic_vector(23 downto 0);
signal ADC_READ_DATA_REGISTER : std_logic_vector(7 downto 0);
signal BIT_COUNTER : std_logic_vector(4 downto 0);
signal READ_WRITE_INT : std_logic;

signal slow_down_counter : std_logic_vector(1 downto 0);

signal CSB_REG_OUT : std_logic;

begin

SCLK_OUT <= '1' when spi_state = adr_clock_high or 
                     spi_state = adr_clock_high1 or 
                     spi_state = send_clock_high or 
                     spi_state = send_clock_high1 or 
                     spi_state = read_clock_high or
                     spi_state = read_clock_high1 
         else '0';

CSB_OUT <= CSB_REG_OUT;
DATA_OUT  <= (others => '0');

READ_WRITE_INT <= '0';    -- only write

ADC_READY_OUT  <= '1' when spi_state = wait_for_finish else '0';
--will not work. On the slow control channel the ACK has to be given within 16 clock cycles.

ADC_CSB: process(reset, clock, ADC_SELECT_IN, spi_state) begin
if rising_edge(clock) then
  if(reset = '1') then
   CSB_REG_OUT <= '1';
   elsif CSB_REG_OUT = '1' then
     CSB_REG_OUT <= not ADC_SELECT_IN;
   elsif spi_state = wait_for_finish then
     CSB_REG_OUT <= '1';
  end if;
end if;
end process ADC_CSB;

WRITE_ADC: process (spi_state, CLOCK, ADC_ADDR_AND_DATA_REGISTER) begin
if rising_edge (clock) then
	case spi_state is
		when select_adc		  	=> SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
	  when wait_after_cs		=> SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
		when adr_clock_high		=> SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
		when adr_clock_low		=> SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
		when send_adr			    => SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
		when send_clock_high	=> SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
		when send_clock_low		=> SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
		when send_data			  => SDIO_INOUT <= ADC_ADDR_AND_DATA_REGISTER(23);
	end case;
end if;
end process WRITE_ADC;

SPI_INTERFACE: process (spi_state, START_IN, READ_WRITE_INT, BIT_COUNTER)
begin
	case spi_state is
		when idle	                => if START_IN = '1' then
					                 next_spi_state <= select_adc;
				                   else
					                 next_spi_state <= idle;
				                   end if;

		when select_adc			=> next_spi_state <= wait_after_CS;

	        when wait_after_CS              => next_spi_state <= adr_clock_high;
		
		when adr_clock_high		=> next_spi_state <= adr_clock_high1;

	        when adr_clock_high1            => next_spi_state <= adr_clock_low;

		when adr_clock_low		=> next_spi_state <= send_adr;
		
		when send_adr			=> if BIT_COUNTER = "10000" then
							if READ_WRITE_INT = '0' then					
								next_spi_state <= send_clock_high;
							else
								next_spi_state <= read_clock_high;
							end if;
					           else
							next_spi_state <= adr_clock_high;
					           end if;

		when send_clock_high	        => next_spi_state <= send_clock_high1;

                when send_clock_high1           => next_spi_state <= send_clock_low;
	
		when send_clock_low	        => next_spi_state <= send_data;

		when send_data			=> if BIT_COUNTER = "11000" then
							next_spi_state <= wait_for_finish;
					   	   else
							next_spi_state <= send_clock_high;
						   end if;
									

		when read_clock_high	        => next_spi_state <= read_clock_high1;

                when read_clock_high1           => next_spi_state <= read_clock_low;
		
		when read_clock_low	        => next_spi_state <= read_data;

		when read_data		        => if BIT_COUNTER = "11000" then
						       next_spi_state <= wait_for_finish;
					           else
						       next_spi_state <= read_clock_high;
					           end if;
									
		
		when wait_for_finish	        => if START_IN = '0' then
						      next_spi_state <= idle;
					           else
						      next_spi_state <= wait_for_finish;
					           end if;

	       when others			=> next_spi_state <= idle;

       end case;

end process SPI_INTERFACE; 


slowDownCounter: process(RESET, CLOCK) begin
if rising_edge(clock) then
	if(RESET = '1') then
		slow_down_counter <= "00";
	else
                slow_down_counter <= slow_down_counter + 1;
	end if;
end if;
end process slowDowncounter;

NEXT_STATE_GEN: process(RESET, CLOCK) begin
if rising_edge(clock) then
	if(RESET = '1') then
		spi_state <= idle;
	else
              if (slow_down_counter = "00") then
		spi_state <= next_spi_state;
              else
                null;
              end if;
	end if;
end if;
end process NEXT_STATE_GEN;

ADDRESS_AND_DATA_SHIFT: process(CLOCK, spi_state) begin
if rising_edge(CLOCK) then
	if(spi_state = idle) then
		ADC_ADDR_AND_DATA_REGISTER(23 downto 8) <= READ_WRITE_INT & DATA_IN(31 downto 30) & "00000" & MEMORY_ADDRESS_IN;
		ADC_ADDR_AND_DATA_REGISTER(7 downto 0) <= DATA_IN(7 downto 0);
	elsif (spi_state = adr_clock_high) or (spi_state = send_clock_high) then
             if (slow_down_counter = "00") then
		ADC_ADDR_AND_DATA_REGISTER <= ADC_ADDR_AND_DATA_REGISTER(22 downto 0) & ADC_ADDR_AND_DATA_REGISTER(23);
             end if;
	end if;
end if;
end process ADDRESS_AND_DATA_SHIFT;

READ_SHIFT: process(CLOCK, spi_state) begin
if rising_edge(CLOCK) then
	if(spi_state = send_adr) then
		ADC_READ_DATA_REGISTER <= (others => '0');
	elsif spi_state = read_clock_low then
             if (slow_down_counter = "00") then
		ADC_READ_DATA_REGISTER <= ADC_READ_DATA_REGISTER(6 downto 0) & SDIO_INOUT;
             end if;
	end if;
end if;
end process READ_SHIFT;

COUNT_BITS: process(CLOCK, spi_state) begin
if rising_edge(CLOCK) then
	if(spi_state = idle) then
		BIT_COUNTER <= (others => '0');
	elsif (spi_state = adr_clock_high) or (spi_state = send_clock_high) or (spi_state = read_clock_high) then
              if (slow_down_counter = "00") then
		BIT_COUNTER <= BIT_COUNTER + 1;
              end if;
           else
                null;
	end if;
end if;
end process COUNT_BITS;

end Behavioral;
