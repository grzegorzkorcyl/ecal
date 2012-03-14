
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.shower_components.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
--use IEEE.STD_LOGIC_ARITH.all;

entity data_buffer is
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
      THRESHOLD_IN    : in std_logic_vector(11 downto 0);
      POSITION_IN	: in std_logic_vector(3 downto 0);
      SUM_SAMPLES_IN  : in std_logic_vector(31 downto 0);
      EVENT_SAVED_OUT : out std_logic
);
end data_buffer;

architecture data_buffer of data_buffer is

-- attribute HGROUP : string;
-- attribute HGROUP of Behavioral : architecture is "DATA_BUF";

signal buf_empty             : std_logic;
signal buf_full              : std_logic;
signal buf_data              : std_logic_vector(17 downto 0);
signal buf_q                 : std_logic_vector(17 downto 0);
signal buf_wr_en             : std_logic;
signal buf_rd_en             : std_logic;
--signal pre_ctr               : std_logic_vector(9 downto 0);
--signal total_ctr             : std_logic_vector(9 downto 0);
signal pre_ctr               : unsigned(9 downto 0);
signal total_ctr             : unsigned(9 downto 0);
signal trigger_found         : std_logic;
--signal local_max_samples     : std_logic_vector(9 downto 0);
signal local_max_samples     : unsigned(9 downto 0);
--signal local_trg_pos         : std_logic_vector(9 downto 0);
signal local_trg_pos         : unsigned(9 downto 0);
signal local_event_saved     : std_logic;
signal local_clear           : std_logic;
signal local_osc_mode        : std_logic;
signal wr_en                 : std_logic;
signal sum_ctr               : std_logic_vector(31 downto 0);
signal test_data             : std_logic_vector(17 downto 0);
signal temp_data             : std_logic_vector(17 downto 0);
signal local_sum_samples     : std_logic_vector(31 downto 0);
signal local_data_in         : std_logic_vector(9 downto 0);
signal local_wr_en_in        : std_logic;
signal dsp_cf_a              : std_logic_vector(11 downto 0);
signal dsp_cf_b              : std_logic_vector(11 downto 0);
signal dsp_cf_t              : std_logic_vector(11 downto 0);
signal dsp_mean              : std_logic_vector(11 downto 0);
signal dsp_sum               : std_logic_vector(31 downto 0);
signal dsp_wr_en             : std_logic;
signal dsp_substr_en         : std_logic;
signal dsp_cf_en             : std_logic;
signal values_selector       : std_logic_vector(3 downto 0);
signal buf_aempty            : std_logic;
signal dsp_data              : std_logic_vector(11 downto 0);

attribute syn_preserve : boolean;
attribute syn_keep : boolean;
attribute syn_keep of EVENT_SAVED_OUT : signal is true;
attribute syn_preserve of EVENT_SAVED_OUT : signal is true;
-- attribute syn_keep of local_trg_pos : signal is true;
-- attribute syn_preserve of local_trg_pos : signal is true;
-- attribute syn_keep of local_max_samples : signal is true;
-- attribute syn_preserve of local_max_samples : signal is true;
attribute syn_keep of local_event_saved : signal is true;
attribute syn_preserve of local_event_saved : signal is true;
attribute syn_keep of local_clear : signal is true;
attribute syn_preserve of local_clear : signal is true;
-- attribute syn_keep of local_osc_mode : signal is true;
-- attribute syn_preserve of local_osc_mode : signal is true;
-- attribute syn_keep of local_sum_samples : signal is true;
-- attribute syn_preserve of local_sum_samples : signal is true;
attribute syn_keep of wr_en : signal is true;
attribute syn_preserve of wr_en : signal is true;
attribute syn_keep of local_wr_en_in : signal is true;
attribute syn_preserve of local_wr_en_in : signal is true;
attribute syn_keep of local_data_in : signal is true;
attribute syn_preserve of local_data_in : signal is true;
attribute syn_keep of pre_ctr : signal is true;
attribute syn_preserve of pre_ctr : signal is true;
attribute syn_keep of total_ctr : signal is true;
attribute syn_preserve of total_ctr : signal is true;
attribute syn_keep of buf_wr_en : signal is true;
attribute syn_preserve of buf_wr_en : signal is true;
attribute syn_keep of buf_rd_en : signal is true;
attribute syn_preserve of buf_rd_en : signal is true;
attribute syn_keep of trigger_found : signal is true;
attribute syn_preserve of trigger_found : signal is true;
attribute syn_keep of sum_ctr : signal is true;
attribute syn_preserve of sum_ctr : signal is true;
attribute syn_keep of dsp_data : signal is true;
attribute syn_preserve of dsp_data : signal is true;
attribute syn_keep of dsp_cf_en : signal is true;
attribute syn_preserve of dsp_cf_en : signal is true;
attribute syn_keep of dsp_wr_en : signal is true;
attribute syn_preserve of dsp_wr_en : signal is true;
attribute syn_keep of dsp_substr_en : signal is true;
attribute syn_preserve of dsp_substr_en : signal is true;

begin

SYNC_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    --DATA_OUT               <= buf_q(15 downto 0);
    EVENT_SAVED_OUT        <= local_event_saved;
    local_clear            <= CLEAR or RESET;
    local_data_in          <= DATA_IN;
    local_wr_en_in         <= WR_EN_IN;

    if (CLEAR = '1') then
      local_max_samples      <= unsigned(MAX_SAMPLES_IN);
      local_trg_pos          <= unsigned(TRIGGER_POS_IN);
      local_osc_mode         <= OSC_MODE_IN;
      local_sum_samples      <= SUM_SAMPLES_IN;
    end if;

  end if;
end process;

DSP_PROCESSOR : start
port map(
  CLOCK		=> CLK,
  RESET		=> local_clear,  -- rest after each readout

  DATAIN	=> dsp_data, --buf_data(11 downto 0),
  DATASUBIN	=> buf_q(11 downto 0),

  TRESHOLD_IN   => THRESHOLD_IN,

  POSITION_IN	=> POSITION_IN,

  ENABLESUB_IN	=> dsp_substr_en,
  ENABLECF_IN	=> dsp_cf_en,
  ENABLE_IN	=> dsp_wr_en,
  
  SUM_OUT	=> dsp_sum,
  MEAN_OUT	=> dsp_mean,
  CF_A_OUT	=> dsp_cf_a,
  CF_B_OUT	=> dsp_cf_b,
  CF_TIME_OUT	=> dsp_cf_t
);

dsp_data <= buf_q(11 downto 0) when dsp_cf_en = '1' else buf_data(11 downto 0);

dsp_cf_en <= '1' when ((RD_EN_IN = '1') and (trigger_found = '1')) else '0';  -- calculate cf while thereading samples from the fifo

dsp_wr_en <= '1' when ((local_wr_en_in = '1') and (total_ctr <= local_max_samples) and (OSC_MODE_IN = '1')) else '0';  -- add each incoming sample to the sum

dsp_substr_en <= '1' when ((pre_ctr = local_trg_pos) and (trigger_found = '0') and (local_wr_en_in = '1') and (OSC_MODE_IN = '1')) else '0'; -- substract rejected samples


-- part that inserts dsp results at the end of buffered samples
VALUES_SELECTOR_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') or (local_clear = '1') then
      values_selector <= x"0";
--     elsif (buf_aempty = '1' and buf_empty = '0') then
--       values_selector <= x"1";
    elsif (buf_empty = '1') and (buf_rd_en = '1') then
      values_selector <= values_selector + x"1";
    end if;
  end if;
end process VALUES_SELECTOR_PROC;

DATA_OUT_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') or (local_clear = '1') then
      DATA_OUT <= (others => '0');
    elsif (buf_empty = '0') then
      DATA_OUT <= buf_q(15 downto 0);
    else
      case values_selector is

	when x"0" =>
	  DATA_OUT <= buf_q(15 downto 0);

	when x"1" =>
	  DATA_OUT <= dsp_sum(15 downto 0);
	when x"2" =>
	  DATA_OUT <= dsp_sum(31 downto 16);

	when x"3" =>
	  DATA_OUT <= x"1" & dsp_mean;

	when x"4" =>
	  DATA_OUT <= x"2" & dsp_cf_a;

	when x"5" =>
	  DATA_OUT <= x"3" & dsp_cf_b;

	when x"6" =>
	  DATA_OUT <= x"4" & dsp_cf_t;

	when others =>
	  DATA_OUT <= x"cafe";

      end case;      
    end if;
  end if;
end process DATA_OUT_PROC;








THE_BUFFER : fifo_1kx18
port map(
    Data    => buf_data,
    WrClock => CLK,
    RdClock => CLK,
    WrEn    => buf_wr_en,
    RdEn    => buf_rd_en,
    Reset   => local_clear,
    RPReset => local_clear,
    Q       => buf_q,
    Empty   => buf_empty,
    Full    => buf_full,
    AlmostEmpty => buf_aempty
);

buf_wr_en <= '1' when ((local_wr_en_in = '1') and (total_ctr <= local_max_samples) and (local_osc_mode = '1'))  -- write only max number samples
                  or ((local_osc_mode = '0') and (wr_en = '1') and (total_ctr <= local_max_samples))
                  else '0';

buf_rd_en <= '1' when ((RD_EN_IN = '1') and (trigger_found = '1'))  -- read from fifo when readout
                  or ((pre_ctr = local_trg_pos) and (trigger_found = '0') and (local_wr_en_in = '1') and (local_osc_mode = '1'))  -- read when pre part filled and trigger didnt arrive
                  or ((pre_ctr = local_trg_pos) and (trigger_found = '0') and (wr_en = '1') and (local_osc_mode = '0'))
                  else '0';

buf_data(15 downto 0)   <= "000000" & local_data_in when (local_osc_mode = '1') else temp_data(15 downto 0);
buf_data(17 downto 16) <= (others => '0');

local_event_saved <= '1' when (total_ctr = local_max_samples)
                        else '0';

TEMP_DATA_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') then
      temp_data <= (others => '0');
    elsif (local_osc_mode = '0') and (local_wr_en_in = '1') and (sum_ctr /= local_sum_samples) then
      temp_data <= temp_data + local_data_in;
    elsif (sum_ctr = local_sum_samples) then
      temp_data <= (others => '0');
    end if;
  end if;
end process TEMP_DATA_PROC;

SUM_CTR_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') or (local_clear = '1') then
      sum_ctr <= (others => '0');
    elsif ((local_osc_mode = '0') and (local_wr_en_in = '1') and (sum_ctr /= local_sum_samples)) then
      sum_ctr <= sum_ctr + x"1";
    elsif (sum_ctr = local_sum_samples) then
      sum_ctr <= (others => '0');
    end if;
  end if;
end process SUM_CTR_PROC;

wr_en <= '1' when ((sum_ctr = local_sum_samples) and (local_osc_mode = '0'))
	      else '0';

TRIGGER_FOUND_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') or (local_clear = '1') then
      trigger_found <= '0';
    elsif (pre_ctr <= local_trg_pos) and (TRIGGER_IN = '1') then
      trigger_found <= '1';
    end if;
  end if;
end process;

PRE_CTR_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') or (local_clear = '1') then
      pre_ctr <= (others => '0');
    elsif (trigger_found = '0') and (buf_wr_en = '1') and (pre_ctr < local_trg_pos) then
      pre_ctr <= pre_ctr + x"1";
    end if;
  end if;
end process PRE_CTR_PROC;

TOTAL_CTR_PROC : process(CLK)
begin
  if rising_edge(CLK) then
    if (RESET = '1') or (local_clear = '1') then
      total_ctr <= (others => '0');
    elsif (buf_wr_en = '1') and (buf_rd_en = '0') then
      total_ctr <= total_ctr + x"1";
    end if;
  end if;
end process TOTAL_CTR_PROC;

end architecture;

