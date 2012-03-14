----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:19:23 09/27/2008 
-- Design Name: 
-- Module Name:    read_ADCs - Behavioral 
-- Project Name: 

-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.all;
use work.shower_components.all;

entity read_ADC is
       generic (
         IOFF_DELAY   : std_logic_vector(3 downto 0) :=  "0000";
	 ADC_ID       : integer range 0 to 7 := 0
         );

    port (  RESET         : in std_logic;
        CLOCK             : in std_logic;

--         --Pedestal / connection to bus handler
        PED_DATA_IN            : in std_logic_vector(9 downto 0);
        PED_DATA_OUT           : out std_logic_vector(9 downto 0);
        TRB_PED_ADDR_IN        : in std_logic_vector(8 downto 0);
        PED_READ_IN            : in std_logic;
        PED_WRITE_IN           : in std_logic;
        PED_READ_ACK_OUT       : out std_logic;
        PED_WRITE_ACK_OUT      : out std_logic;
        PED_BUSY_OUT           : out std_logic;
        PED_UNKNOWN_OUT        : out std_logic;
  
      IOFF_DELAY_IN             : in std_logic_vector(3 downto 0);
      LOCAL_ID_IN               : in std_logic_vector(3 downto 0);
      SAMPLING_PATTERN_IN       : in std_logic_vector (3 downto 0);
      THRESHOLD_IN              : in std_logic_vector (3 downto 0);

         --ADC inputs
      ADC_DATA_CLOCK_IN       : in std_logic;
      ADC_FRAME_CLOCK_IN      : in std_logic;
      ADC_SERIAL_IN   : in std_logic_vector(7 downto 0);

--         --Control signals from FEB
-- 10 ns pulse when FEB multiplexer advances input channel
      FEB_MUX_NEW_CHAN_RDY_IN : in std_logic;
      ADC_VALID_SYNCH_OUT     : out std_logic;

      --  data interface to endpint handler
      FEE_TRG_TYPE_IN           : in std_logic_vector(3  downto 0);
      FEE_TRG_RELEASE_OUT       : out std_logic;
      FEE_TRG_DATA_VALID_IN     : in std_logic;
      FEE_VALID_TIMING_TRG_IN   : in std_logic;
      FEE_VALID_NOTIMING_TRG_IN : in std_logic;
      FEE_DATA_OUT              : out std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT        : out std_logic;
      FEE_DATA_FINISHED_OUT     : out std_logic;

         --Data Output to ipu_handler
        IPU_DAT_DATA_OUT        : out std_logic_vector(26 downto 0);
        IPU_DAT_DATA_READ_IN    : in std_logic;
        IPU_DAT_DATA_EMPTY_OUT  : out std_logic;
        IPU_HDR_DATA_OUT        : out std_logic_vector(17 downto 0);
        IPU_HDR_DATA_READ_IN    : in std_logic;
        IPU_HDR_DATA_EMPTY_OUT  : out std_logic;

-- outputs to trb Slow Control REGIO_STAT_REG
        SERPAR_INPUT_FIFO_EMPTY :out std_logic;
        SERPAR_INPUT_FIFO_FULL  :out std_logic;
       --Debug

        WRITE_STATE_OUT        : out std_logic_vector(3 downto 0);  -- gk 02.11.10
	DESYNC_OUT              : out std_logic;

        TRIGGER_POS_IN          : in std_logic_vector(9 downto 0);  -- gk 21.12.10
        MAX_SAMPLES_IN          : in std_logic_vector(9 downto 0);  -- gk 21.12.10
        OSC_MODE_IN             : in std_logic;  -- gk 10.01.11
        SUM_SAMPLES_IN          : in std_logic_vector(31 downto 0);
	THRESHOLD_CF_IN         : in std_logic_vector(11 downto 0);
	POSITION_IN	: in std_logic_vector(3 downto 0);

        ENABLE_DEBUG_IN         : in std_logic;
        ADC_INSPECT_BUS         : out std_logic_vector(35 downto 0)
);
end read_ADC;

architecture Behavioral of read_ADC is

attribute HGROUP : string;
attribute HGROUP of Behavioral : architecture is "ADC_chip";

type ADC_INPUT_VECTOR_ARRAY is array (7 downto 0) of std_logic_vector(0 downto 0);
type ADC_CHANN_ARRAY_12BIT is array (8 downto 1) of unsigned (11 downto 0);

type write_state_type is (IDLE, WAIT_FOR_BUFFERS, WRITE_CHANNEL, NEXT_SAMPLE, EVENT_FINISHED, TRIGGER_RELEASE, EVENT_FINISHED_SYNCH);

type PEDESTAL_DATA_ARRAY is array (8 downto 1) of unsigned (15 downto 0);

signal write_state, next_write_state : write_state_type;

attribute syn_encoding: string;
attribute syn_encoding of write_state: signal is "safe,onehot";

signal COLUMN_COUNTER : unsigned (10 downto 0);
signal PEDESTAL_ADDRESS : std_logic_vector(4 downto 0);
signal WIDE_ADC_BUS  : std_logic_vector(79 downto 0);
--signal WIDER_ADC_BUS  : unsigned(95 downto 0);
signal ADC_IN_BUS : std_logic_vector(15 downto 0);
signal ADC_THRESHOLD_BUS : std_logic_vector(9 downto 0);
signal channel_threshold : PEDESTAL_OUT_ARRAY;
signal WRITE_PEDESTAL : std_logic_vector(8 downto 1);
signal ADC_INPUT_VECTOR     : ADC_INPUT_VECTOR_ARRAY;
signal ADC_INPUT_7, ADC_INPUT_6, ADC_INPUT_5, ADC_INPUT_4 : std_logic_vector(0 downto 0);
signal ADC_INPUT_3, ADC_INPUT_2, ADC_INPUT_1, ADC_INPUT_0 : std_logic_vector(0 downto 0);
signal FRAME_CLOCK_VECTOR : std_logic_vector(0 downto 0);
signal sampled_FRAME_CLOCK : std_logic_vector(1 downto 0);
signal sampled_ADC_INPUT : std_logic_vector(15 downto 0);
signal execute_write : std_logic;
signal ADC_RESULT_VALID, serpar_full, serpar_empty : std_logic;

signal integrator, average : ADC_CHANN_ARRAY_12BIT; 

signal sampling_end : std_logic_vector (7 downto 0);
signal current_sampling_pattern : std_logic_vector (5 downto 0);
signal delayed_start : std_logic_vector (8 downto 0);
signal start_extended: std_logic;
signal channel_counter : unsigned (3 downto 0);
signal comp_result, threshold_comparison_status : std_logic_vector (7 downto 0);
signal add_result : std_logic_vector (95 downto 0);

signal inverted_sampling_pattern : std_logic_vector (0 to 3);
signal fee_trg_type: std_logic_vector(3  downto 0);
signal fee_data_finished : std_logic;
signal fee_data_write : std_logic;

signal pedestal_calculation : std_logic;
signal PEDESTAL_DATA_IN_16, pedestal_sum : PEDESTAL_DATA_ARRAY;

signal state_bits: std_logic_vector(3 downto 0);
signal SERPAR_INSPECT_BUS: std_logic_vector(31 downto 0);

signal delayed_write_ack, delayed_read_ack : std_logic_vector(2 downto 0);

signal pedestals_ctr_lock : std_logic;
signal pedestals_ctr      : unsigned(3 downto 0);
signal ped_divider        : integer range 0 to 6;

-- gk 21.12.10
signal samples_ctr        : unsigned(7 downto 0);
signal buffers_ready      : std_logic_vector(7 downto 0);
signal reset_buffers      : std_logic;
signal buf_rd_en          : std_logic;

signal local_max_samples     : std_logic_vector(9 downto 0);
signal local_trg_pos         : std_logic_vector(9 downto 0);
signal local_osc_mode        : std_logic;
signal local_sum_samples     : std_logic_vector(31 downto 0);
signal local_trg             : std_logic;

type ADC_DATA_ARRAY is array (7 downto 0) of std_logic_vector(15 downto 0);
signal adc_data : ADC_DATA_ARRAY;

attribute syn_preserve : boolean;
attribute syn_keep : boolean;
attribute syn_keep of COLUMN_COUNTER : signal is true;
attribute syn_preserve of COLUMN_COUNTER : signal is true;

attribute syn_preserve of pedestal_calculation : signal is true;
attribute syn_keep of pedestal_calculation : signal is true;
attribute syn_preserve of fee_trg_type : signal is true;
attribute syn_keep of fee_trg_type : signal is true;
attribute syn_preserve of write_state : signal is true;
attribute syn_keep of write_state : signal is true;
attribute syn_preserve of average : signal is true;
attribute syn_keep of integrator : signal is true;
attribute syn_preserve of WRITE_PEDESTAL : signal is true;
attribute syn_keep of WRITE_PEDESTAL : signal is true;
attribute syn_preserve of next_write_state : signal is true;
attribute syn_keep of next_write_state : signal is true;
attribute syn_preserve of local_max_samples : signal is true;
attribute syn_keep of local_max_samples : signal is true;
attribute syn_preserve of local_trg_pos : signal is true;
attribute syn_keep of local_trg_pos : signal is true;
attribute syn_preserve of local_osc_mode : signal is true;
attribute syn_keep of local_osc_mode : signal is true;
attribute syn_preserve of local_sum_samples : signal is true;
attribute syn_keep of local_sum_samples : signal is true;
attribute syn_preserve of local_trg : signal is true;
attribute syn_keep of local_trg : signal is true;

begin

FEE_DATA_FINISHED_OUT <= fee_data_finished;
FEE_DATA_WRITE_OUT <= fee_data_write;
FRAME_CLOCK_VECTOR(0) <= ADC_FRAME_CLOCK_IN;

local_trg <= FEE_VALID_NOTIMING_TRG_IN or FEE_VALID_TIMING_TRG_IN;

--gk 08.11.10
SYNC_PROC : process(CLOCK)
begin
  if rising_edge(CLOCK) then
    WRITE_STATE_OUT   <= state_bits;
    local_trg_pos     <= TRIGGER_POS_IN;
    local_max_samples <= MAX_SAMPLES_IN;
    local_osc_mode    <= OSC_MODE_IN;
    if (write_state = EVENT_FINISHED) or (RESET = '1') then
      local_sum_samples <= SUM_SAMPLES_IN;
    end if;
  end if;
end process SYNC_PROC;

ADC_VALID_SYNCH_OUT <= ADC_RESULT_VALID;

ADC_INPUT_7(0) <= ADC_SERIAL_IN(7);
ADC_INPUT_6(0) <= ADC_SERIAL_IN(6);
ADC_INPUT_5(0) <= ADC_SERIAL_IN(5);
ADC_INPUT_4(0) <= ADC_SERIAL_IN(4);
ADC_INPUT_3(0) <= ADC_SERIAL_IN(3);
ADC_INPUT_2(0) <= ADC_SERIAL_IN(2);
ADC_INPUT_1(0) <= ADC_SERIAL_IN(1);
ADC_INPUT_0(0) <= ADC_SERIAL_IN(0);

ADC_INSPECT_BUS <= x"0000000" & delayed_start(8) & sampling_end(5) & start_extended & ADC_RESULT_VALID & SERPAR_INSPECT_BUS(23 downto 20);

  THE_FCLK_DDR_FF : ddr_input_ff --ddr_iff_sysclk 
        port map(
            Del  => "0000",
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => FRAME_CLOCK_VECTOR,
            Q    => sampled_FRAME_CLOCK
            );

  THE_DATA_DDR_FF_0 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_0,
            Q(0)    => sampled_ADC_INPUT(1),
            Q(1)    => sampled_ADC_INPUT(0)
            );
  THE_DATA_DDR_FF_1 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,  
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_1,
            Q(0)    => sampled_ADC_INPUT(3),
            Q(1)    => sampled_ADC_INPUT(2)
            );
  THE_DATA_DDR_FF_2 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_2,
            Q(0)    => sampled_ADC_INPUT(5),
            Q(1)    => sampled_ADC_INPUT(4)
            );
  THE_DATA_DDR_FF_3 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_3,
            Q(0)    => sampled_ADC_INPUT(7),
            Q(1)    => sampled_ADC_INPUT(6)
            );
  THE_DATA_DDR_FF_4 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_4,
            Q(0)    => sampled_ADC_INPUT(9),
            Q(1)    => sampled_ADC_INPUT(8)
            );
  THE_DATA_DDR_FF_5 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_5,
            Q(0)    => sampled_ADC_INPUT(11),
            Q(1)    => sampled_ADC_INPUT(10)
            );
  THE_DATA_DDR_FF_6 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_6,
            Q(0)    => sampled_ADC_INPUT(13),
            Q(1)    => sampled_ADC_INPUT(12)
            );
  THE_DATA_DDR_FF_7 : ddr_input_ff --ddr_iff_sysclk  
        port map(
            Del  => IOFF_DELAY_IN,
            CLK  => ADC_DATA_CLOCK_IN, --ECLK  => ADC_DATA_CLOCK_IN,
            --SCLK => CLOCK,
            Rst  => RESET,
            Data => ADC_INPUT_7,
            Q(0)    => sampled_ADC_INPUT(15),
            Q(1)    => sampled_ADC_INPUT(14)
            );

ADC: serpar2 port map (
    RESET         => RESET,
    ADC_CLOCK       => ADC_DATA_CLOCK_IN,
    SYS_CLOCK       => CLOCK,
    ADC_INPUT       => sampled_ADC_INPUT,
    FRAME_CLOCK     => sampled_FRAME_CLOCK,
    ADC_RESULT_OUT    => WIDE_ADC_BUS,
    ADC_RESULT_VALID_OUT  => ADC_RESULT_VALID,
      fifo_full       => SERPAR_INPUT_FIFO_FULL,
      fifo_empty      => SERPAR_INPUT_FIFO_EMPTY,
    debug             => SERPAR_INSPECT_BUS
    );

-- gk 21.12.10
buffers_gen : for i in 0 to 0 generate
BUF : data_buffer
    port map (
      RESET           => RESET,
      CLK             => CLOCK,
      CLEAR           => reset_buffers,
      -- data input from ADC
      DATA_IN         => WIDE_ADC_BUS(i * 10 + 9 downto i * 10),
      WR_EN_IN        => ADC_RESULT_VALID,
      -- data output to the endpoint
      RD_EN_IN        => buf_rd_en,
      DATA_OUT        => adc_data(i)(15 downto 0),
      -- trigger input and settings
      TRIGGER_IN      => local_trg, --FEE_VALID_TIMING_TRG_IN,  -- gk 01.06.11
      TRIGGER_POS_IN  => local_trg_pos,
      MAX_SAMPLES_IN  => local_max_samples,
      OSC_MODE_IN     => local_osc_mode,
      THRESHOLD_IN    => THRESHOLD_CF_IN,
      POSITION_IN	=> POSITION_IN,
      SUM_SAMPLES_IN  => local_sum_samples,
      EVENT_SAVED_OUT => buffers_ready(i)
);
end generate;



reset_buffers <= '1' when (write_state = EVENT_FINISHED)
                      else '0';

buf_rd_en <= '1' when ((write_state = NEXT_SAMPLE) and (std_logic_vector(samples_ctr) < (local_max_samples + x"6")))
                  or ((write_state = WAIT_FOR_BUFFERS) and (buffers_ready = x"ff"))
                  else '0';

DESYNC_PROC : process(CLOCK)
begin
  if rising_edge(CLOCK) then
    if (RESET = '1') then
      DESYNC_OUT <= '0';
    elsif ((buffers_ready /= x"ff") and (buffers_ready /= x"00")) then
      DESYNC_OUT <= '1';
    end if;
  end if;
end process DESYNC_PROC;

LOCAL_RELEASE_PROCESS: process (RESET, CLOCK, write_state) begin
if rising_edge(CLOCK) then
  if(RESET = '1') then
     FEE_TRG_RELEASE_OUT <= '0';
  elsif write_state = event_finished_synch then
    FEE_TRG_RELEASE_OUT <= '1';
  else
    FEE_TRG_RELEASE_OUT <= '0';
  end if;
end if;
end process LOCAL_RELEASE_PROCESS;

FEE_DATA_FINISHED_PROCESS: process (RESET, CLOCK, write_state) begin
if rising_edge (CLOCK) then
  if (RESET = '1') then
    fee_data_finished <= '0';
  else
    if write_state = event_finished then
      fee_data_finished <= '1';
    else
      fee_data_finished <= '0';
    end if;
  end if;
end if; 
end process FEE_DATA_FINISHED_PROCESS;

FEE_TRG_TYPE_VALID_PROCESS: process (RESET, CLOCK, FEE_TRG_DATA_VALID_IN) begin
if rising_edge (CLOCK) then
  if (RESET = '1') then
    fee_trg_type <= "0001";
  else
    if FEE_TRG_DATA_VALID_IN = '1' then
--    if FEE_VALID_TIMING_TRG_IN = '1' or FEE_VALID_NOTIMING_TRG_IN = '1' then
      fee_trg_type <= FEE_TRG_TYPE_IN;
    else
      fee_trg_type <= "0001";
    end if;
  end if;
end if; 
end process FEE_TRG_TYPE_VALID_PROCESS;

START_EXTENDED_PROCESS: process (RESET, CLOCK, FEB_MUX_NEW_CHAN_RDY_IN) begin
if rising_edge (CLOCK) then
  if (RESET = '1') then
    start_extended <= '0';
  else
    if start_extended = '0' then
      if FEB_MUX_NEW_CHAN_RDY_IN = '1' then
        start_extended <= '1';
      end if;
    else
      if (delayed_start(0) = '1') then 
          start_extended <= '0';
      end if;
    end if;
  end if;
end if; 
end process START_EXTENDED_PROCESS;

SIMULATE_ADC_PIPE: process (RESET, CLOCK, ADC_RESULT_VALID) begin
if rising_edge (CLOCK) then
  if (RESET = '1') then
    sampling_end <= (others => '0');
  else
    if (ADC_RESULT_VALID = '1') then             -- register shifts synchronously with ADC results (20 MSPS: every 50 ns)
      sampling_end <= sampling_end (6 downto 0) & delayed_start(7);  -- kk (8)
    end if;
  end if;
end if;
end process SIMULATE_ADC_PIPE;

DELAYED_COLUMN_PROCESS: process (RESET, CLOCK, ADC_RESULT_VALID) begin
if rising_edge (CLOCK) then
  if (RESET = '1') then
    delayed_start <= (others => '0');
  else
    if (ADC_RESULT_VALID = '1') then             -- register shifts synchronously with ADC results (20 MSPS: every 50 ns)
      delayed_start <= delayed_start (7 downto 0) & start_extended;
    end if;
  end if;
end if;
end process DELAYED_COLUMN_PROCESS;

CHANNEL_COUNTER_PROCESS: process (CLOCK) begin
if rising_edge (CLOCK) then
  if (RESET = '1' or write_state = IDLE or write_state = NEXT_SAMPLE) then
    channel_counter <= (others =>'0');
  elsif (write_state = WRITE_CHANNEL) then
    channel_counter <= channel_counter + 1;
  end if;
end if;
end process CHANNEL_COUNTER_PROCESS;

FEE_DATA_OUT <= conv_std_logic_vector(ADC_ID, 4) & "0" & std_logic_vector(channel_counter (2 downto 0)) & std_logic_vector(samples_ctr) & ADC_IN_BUS;


ADC_IN_BUS_PROC: process (RESET, channel_counter)  begin
--if  rising_edge(CLOCK) then
  if (RESET = '1') then
  ADC_IN_BUS <= (others => '0');
  else
  case std_logic_vector(channel_counter(2 downto 0)) is
    when "000"    => ADC_IN_BUS <=  adc_data(0);
    when "001"    => ADC_IN_BUS <=  adc_data(1);
    when "010"    => ADC_IN_BUS <=  adc_data(2);
    when "011"    => ADC_IN_BUS <=  adc_data(3);
    when "100"    => ADC_IN_BUS <=  adc_data(4);
    when "101"    => ADC_IN_BUS <=  adc_data(5);
    when "110"    => ADC_IN_BUS <=  adc_data(6);
    when "111"    => ADC_IN_BUS <=  adc_data(7);
    when others   => ADC_IN_BUS <=  '0' & x"ac";
  end case;
  end if;
--end if;
end process ADC_IN_BUS_PROC;

DATA_VALID_PROCESS: process(RESET, CLOCK, write_state) begin
if rising_edge(CLOCK) then
  if(RESET = '1') then
    fee_data_write <= '0';
  else
    if (write_state = WRITE_CHANNEL) then
        fee_data_write <= '1';
    else
        fee_data_write <= '0';
    end if;
  end if;
end if;
end process DATA_VALID_PROCESS;

-- gk 21.12.10
SAMPLES_CTR_PROC : process(CLOCK)
begin
  if rising_edge(CLOCK) then
    if (RESET = '1') or (write_state = IDLE) then
      samples_ctr <= (others => '0');
    elsif (write_state = NEXT_SAMPLE) then
      samples_ctr <= samples_ctr + x"1";
    end if;
  end if;
end process;

NEXT_STATE_GEN: process(RESET, CLOCK) begin
if rising_edge(CLOCK) then
  if(RESET = '1') then
    write_state <= idle;
  else
    write_state <= next_write_state;
  end if;
end if;
end process NEXT_STATE_GEN;

-- gk 21.12.10
WRITE_RESULTS : process (buffers_ready, channel_counter, samples_ctr, MAX_SAMPLES_IN, FEE_TRG_DATA_VALID_IN, local_trg)
begin

    next_write_state <= IDLE;

    case write_state is

      when IDLE =>
        if (local_trg = '1') then  -- gk 01.06.11
          next_write_state <= WAIT_FOR_BUFFERS;
        else
          next_write_state <= IDLE;
        end if;

      when WAIT_FOR_BUFFERS =>
        if (buffers_ready = x"ff") then
          next_write_state <= WRITE_CHANNEL;
        else
          next_write_state <= WAIT_FOR_BUFFERS;
        end if;

      when WRITE_CHANNEL =>
        if (channel_counter = "0111") then
          next_write_state <= NEXT_SAMPLE;
        else
          next_write_state <= WRITE_CHANNEL;
        end if;

      when NEXT_SAMPLE =>
	-- gk read 6 more values which are dsp results
        --if (std_logic_vector(samples_ctr) < local_max_samples) then
	if (std_logic_vector(samples_ctr) < (local_max_samples + x"6")) then
          next_write_state <= WRITE_CHANNEL;
        else
          next_write_state <= EVENT_FINISHED;
        end if;

      when EVENT_FINISHED =>
        next_write_state <= TRIGGER_RELEASE;

      when TRIGGER_RELEASE =>
        next_write_state <= event_finished_synch;

      when EVENT_FINISHED_SYNCH => 
        if (FEE_TRG_DATA_VALID_IN = '0') then
          next_write_state <= idle;
        else
          next_write_state <= event_finished_synch;
        end if;

      when others => null;

    end case;
end process;

end Behavioral;
