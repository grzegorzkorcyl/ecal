library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library work;
--use work.adcmv3_components.all;


entity shower_spi_real_slim is
port(
	SYSCLK      : in    std_logic; -- 100MHz sysclock
	RESET       : in    std_logic; -- synchronous reset
	-- Command interface
	START_IN    : in    std_logic; -- one start pulse
	BUSY_OUT    : out   std_logic; -- SPI transactions are ongoing
	CMD_IN      : in    std_logic_vector(23 downto 0); -- SPI command byte
	-- SPI interface
	SPI_SCK_OUT : out   std_logic;
	SPI_CS_OUT  : out   std_logic;
	SPI_SDO_OUT : out   std_logic;
	-- DEBUG
	CLK_EN_OUT  : out   std_logic;
	BSM_OUT     : out   std_logic_vector(7 downto 0);
	DEBUG_OUT   : out   std_logic_vector(31 downto 0)
);
end shower_spi_real_slim;

architecture Behavioral of shower_spi_real_slim is

-- new clock divider
signal div_counter      : std_logic_vector(1 downto 0);
signal div_done_x       : std_logic;
signal div_done         : std_logic; -- same as clk_en
signal clk_en           : std_logic; -- same as div_done

-- Statemachine signals
type state_t is (IDLE,CSL,TXCMD,CSH);
signal STATE, NEXT_STATE    : state_t;

signal tx_ena_x         : std_logic;
signal tx_ena           : std_logic;
signal busy_x           : std_logic;
signal busy             : std_logic;
signal spi_cs_x         : std_logic; -- SPI chip select (low active)
signal spi_cs           : std_logic;
signal spi_sck_x        : std_logic; -- SPI clock (rising edge active, from counter)
signal spi_sck          : std_logic;
signal tx_load_x        : std_logic; -- load TX shift register
signal tx_load          : std_logic;

signal last_tx_bit_x    : std_logic;
signal last_tx_bit      : std_logic;

-- debug signals
signal bsm_x            : std_logic_vector(7 downto 0);
signal debug_x          : std_logic_vector(31 downto 0);

signal start            : std_logic; -- buffered start_in signal, as we have a clocked down state machine
signal cmd_int          : std_logic_vector(23 downto 0); -- internal command and address bytes

-- transmitter
signal tx_sreg          : std_logic_vector(23 downto 0);
signal tx_bit_cnt       : std_logic_vector(4 downto 0);

begin

-----------------------------------------------------------
-- Debug signals
-----------------------------------------------------------
debug_x(31 downto 8 ) <= tx_sreg;
debug_x(7)            <= last_tx_bit;
debug_x(6)            <= tx_load;
debug_x(5)            <= tx_ena;
debug_x(4 downto 0)   <= tx_bit_cnt;

-----------------------------------------------------------
-- SPI clock generator
-----------------------------------------------------------
THE_CLOCK_DIVIDER: process( sysclk )
begin
	if( rising_edge(sysclk) ) then
		if( reset = '1' ) then
			div_counter <= (others => '0');
			div_done    <= '0';
			spi_sck     <= '0';
		else
			div_counter <= div_counter + 1;
			div_done    <= div_done_x;
			spi_sck     <= spi_sck_x;
		end if;
	end if;
end process THE_CLOCK_DIVIDER;

div_done_x <= '1' when ( div_counter = b"00" ) else '0';

spi_sck_x  <= '1' when ( ((div_counter = b"11") or (div_counter = b"00")) and
						 (tx_ena = '1') ) else '0';

clk_en <= div_done;

-----------------------------------------------------------
-- start signal and local register sets for CMD and ADR
-----------------------------------------------------------
THE_START_PROC: process( sysclk )
begin
	if( rising_edge(sysclk) ) then
		if   ( reset = '1' ) then
			start   <= '0';
			cmd_int <= (others => '0');
		elsif( (start_in = '1') and (busy = '0') ) then
			start <= '1';
			cmd_int <= cmd_in;
		elsif( busy = '1' ) then
			start <= '0';
		end if;
	end if;
end process THE_START_PROC;

-----------------------------------------------------------
-- statemachine: clocked process
-----------------------------------------------------------
THE_STATEMACHINE: process( sysclk )
begin
	if( rising_edge(sysclk) ) then
		if   ( reset = '1' ) then
			STATE      <= IDLE;
			tx_ena     <= '0';
			busy       <= '0';
			spi_cs     <= '1';
			tx_load    <= '0';
		elsif( clk_en = '1' ) then
			STATE    <= NEXT_STATE;
			tx_ena   <= tx_ena_x;
			busy     <= busy_x;
			spi_cs   <= spi_cs_x;
			tx_load  <= tx_load_x;
		end if;
	end if;
end process THE_STATEMACHINE;

-----------------------------------------------------------
-- state machine transition table
-----------------------------------------------------------
THE_STATE_TRANSITIONS: process( STATE, start, tx_bit_cnt )
begin
	tx_ena_x   <= '0';
	busy_x     <= '1';
	spi_cs_x   <= '1';
	tx_load_x  <= '0';
	case STATE is
		when IDLE =>
			if( start = '1' ) then
				NEXT_STATE <= CSL;
				spi_cs_x   <= '0';
				tx_load_x  <= '1';
			else
				NEXT_STATE <= IDLE;
				busy_x     <= '0';
			end if;

		when CSL =>
			NEXT_STATE <= TXCMD;
			tx_ena_x   <= '1';
			spi_cs_x   <= '0';

		when TXCMD =>
			if( tx_bit_cnt < b"1_0111" ) then
				NEXT_STATE <= TXCMD;
				tx_ena_x   <= '1';
				spi_cs_x   <= '0';
			else
				NEXT_STATE <= CSH;
				spi_cs_x   <= '0';
			end if;

		when CSH =>
			NEXT_STATE <= IDLE;
			busy_x     <= '0';

		when others =>
			NEXT_STATE <= IDLE;

	end case;
end process THE_STATE_TRANSITIONS;

-- state machine output table
THE_STATEMACHINE_OUT: process( STATE )
begin
	case STATE is
		when IDLE       =>  bsm_x           <= x"00";
		when CSL        =>  bsm_x           <= x"01";
		when TXCMD      =>  bsm_x           <= x"02";
		when CSH        =>  bsm_x           <= x"03";
		when others     =>  bsm_x           <= x"ff";
	end case;
end process THE_STATEMACHINE_OUT;

-- TXData shift register and bit counter
THE_TX_SHIFT_AND_BITCOUNT: process( sysclk )
begin
	if( rising_edge(sysclk) ) then
		if   ( (clk_en = '1' ) and (tx_load = '1') ) then
			tx_bit_cnt <= (others => '0');
			tx_sreg    <= cmd_int;
		elsif( (clk_en = '1') and (tx_ena = '1') ) then
			tx_bit_cnt <= tx_bit_cnt + 1;
			tx_sreg    <= tx_sreg (22 downto 0) & '0';
		end if;
		last_tx_bit <= last_tx_bit_x;
	end if;
end process THE_TX_SHIFT_AND_BITCOUNT;

last_tx_bit_x <= '1' when ( tx_bit_cnt = b"1_0111" ) else '0'; -- 0x17 = 23

-- output signals
spi_cs_out   <= spi_cs;
spi_sck_out  <= spi_sck;
spi_sdo_out  <= tx_sreg(23);
busy_out     <= busy;

clk_en_out   <= clk_en;
bsm_out      <= bsm_x;
debug_out    <= debug_x;


end Behavioral;
