LIBRARY ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.ALL;

library work;
library ecp2m;
use ecp2m.components.all;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.shower_components.all;
use work.version.all;

entity shower_fpga1 is
  generic(
    NUM_STAT_REGS      : integer range 0 to  6         := 2;
    NUM_CTRL_REGS      : integer range 0 to  6         := 2;
    REGIO_INIT_ADDRESS : std_logic_vector(15 downto 0) := x"FF31";
    REGIO_ENDPOINT_ID  : std_logic_vector(15 downto 0) := x"0001";
    NUMBER_OF_ADC      : integer range 0 to 12         := 1;
    FPGA_NUMBER        : std_logic                     := '0'
    );
  port(
    --Clocks
    CLK_100_IN          : in  std_logic;
    CLK_125_IN          : in  std_logic;
    --Resets
    RESET_IN            : in    std_logic; -- async reset from one unused pin with pullup
    ADDON_RESET_IN      : in  std_logic;
    --FPGA1
    F1_F2               : inout std_logic_vector(23 downto 0);
    --FPGA3
    F1_F3               : inout std_logic_vector(22 downto 0);
    F3_TXP              : out std_logic;
    F3_TXN              : out std_logic;
    F3_RXP              : in  std_logic;
    F3_RXN              : in  std_logic;
    --SPI / Flash
    SPI_CLK_OUT         : out std_logic;
    SPI_CS_OUT          : out std_logic;
    SPI_SO_IN           : in  std_logic;
    SPI_SI_OUT          : out std_logic;
    PROGRAMB_OUT        : out std_logic;
    --ADC SPI
    ADC_CSB_OUT         : out std_logic_vector(6  downto 1);
    ADC_SCLK_OUT        : out std_logic_vector(6  downto 1);
    ADC_SDIO_INOUT      : inout std_logic_vector(6  downto 1);
    --ADC
    ADCCLK_OUT          : out std_logic_vector(6  downto 1);
    DCO_IN              : in  std_logic_vector(6  downto 1);
    FCO_IN              : in  std_logic_vector(6  downto 1);
    P1_IN               : in  std_logic_vector(16 downto 1);
    P2_IN               : in  std_logic_vector(16 downto 1);
    PRE_IN              : in  std_logic_vector(16 downto 1);
    --FEB
    FEB_CLK_OUT         : out std_logic;
    FEB_ENABLE_OUT      : out std_logic;
    FEB_EVEN_OUT        : out std_logic;
    FEB_HOLD_OUT        : out std_logic;
    FEB_ODD_OUT         : out std_logic;
    FEB_RBITIN_OUT      : out std_logic;
    FEB_RESET_OUT       : out std_logic;
    --Trigger
    HOLD_IN             : in  std_logic;
    SPARE_IN            : in  std_logic;
    ONEWIRE_MONITOR_IN  : in  std_logic;
    --Debug & Test connector
    TEST_LINE           : out std_logic_vector(15 downto 0)
    );
  attribute syn_useioff : boolean;
  attribute syn_useioff of SPI_CLK_OUT     : signal is true;
  attribute syn_useioff of SPI_CS_OUT      : signal is true;
  attribute syn_useioff of SPI_SO_IN       : signal is true;
  attribute syn_useioff of SPI_SI_OUT      : signal is true;

  attribute syn_useioff of F1_F2           : signal is true;
  attribute syn_useioff of F1_F3           : signal is true;

  attribute syn_useioff of ADC_CSB_OUT     : signal is true;
  attribute syn_useioff of ADC_SCLK_OUT    : signal is true;
  attribute syn_useioff of ADC_SDIO_INOUT  : signal is true;

  attribute syn_useioff of ADCCLK_OUT      : signal is true;
  attribute syn_useioff of DCO_IN          : signal is true;
  attribute syn_useioff of FCO_IN          : signal is true;
  attribute syn_useioff of P1_IN           : signal is true;
  attribute syn_useioff of P2_IN           : signal is true;
  attribute syn_useioff of PRE_IN          : signal is true;

  attribute syn_useioff of FEB_CLK_OUT     : signal is true;
  attribute syn_useioff of FEB_ENABLE_OUT  : signal is true;
  attribute syn_useioff of FEB_EVEN_OUT    : signal is true;
  attribute syn_useioff of FEB_HOLD_OUT    : signal is true;
  attribute syn_useioff of FEB_ODD_OUT     : signal is true;
  attribute syn_useioff of FEB_RBITIN_OUT  : signal is true;
  attribute syn_useioff of FEB_RESET_OUT   : signal is true;

  attribute syn_useioff of ONEWIRE_MONITOR_IN   : signal is false;

end entity;


architecture shower_fpga1_arch of shower_fpga1 is

 --Clock and Reset
  signal clk_100                 : std_logic;
  signal clk_10                  : std_logic;
  signal clk_en                  : std_logic;
  signal reset_i                 : std_logic;
  signal reset_i_q               : std_logic;
  signal reset_counter           : unsigned (19 downto 0);
  signal pll_locked              : std_logic;
  signal pll_10_locked           : std_logic;
  signal make_reset_via_network  : std_logic;

  --endpoint RegIo to bus handler
  signal regio_addr_out          : std_logic_vector (16-1 downto 0);
  signal regio_read_enable_out   : std_logic;
  signal regio_write_enable_out  : std_logic;
  signal regio_data_out          : std_logic_vector (32-1 downto 0);
  signal regio_data_in           : std_logic_vector (32-1 downto 0);
  signal regio_dataready_in      : std_logic;
  signal regio_no_more_data_in   : std_logic;
  signal regio_write_ack_in      : std_logic;
  signal regio_unknown_addr_in   : std_logic;
  signal regio_timeout_out       : std_logic;

  --SPI for flash programming
  signal spictrl_read_en         : std_logic;
  signal spictrl_write_en        : std_logic;
  signal spictrl_data_in         : std_logic_vector (31 downto 0);
  signal spictrl_addr            : std_logic;
  signal spictrl_data_out        : std_logic_vector (31 downto 0);
  signal spictrl_ack             : std_logic;
  signal spictrl_busy            : std_logic;
  signal spimem_read_en          : std_logic;
  signal spimem_write_en         : std_logic;
  signal spimem_data_in          : std_logic_vector (31 downto 0);
  signal spimem_addr             : std_logic_vector (5 downto 0);
  signal spimem_data_out         : std_logic_vector (31 downto 0);
  signal spimem_ack              : std_logic;
  signal spi_bram_addr           : std_logic_vector (7 downto 0);
  signal spi_bram_wr_d           : std_logic_vector (7 downto 0);
  signal spi_bram_rd_d           : std_logic_vector (7 downto 0);
  signal spi_bram_we             : std_logic;

  --from/to LVL1_Handler
  signal lvl1_trg_received       : std_logic;
  signal lvl1_trg_type           : std_logic_vector (3  downto 0);
  signal lvl1_information        : std_logic_vector (23 downto 0);
  signal lvl1_number             : std_logic_vector (15 downto 0);
  signal lvl1_busy               : std_logic;
  signal lvl1_buffer_warn        : std_logic;

  --LVL1 handler to IPU handler
  signal lvl1_hdr_data           : std_logic_vector (35 downto 0);
  signal lvl1_hdr_read           : std_logic;
  signal lvl1_hdr_empty          : std_logic;

  --Control signals between read_ADC and FEB
  signal adc_start               : std_logic;
  signal adc_freeze              : std_logic;
  signal adc_trg_type            : std_logic_vector (3  downto 0);
  signal adc_trg_information     : std_logic_vector (23 downto 0);
  signal adc_trg_number          : std_logic_vector (15 downto 0);
  signal adc_busy                : std_logic_vector (NUMBER_OF_ADC-1 downto 0);
  signal adc_buffer_warn         : std_logic_vector (NUMBER_OF_ADC-1 downto 0);

-- calibration hold from feb_engine
  signal internal_hold_i              : std_logic;
  signal hold_in_local            : std_logic;

  --read_ADC
  signal adc_data_inputs         : std_logic_vector (47 downto 0);
  signal adc_reset               : std_logic;

  --slow control bus to pedestal fifo
  signal ped_address_in          : std_logic_vector (9-1 downto 0);
  signal ped_data_in             : std_logic_vector (6*16-1 downto 0);
  signal ped_data_out            : std_logic_vector (6*16-1 downto 0);
  signal ped_read_en             : std_logic_vector (6-1 downto 0);
  signal ped_write_en            : std_logic_vector (6-1 downto 0);
  signal ped_read_ack            : std_logic_vector (6-1 downto 0);
  signal ped_write_ack           : std_logic_vector (6-1 downto 0);
  signal ped_no_more_data        : std_logic_vector (6-1 downto 0);
  signal ped_unknown             : std_logic_vector (6-1 downto 0);
  signal ped_busy                : std_logic_vector (6-1 downto 0);

  --Spyfifo
  signal spy1fifo_read            : std_logic;
  signal spy2fifo_read            : std_logic;
  signal spy1fifo_data_out        : std_logic_vector (31 downto 0);
  signal spy2fifo_data_out        : std_logic_vector (31 downto 0);
  signal spy1fifo_dataready       : std_logic;
  signal spy2fifo_dataready       : std_logic;
  signal spy1fifo_empty           : std_logic;
  signal spy2fifo_empty           : std_logic;
  signal spy1InputVector           : std_logic_vector(31 downto 0);
  signal spy2InputVector           : std_logic_vector(31 downto 0);
  signal spy1fifo_write         : std_logic;
  signal spy2fifo_write         : std_logic;
  signal spy1fifo_read_fifo     : std_logic;
  signal spy1_fifo_almost_full         : std_logic;
  signal spy2fifo_read_fifo     : std_logic;
  signal spy2_fifo_almost_full         : std_logic;

  --media interface to endpoint
  signal med_data_in             : std_logic_vector (16-1 downto 0);
  signal med_packet_num_in       : std_logic_vector (3-1  downto 0);
  signal med_dataready_in        : std_logic;
  signal med_read_in             : std_logic;
  signal med_data_out            : std_logic_vector (16-1 downto 0);
  signal med_packet_num_out      : std_logic_vector (3-1  downto 0);
  signal med_dataready_out       : std_logic;
  signal med_read_out            : std_logic;
  signal med_stat_op             : std_logic_vector (16-1 downto 0);
  signal med_ctrl_op             : std_logic_vector (16-1 downto 0);
  signal med_stat_debug          : std_logic_vector (64-1 downto 0);

  --endpoint LVL1 trigger
  signal trg_type                : std_logic_vector (3  downto 0);
  signal trg_valid_timing        : std_logic;
  signal trg_valid_notiming      : std_logic;
  signal trg_invalid             : std_logic;
  signal trg_data_valid          : std_logic;
  signal trg_number              : std_logic_vector (15 downto 0);
  signal trg_code                : std_logic_vector (7  downto 0);
  signal trg_information         : std_logic_vector (23 downto 0);
  signal trg_error_pattern       : std_logic_vector (31 downto 0);
  signal trg_release             : std_logic;
  signal trg_int_trg_number      : std_logic_vector (15 downto 0);
  signal trg_number_reg          : std_logic_vector (31 downto 0);
 
  --Information about trigger handler errors
  signal  trg_multiple_trg_out    : std_logic;
  signal  trg_timeout_detected_out  :std_logic;
  signal  trg_spurious_trg_out      :std_logic;
  signal  trg_missing_tmg_trg_out   :std_logic;
  signal  trg_spike_detected_out    :std_logic;

  --FEE
  signal fee_trg_release         : std_logic_vector (NUMBER_OF_ADC-1 downto 0);
  signal fee_trg_statusbits      : std_logic_vector (NUMBER_OF_ADC*32-1 downto 0);
  signal fee_data                : std_logic_vector (NUMBER_OF_ADC*32-1 downto 0);
  signal fee_data_local          : std_logic_vector (NUMBER_OF_ADC*32-1 downto 0);
  signal fee_data_write          : std_logic_vector (NUMBER_OF_ADC-1 downto 0);
  signal fee_data_finished       : std_logic_vector (NUMBER_OF_ADC-1 downto 0);
  signal fee_data_almost_full    : std_logic_vector (NUMBER_OF_ADC-1 downto 0);
  signal feb_64th_pedestal       : std_logic_vector (NUMBER_OF_ADC-1 downto 0);
  signal feb_64th_pedestal_sum    : std_logic;

 --endpoint RegIo registers
  signal regio_common_stat_reg   : std_logic_vector (std_COMSTATREG*32-1 downto 0);
  signal regio_common_ctrl_reg   : std_logic_vector (std_COMCTRLREG*32-1 downto 0);
  signal regio_common_ctrl       : std_logic_vector (std_COMCTRLREG*32-1 downto 0);
  signal regio_stat_registers    : std_logic_vector (32*2**(NUM_STAT_REGS)-1 downto 0);
  signal regio_ctrl_registers    : std_logic_vector (32*2**(NUM_CTRL_REGS)-1 downto 0);
  signal common_stat_reg_strobe  : std_logic_vector ((std_COMSTATREG)-1 downto 0);
  signal common_ctrl_reg_strobe  : std_logic_vector ((std_COMCTRLREG)-1 downto 0);
  signal stat_reg_strobe         : std_logic_vector (2**(NUM_STAT_REGS)-1 downto 0);
  signal ctrl_reg_strobe         : std_logic_vector (2**(NUM_CTRL_REGS)-1 downto 0);
  signal my_address              : std_logic_vector (15 downto 0);

  signal regio_ctrl_registers_in : std_logic_vector (32*2**(NUM_CTRL_REGS)-1 downto 0);

  signal regio_var_endpoint_id    : std_logic_vector (15 downto 0);
  signal onewire_monitor_out      : std_logic;

 --Timers
  signal timing_trigger_feedback : std_logic;
  signal global_time             : std_logic_vector (31 downto 0);
  signal local_time              : std_logic_vector (7  downto 0);
  signal time_since_last_trg     : std_logic_vector (31 downto 0);
  signal timer_ticks             : std_logic_vector (1  downto 0);

-- endpoint debugging anf status information
    signal stat_debug_ipu         : std_logic_vector (31 downto 0);
    signal stat_debug_1           : std_logic_vector (31 downto 0);
    signal stat_debug_2           : std_logic_vector (31 downto 0);
    signal stat_debug_data_handler_out  :std_logic_vector (31 downto 0);
    signal stat_debug_ipu_handler_out :std_logic_vector (31 downto 0);
    signal ctrl_mplex             : std_logic_vector (31 downto 0);
    signal iobuf_ctrl_gen         : std_logic_vector (4*32-1 downto 0);
    signal stat_onewire           : std_logic_vector (31 downto 0);
    signal stat_addr_debug        : std_logic_vector (15 downto 0);
    signal debug_lvl1_handler_out : std_logic_vector (15 downto 0);

  --Debugging registers
  signal debug_feb_engine        : std_logic_vector (15 downto 0);
  signal debug_ipu_handler       : std_logic_vector (15 downto 0);
  signal debug_lvl1_handler      : std_logic_vector (15 downto 0);
  signal debug_adc               : std_logic_vector (NUMBER_OF_ADC*36-1 downto 0);

  signal delayed_restart_fpga    : std_logic;
  signal restart_fpga_counter    : unsigned(11 downto 0);

  signal feb_mux_new_chan_rdy    : std_logic;
  signal event_taken             : std_logic;

  signal hold_or_simulated_hold  : std_logic;
  signal hold_pulse              : std_logic;

  signal last_adcspi_write       : std_logic_vector(NUMBER_OF_ADC-1 downto 0);
  signal last_adcspi_read        : std_logic_vector(NUMBER_OF_ADC-1 downto 0);
  signal adcspi_addr             : std_logic_vector((NUMBER_OF_ADC-1)*8+7 downto 0);
  signal adcspi_data             : std_logic_vector((NUMBER_OF_ADC-1)*32+31 downto 0);
  signal last_adcspi_data             : std_logic_vector((NUMBER_OF_ADC-1)*32+31 downto 0);
  signal adcspi_read             : std_logic_vector(NUMBER_OF_ADC-1 downto 0);
  signal adcspi_write            : std_logic_vector(NUMBER_OF_ADC-1 downto 0);

  signal serpar_fifo_empty       : std_logic_vector(NUMBER_OF_ADC-1 downto 0);
  signal serpar_fifo_full        : std_logic_vector(NUMBER_OF_ADC-1 downto 0);

  signal adc_clk_out_v          : std_logic_vector(NUMBER_OF_ADC downto 1);

  signal adc_valid_synch          : std_logic_vector(NUMBER_OF_ADC-1 downto 0);

-- HOLD handling signals:

signal lvl1_state, next_lvl1_state : lvl1_state_type;
signal LVL1_DELAY_COUNTER   : unsigned (7 downto 0);
signal HOLD_LENGTH_COUNTER  : unsigned (3 downto 0);
signal ADJUSTED_HOLD        : std_logic;

-- gk 02.11.10
signal debug_reg_addr       : std_logic_vector(15 downto 0);
signal debug_reg_data_out   : std_logic_vector(31 downto 0);
signal debug_reg_wr_en      : std_logic;
signal debug_reg_rd_en      : std_logic;
signal debug_reg_data_in    : std_logic_vector(31 downto 0);
signal debug_reg_ack        : std_logic;
signal lvl1_state_num       : std_logic_vector(2 downto 0);
signal adc_wr_state         : std_logic_vector(31 downto 0);
signal feb_engine_state     : std_logic_vector(7 downto 0);

-- gk 21.12.10
signal trigger_pos          : std_logic_vector(9 downto 0);
signal trigger_pos_q        : std_logic_vector(9 downto 0);
signal max_samples          : std_logic_vector(9 downto 0);
signal max_samples_q        : std_logic_vector(9 downto 0);
signal osc_mode             : std_logic;
signal osc_mode_q           : std_logic;
signal sum_samples          : std_logic_vector(31 downto 0);
signal sum_samples_q        : std_logic_vector(31 downto 0);

signal desync_vec           : std_logic_vector(5 downto 0);
signal threshold  : std_logic_vector(11 downto 0);
signal position : std_logic_vector(3 downto 0);

begin


SYNC_PROC : process(clk_100)
begin
  if rising_edge(clk_100) then
    max_samples_q <= max_samples;
    trigger_pos_q <= trigger_pos;
    osc_mode_q    <= osc_mode;
    sum_samples_q <= sum_samples;
  end if;
end process SYNC_PROC;

 ---------------------------------------------------------------------------
-- Clock & Reset state machine
---------------------------------------------------------------------------
  clk_en                 <= '1';
  reset_i_q              <= not pll_10_locked or not pll_locked ;
  make_reset_via_network <= MED_STAT_OP(0*16 + 13);

  THE_PLL : pll_in100_out100
    port map(
      CLK      => CLK_100_IN,
      CLKOP    => clk_100,
      LOCK     => pll_locked
      );

-- gk 21.12.10
--   THE_PLL_20: pll_in100_out20
--     port map (
--       CLK      => CLK_100_IN,
--       CLKOP    => clk_20,
--       LOCK     => pll_20_locked
--       );

--   THE_PLL_10 : pll_in100_out10
--     port map (
--       CLK      => CLK_100_IN,
--       CLKOP    => clk_10,
--       LOCK     => pll_10_locked
--       );
--!!!!!!!!!!!!!!!! changed back to clock 20MHz without changing signal names
  THE_PLL_20: pll_in100_out20
    port map (
      CLK      => CLK_100_IN,
      CLKOP    => clk_10,
      LOCK     => pll_10_locked
      );


THE_RESET_COUNTER_PROC: process( RESET_IN, pll_10_locked, pll_locked, CLK_100_IN )
begin
  if( (pll_10_locked = '0') or (pll_locked = '0') or (RESET_IN = '0') ) then
    reset_counter <= (others => '0');
    reset_i       <= '1';
  elsif( rising_edge(CLK_100_IN) ) then
    if   ( make_reset_via_network = '1') then
      reset_counter <= (others => '0');
      reset_i       <= '1';
    elsif( reset_counter = x"3EEEE" ) then
      reset_counter <= x"3EEEE";
      reset_i       <= '0';
    else
      reset_counter <= reset_counter + to_unsigned(1,1);
      reset_i       <= '1';
    end if;
  end if;
end process THE_RESET_COUNTER_PROC;



---------------------------------------------------------------------------
-- ADC Readout
---------------------------------------------------------------------------

--Clock for ADC
 GENERATE_LVDS_CLOCK_FOR_ADC: for i in 1 to NUMBER_OF_ADC generate
  THE_ADC_CLK_OUT: oddrxc
    port map (
        DA => '1',
        DB => '0',
        clk => clk_10,
        rst =>  '0', --reset_i,
        Q => adc_clk_out_v(i)
        );
    ADCCLK_OUT(i) <= adc_clk_out_v(i);
end generate;

-- GENERATE_RELEASE: for i in 1 to NUMBER_OF_ADC generate
--   THE_ADC_CLK_OUT:ddr_generic
--       port map (
--           CLK => clk_20,
--           Data => "10",
--           Q(0) => adc_clk_out_v(i)(0)
--       );
-- ADCCLK_OUT(i) <= adc_clk_out_v(i)(0);
-- end generate;

--Reset
  adc_reset <= reset_i;
--reorganize ADC inputs to one vector
  adc_data_inputs <= P2_IN(16 downto 9) &  P1_IN(16 downto 9) & PRE_IN(16 downto 9) &
                     P2_IN(8 downto 1) &  P1_IN(8 downto 1) & PRE_IN(8 downto 1);

  gen_read_ADC : for i in 0 to NUMBER_OF_ADC-1  generate
    THE_ADC_READ: read_ADC
      generic map(
        IOFF_DELAY               => "0000",
	ADC_ID                   => i
        )
      port map(
        RESET                    => adc_reset,
        CLOCK                    => clk_100,
        --Pedestal / connection to bus handler
        PED_DATA_IN              => ped_data_in(i*16+9 downto i*16),
        PED_DATA_OUT             => ped_data_out(i*16+9 downto i*16),
        TRB_PED_ADDR_IN          => ped_address_in,
        PED_READ_IN              => ped_read_en(i),
        PED_WRITE_IN             => ped_write_en(i),
        PED_READ_ACK_OUT         => ped_read_ack(i),
        PED_WRITE_ACK_OUT        => ped_write_ack(i),
        PED_BUSY_OUT             => ped_busy(i),
        PED_UNKNOWN_OUT          => ped_unknown(i),

        IOFF_DELAY_IN            => "0000",
        LOCAL_ID_IN              => std_logic_vector(to_unsigned(i,4)),
        SAMPLING_PATTERN_IN      => regio_ctrl_registers (7 downto 4),
        THRESHOLD_IN             => regio_ctrl_registers (3 downto 0),
        --ADC inputs
        ADC_DATA_CLOCK_IN        => DCO_IN(i+1),
        ADC_FRAME_CLOCK_IN       => FCO_IN(i+1),
        ADC_SERIAL_IN            => adc_data_inputs(i*8+7 downto i*8),
        --Control signals from FEB
        FEB_MUX_NEW_CHAN_RDY_IN  => feb_mux_new_chan_rdy,
        ADC_VALID_SYNCH_OUT      => adc_valid_synch(i),

        --  data interface to endpint handler
        FEE_TRG_TYPE_IN          => trg_type,
        FEE_TRG_RELEASE_OUT      => fee_trg_release(i),
        FEE_TRG_DATA_VALID_IN    => trg_data_valid,
        FEE_VALID_TIMING_TRG_IN  => trg_valid_timing,
        FEE_VALID_NOTIMING_TRG_IN=> trg_valid_notiming,
        FEE_DATA_OUT             => fee_data_local(32*i+31 downto 32*i) ,
        FEE_DATA_WRITE_OUT       => fee_data_write(i),
        FEE_DATA_FINISHED_OUT    => fee_data_finished(i),
         --Data Output to ipu_han
        IPU_DAT_DATA_OUT      => open,
        IPU_DAT_DATA_READ_IN  => '0',
        IPU_DAT_DATA_EMPTY_OUT => open,
        IPU_HDR_DATA_OUT      => open,
        IPU_HDR_DATA_READ_IN  => '0',
        IPU_HDR_DATA_EMPTY_OUT => open,
        -- outputs to trb Slow Control REGIO_STAT_REG
        SERPAR_INPUT_FIFO_EMPTY => serpar_fifo_empty(i),
        SERPAR_INPUT_FIFO_FULL  => serpar_fifo_full(i),
        --Debug

        WRITE_STATE_OUT        => open, --adc_wr_state(4*i + 3 downto 4*i), -- gk 02.11.10
	DESYNC_OUT             => desync_vec(i),

        TRIGGER_POS_IN         => trigger_pos_q,  -- gk 21.12.10
        MAX_SAMPLES_IN         => max_samples_q,  -- gk 21.12.10
        OSC_MODE_IN            => osc_mode_q,  -- gk 10.01.11
        SUM_SAMPLES_IN         => sum_samples_q,
	THRESHOLD_CF_IN           => threshold,
	POSITION_IN	=> position,

        ENABLE_DEBUG_IN         => regio_common_ctrl_reg(94),-- CCR2(30): 1 - word counter added, 0 - word counter ignored (enables 11-bit word counter + "bad" control word to be added at the end of data from each ADC chip)
        ADC_INSPECT_BUS          => debug_adc(i*36+35 downto i*36)
        );
--fee_data(32*i+31 downto 32*i) <= fee_data_local(32*i+31) & '0' & std_logic_vector(to_unsigned(i mod 3,2)) & trg_int_trg_number(2 downto 0) &  FPGA_NUMBER & std_logic_vector(to_unsigned(i/3,1)) & fee_data_local(32*i+22 downto 32*i);
fee_data(32*i+31 downto 32*i) <= fee_data_local(32*i+31 downto 32*i);
 end generate;

---------------------------------------------------------------------------
-- FEB Control
---------------------------------------------------------------------------
-- gk 21.12.10
--   THE_FEB_ENGINE: FEB_engine
--     port map(
--       RESET                      => adc_reset,
--       CLOCK                      => clk_100,
--       -- to LVL1_handler
--       REAL_HOLD_IN               => hold_or_simulated_hold,
-- 
--       LVL1_VALID_NOTIMING_TRG_IN => trg_valid_notiming,
--       LVL1_INVALID_TRG_IN        => trg_invalid,
--       LVL1_TRG_DATA_VALID_IN     => trg_data_valid,
--       LVL1_TRG_TYPE_IN           => trg_type,
--       LVL1_TRG_INFORMATION_IN    => trg_information,
-- 
--       FEE_TRG_RELEASE_OUT        => event_taken,
--       FEB_64TH_PEDESTAL_IN       => feb_64th_pedestal_sum,
--       FEB_MUX_NEW_CHAN_RDY_OUT   => feb_mux_new_chan_rdy,
--       ADC_VALID_SYNCH_IN         => adc_valid_synch(0), -- take first ADC for synchronization, others should be in synch
-- 
--        --FEB
--       INT_HOLD_OUT               => internal_hold_i,
--       FEB_CLOCK_OUT              => FEB_CLK_OUT,
--       FEB_RESET_OUT              => FEB_RESET_OUT,
--       FEB_RBITIN_OUT             => FEB_RBITIN_OUT,
--       FEB_ENABLE_OUT             => FEB_ENABLE_OUT,
--       FEB_EVEN_OUT               => FEB_EVEN_OUT,
--       FEB_ODD_OUT                => FEB_ODD_OUT,
-- 
--       ENGINE_STATE_OUT           => feb_engine_state,
--       PED_PAUSE_IN               => ped_pause,  -- gk 10.11.10
--       PED_NUM_OF_SAMPLES_IN      => ped_num_of_samples, -- gk 10.11.10
--       --Debug
--       DEBUG_OUT                  => debug_feb_engine
--       );

--   gen_ADC_SPI : for i in 0 to NUMBER_OF_ADC-1  generate
--     SPI_ADC: program_ADC
--       port map(
--         RESET           => adc_reset,
--         CLOCK           => clk_100,
--         START_IN        => adcspi_read(i),
--         ADC_READY_OUT   => open, --last_adcspi_write(i),
--         CSB_OUT         => ADC_CSB_OUT(i+1),
--         SDIO_INOUT      => ADC_SDIO_INOUT(i+1),
--         SCLK_OUT        => ADC_SCLK_OUT(i+1),
--         ADC_SELECT_IN   => adcspi_write(i),
--         MEMORY_ADDRESS_IN => adcspi_addr(i*8+7 downto i*8),
--         DATA_IN          => adcspi_data(i*32+31 downto i*32),
--         DATA_OUT         => open
--       );
--   end generate;

gen_ADC_SPI : for i in 0 to NUMBER_OF_ADC-1  generate
SPI_ADC: shower_spi_adc_master
port map (
  RESET_IN        => adc_reset,
  CLK_IN          => clk_100,

  -- Slave bus
  SLV_READ_IN     => '0',
  SLV_WRITE_IN    => last_adcspi_write(i),
  SLV_BUSY_OUT    => open,
  SLV_ACK_OUT     => open,
  SLV_DATA_IN     => last_adcspi_data(i*32+31 downto i*32),
  SLV_DATA_OUT    => open,

  -- SPI connections
  SPI_CS_OUT      => ADC_CSB_OUT(i+1),
  SPI_SDO_OUT     => ADC_SDIO_INOUT(i+1),
  SPI_SCK_OUT     => ADC_SCLK_OUT(i+1),

  -- ADC connections
  ADC_LOCKED_IN   => '0',
  ADC_PD_OUT      => open,
  ADC_RST_OUT     => open,
  ADC_DEL_OUT     => open,
  -- Status lines
  STAT            => open -- DEBUG
);
end generate;

WRITE_REGIO_COMMON_CTRL_REG:process(reset_i, clk_100, common_ctrl_reg_strobe) begin
if rising_edge(clk_100) then
  if(reset_i = '1') then
    regio_common_ctrl_reg <= (others => '0');
  else
     for i in 0 to std_COMCTRLREG-1  loop
       if common_ctrl_reg_strobe(i) = '1' then
         regio_common_ctrl_reg((i+1)*32-1 downto 0) <= regio_common_ctrl((i+1)*32-1 downto 0);
       end if;
     end loop;
  end if;
end if;
end process WRITE_REGIO_COMMON_CTRL_REG;

WRITE_TRIGGER_NUMBERS:process(reset_i, clk_100, trg_data_valid) begin
if rising_edge(clk_100) then
  if(reset_i = '1') then
    trg_number_reg <= (others => '0');
  elsif trg_data_valid = '1' then
      trg_number_reg <= trg_int_trg_number & trg_number;
    end if;
end if;
end process WRITE_TRIGGER_NUMBERS;

---------------------------------------------------------------------
-- Generate internal hold signal
---------------------------------------------------------------------
  hold_in_local <= HOLD_IN and regio_common_ctrl_reg(95); -- CCR2(31): 1 - triggers accepted, 0 - triggers ignored

  -- gk 14.12.10 hold_in_local used as intout signal for lvl_handler
--   HOLD_PULSE_GENERATOR: edge_to_pulse
--     port map (
--       clock => clk_100,
--       en_clk => '1',
--       signal_in => hold_in_local,
--       pulse => hold_pulse
--       );

  FEB_HOLD_OUT <= ADJUSTED_HOLD  or internal_hold_i;

  hold_or_simulated_hold <= regio_common_ctrl_reg(16) or ADJUSTED_HOLD;    -- CCR0(16)

DELAY_LVL1:process(reset_i, clk_100, lvl1_state) begin
if rising_edge(clk_100) then
  if(reset_i = '1') then
    LVL1_DELAY_COUNTER <= (others => '0');
  elsif lvl1_state = REALISE_DELAY then
    LVL1_DELAY_COUNTER <= LVL1_DELAY_COUNTER + 1;
    else
    LVL1_DELAY_COUNTER <= (others => '0');
    end if;
end if;
end process DELAY_LVL1;

ADJUST_HOLD:process(reset_i, clk_100, lvl1_state) begin
if rising_edge(clk_100) then
  if(reset_i = '1') then
    HOLD_LENGTH_COUNTER <= (others => '0');
    ADJUSTED_HOLD <= '0';
  elsif lvl1_state = GENERATE_HOLD then
    HOLD_LENGTH_COUNTER <= HOLD_LENGTH_COUNTER + 1;
    ADJUSTED_HOLD <= '1';
    else
    HOLD_LENGTH_COUNTER <= (others => '0');
    ADJUSTED_HOLD <= '0';
    end if;
end if;
end process ADJUST_HOLD;

NEXT_STATE_GEN: process(reset_i, clk_100) begin
if rising_edge(clk_100) then
  if(reset_i = '1') then
    lvl1_state <= IDLE;
  else
    lvl1_state <= next_lvl1_state;
  end if;
end if;
end process NEXT_STATE_GEN;

-- gk 01.11.2010
MAKE_HOLD_SIGNAL: process (reset_i, trg_valid_timing, regio_ctrl_registers(15 downto 8))begin
  if(reset_i = '1') then
    next_lvl1_state <= idle;
  else
    case lvl1_state is

       when IDLE =>
--         lvl1_state_num <= "001";
        if trg_valid_timing  = '1' then
          next_lvl1_state <= REALISE_DELAY;
        else
          next_lvl1_state <= idle;
        end if;

      when REALISE_DELAY =>
--         lvl1_state_num <= "010";
        if LVL1_DELAY_COUNTER(7 downto 0) = unsigned (regio_ctrl_registers(15 downto 8)) then
          next_lvl1_state <= GENERATE_HOLD;
        else
          next_lvl1_state <= REALISE_DELAY;
        end if;

      when GENERATE_HOLD =>
--         lvl1_state_num <= "011";
        if HOLD_LENGTH_COUNTER(3 downto 0) = "1100" then  -- unsigned (regio_ctrl_registers(19 downto 16)) then
          next_lvl1_state <= IDLE;
        else
          next_lvl1_state <= GENERATE_HOLD;
        end if;

      when others =>
        next_lvl1_state <= IDLE;

    end case;
  end if;
end process MAKE_HOLD_SIGNAL;

  --feb_64th_pedestal_sum <= feb_64th_pedestal(0) or feb_64th_pedestal(1) or feb_64th_pedestal(2) or
  --                          feb_64th_pedestal(3) or feb_64th_pedestal(4) or feb_64th_pedestal(5);


---------------------------------------------------------------------------
-- Media Interface
---------------------------------------------------------------------------

  THE_MEDIA_INTERFACE_0 : trb_net16_med_ecp_sfp_gbe
    generic map(
      SERDES_NUM => 0,
      EXT_CLOCK  => c_NO
      )
    port map(
      CLK                      => clk_100_in,
      SYSCLK                   => clk_100,
      RESET                    => reset_i,
      CLEAR                    => reset_i_q,
      CLK_EN                   => clk_en,
      --Internal Connection
      MED_DATA_IN              => med_data_out,
      MED_PACKET_NUM_IN        => med_packet_num_out,
      MED_DATAREADY_IN         => med_dataready_out,
      MED_READ_OUT             => med_read_in,
      MED_DATA_OUT             => med_data_in,
      MED_PACKET_NUM_OUT       => med_packet_num_in,
      MED_DATAREADY_OUT        => med_dataready_in,
      MED_READ_IN              => med_read_out,
      REFCLK2CORE_OUT          => open,
      --SFP Connection
      SD_RXD_P_IN              => F3_RXP,
      SD_RXD_N_IN              => F3_RXN,
      SD_TXD_P_OUT             => F3_TXP,
      SD_TXD_N_OUT             => F3_TXN,
      SD_REFCLK_P_IN           => open,
      SD_REFCLK_N_IN           => open,
      SD_PRSNT_N_IN            => '0',
      SD_LOS_IN                => '0',
      -- Status and control port
      STAT_OP                  => med_stat_op,
      CTRL_OP                  => med_ctrl_op,
      STAT_DEBUG               => med_stat_debug,
      CTRL_DEBUG               => (others => '0')
    );


---------------------------------------------------------------------------
-- TrbNet Endpoint
---------------------------------------------------------------------------

  THE_ENDPOINT: trb_net16_endpoint_hades_full_handler
    generic map(
      REGIO_NUM_STAT_REGS        => NUM_STAT_REGS,
      REGIO_NUM_CTRL_REGS        => NUM_CTRL_REGS,
      ADDRESS_MASK               => x"FFFF",
      BROADCAST_BITMASK          => x"F7",
      REGIO_INIT_ADDRESS         => REGIO_INIT_ADDRESS,
      REGIO_COMPILE_TIME         => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
      REGIO_INIT_ENDPOINT_ID     => REGIO_ENDPOINT_ID,
      REGIO_COMPILE_VERSION      => x"0000",
      REGIO_HARDWARE_VERSION     => x"42100000",
      REGIO_USE_1WIRE_INTERFACE  => c_MONITOR,
      CLOCK_FREQUENCY            => 100,
      DATA_INTERFACE_NUMBER      => NUMBER_OF_ADC,
      DATA_BUFFER_DEPTH          => 11,  --reduced for faster compilation
      DATA_BUFFER_WIDTH          => 32,
      DATA_BUFFER_FULL_THRESH    => 2**11-520,
      TRG_RELEASE_AFTER_DATA     => c_YES,
      HEADER_BUFFER_DEPTH        => 9,
      HEADER_BUFFER_FULL_THRESH  => 2**9-10
      )
    port map(
     CLK                        => clk_100,
      RESET                      => reset_i,
      CLK_EN                     => clk_en,

      MED_DATAREADY_OUT          => med_dataready_out,
      MED_DATA_OUT               => med_data_out,
      MED_PACKET_NUM_OUT         => med_packet_num_out,
      MED_READ_IN                => med_read_in,
      MED_DATAREADY_IN           => med_dataready_in,
      MED_DATA_IN                => med_data_in,
      MED_PACKET_NUM_IN          => med_packet_num_in,
      MED_READ_OUT               => med_read_out,
      MED_STAT_OP_IN             => med_stat_op,
      MED_CTRL_OP_OUT            => med_ctrl_op,

      -- LVL1 trigger APL
      TRG_TIMING_TRG_RECEIVED_IN => hold_in_local, --hold_pulse, -- gk 02.11.10
      LVL1_TRG_DATA_VALID_OUT    => trg_data_valid,
      LVL1_VALID_TIMING_TRG_OUT  => trg_valid_timing,
      LVL1_VALID_NOTIMING_TRG_OUT=> trg_valid_notiming,
      LVL1_INVALID_TRG_OUT       => trg_invalid,
      LVL1_TRG_TYPE_OUT          => trg_type,
      LVL1_TRG_NUMBER_OUT        => trg_number,
      LVL1_TRG_CODE_OUT          => trg_code,
      LVL1_TRG_INFORMATION_OUT   => trg_information,
      LVL1_INT_TRG_NUMBER_OUT    => trg_int_trg_number,

    --Information about trigger handler errors
--       TRG_MULTIPLE_TRG_OUT       => trg_multiple_trg_out,
--       TRG_TIMEOUT_DETECTED_OUT   => trg_timeout_detected_out,
--       TRG_SPURIOUS_TRG_OUT       => trg_spurious_trg_out,
--       TRG_MISSING_TMG_TRG_OUT    => trg_missing_tmg_trg_out,
--       TRG_SPIKE_DETECTED_OUT     => trg_spike_detected_out,

      -- FEE Port
      FEE_TRG_RELEASE_IN         => fee_trg_release,
      FEE_TRG_STATUSBITS_IN      => fee_trg_statusbits,
      FEE_DATA_IN                => fee_data,
      FEE_DATA_WRITE_IN          => fee_data_write,
      FEE_DATA_FINISHED_IN       => fee_data_finished,
      FEE_DATA_ALMOST_FULL_OUT   => fee_data_almost_full,


      -- Slow Control Data Port
      REGIO_COMMON_STAT_REG_IN   => regio_common_stat_reg, --0x00  (others => '0'),
      REGIO_COMMON_CTRL_REG_OUT  => regio_common_ctrl, --0x20
      REGIO_COMMON_CTRL_STROBE_OUT => common_ctrl_reg_strobe,
      REGIO_COMMON_STAT_STROBE_OUT => common_stat_reg_strobe,

      REGIO_STAT_REG_IN          => regio_stat_registers,  --start 0x80
      REGIO_CTRL_REG_OUT         => regio_ctrl_registers_in,  --start 0xc0
      REGIO_STAT_STROBE_OUT      => stat_reg_strobe,
      REGIO_CTRL_STROBE_OUT      => ctrl_reg_strobe,

      --following ports only used when using internal data port
      BUS_ADDR_OUT               => regio_addr_out,
      BUS_DATA_OUT               => regio_data_out,
      BUS_READ_ENABLE_OUT        => regio_read_enable_out,
      BUS_WRITE_ENABLE_OUT       => regio_write_enable_out,

      BUS_TIMEOUT_OUT            => regio_timeout_out,
      BUS_DATA_IN                => regio_data_in,
      BUS_DATAREADY_IN           => regio_dataready_in,

      BUS_WRITE_ACK_IN           => regio_write_ack_in,
      BUS_NO_MORE_DATA_IN        => regio_no_more_data_in,
      BUS_UNKNOWN_ADDR_IN        => regio_unknown_addr_in,

      ONEWIRE_INOUT              => open,
      ONEWIRE_MONITOR_IN         => onewire_monitor_in,
      ONEWIRE_MONITOR_OUT        => onewire_monitor_out,
      REGIO_VAR_ENDPOINT_ID      => regio_var_endpoint_id,

      TIME_GLOBAL_OUT            => global_time,
      TIME_LOCAL_OUT             => local_time,
      TIME_SINCE_LAST_TRG_OUT    => time_since_last_trg,
      TIME_TICKS_OUT             => timer_ticks,

      STAT_DEBUG_IPU              => stat_debug_ipu,
      STAT_DEBUG_1                => stat_debug_1,
      STAT_DEBUG_2                => stat_debug_2,
      STAT_DEBUG_DATA_HANDLER_OUT => stat_debug_data_handler_out,
      STAT_DEBUG_IPU_HANDLER_OUT  => stat_debug_ipu_handler_out,
      CTRL_MPLEX                  => ctrl_mplex,
      IOBUF_CTRL_GEN              => iobuf_ctrl_gen,
      STAT_ONEWIRE                => stat_onewire,
      STAT_ADDR_DEBUG             => stat_addr_debug,
      DEBUG_LVL1_HANDLER_OUT      => debug_lvl1_handler_out
);



---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
--  D000         spi status register
--  D001         spi ctrl register
--  D100 - D13F  spi memory
--  A000 - AFFF  pedestal / threshold memory
--                      10-8 nr ADC,
--                      7    pedestal / threshold
--                      6-4  ADC channel number,
--                      3-0  detector pad number
--  C000 - C5FF  adc spi memory
--  E000         Spy Fifo 1
--  F000         Spy Fifo 2

  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 3, -- 9, --15, --17,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100",
			  2 => x"8300",
			--2 => x"c000", 3 => x"c100", 4 => x"c200", 5 => x"c300", 6 => x"c400", 7 => x"c500",
                         --2 => x"A000", 3 => x"A100", 4 => x"A200", 5 => x"A300", 6 => x"A400", 7 => x"A500",
                         --8 => x"8300",-- 8 => x"E000",
			--9 => x"c000", 10 => x"c100", 11 => x"c200",  12 => x"c300",13 => x"c400", 14 => x"c500",
			--15 => x"F000", 16 => x"8300",
			--15 => x"8300",
                        others => x"0000"),
      PORT_ADDR_MASK => (0 => 1,       1 => 6,
                         2 => 8,       --3 => 8,       4 => 8,       5 => 8,       6 => 8,       7 => 8,
                         --8 => 8, --8 => 0,
			  --9 => 8,    10 => 8,    11 => 8,   12 => 8,   13 => 8,   14 => 8,
			 --15 => 0, 16 => 8,
			 --15=> 8,
                          others => 0)
      )
    port map(
      CLK                   => clk_100,
      RESET                 => reset_i,

      DAT_ADDR_IN           => regio_addr_out,
      DAT_DATA_IN           => regio_data_out,
      DAT_DATA_OUT          => regio_data_in,
      DAT_READ_ENABLE_IN    => regio_read_enable_out,
      DAT_WRITE_ENABLE_IN   => regio_write_enable_out,
      DAT_TIMEOUT_IN        => regio_timeout_out,
      DAT_DATAREADY_OUT     => regio_dataready_in,
      DAT_WRITE_ACK_OUT     => regio_write_ack_in,
      DAT_NO_MORE_DATA_OUT  => regio_no_more_data_in,
      DAT_UNKNOWN_ADDR_OUT  => regio_unknown_addr_in,

    --Bus Handler (SPI CTRL)
      BUS_READ_ENABLE_OUT(0)               => spictrl_read_en,
      BUS_WRITE_ENABLE_OUT(0)              => spictrl_write_en,
      BUS_DATA_OUT(0*32+31 downto 0*32)    => spictrl_data_in,
      BUS_ADDR_OUT(0*16)                   => spictrl_addr,
      BUS_ADDR_OUT(0*16+15 downto 0*16+1)  => open,
      BUS_TIMEOUT_OUT(0)                   => open,
      BUS_DATA_IN(0*32+31 downto 0*32)     => spictrl_data_out,
      BUS_DATAREADY_IN(0)                  => spictrl_ack,
      BUS_WRITE_ACK_IN(0)                  => spictrl_ack,
      BUS_NO_MORE_DATA_IN(0)               => spictrl_busy,
      BUS_UNKNOWN_ADDR_IN(0)               => '0',
    --Bus Handler (SPI Memory)
      BUS_READ_ENABLE_OUT(1)               => spimem_read_en,
      BUS_WRITE_ENABLE_OUT(1)              => spimem_write_en,
      BUS_DATA_OUT(1*32+31 downto 1*32)    => spimem_data_in,
      BUS_ADDR_OUT(1*16+5 downto 1*16)     => spimem_addr,
      BUS_ADDR_OUT(1*16+15 downto 1*16+6)  => open,
      BUS_TIMEOUT_OUT(1)                   => open,
      BUS_DATA_IN(1*32+31 downto 1*32)     => spimem_data_out,
      BUS_DATAREADY_IN(1)                  => spimem_ack,
      BUS_WRITE_ACK_IN(1)                  => spimem_ack,
      BUS_NO_MORE_DATA_IN(1)               => '0',
      BUS_UNKNOWN_ADDR_IN(1)               => '0',
    -- pedestal memories
--       BUS_ADDR_OUT(2*16+8 downto 2*16)     => ped_address_in,
--       BUS_ADDR_OUT(7*16+15 downto 2*16+9)  => open,
--       BUS_DATA_OUT(2*32+15 downto 2*32)    => ped_data_in(15 downto 0),
--       BUS_DATA_OUT(3*32+15 downto 3*32)    => ped_data_in(31 downto 16),
--       BUS_DATA_OUT(4*32+15 downto 4*32)    => ped_data_in(47 downto 32),
--       BUS_DATA_OUT(5*32+15 downto 5*32)    => ped_data_in(63 downto 48),
--       BUS_DATA_OUT(6*32+15 downto 6*32)    => ped_data_in(79 downto 64),
--       BUS_DATA_OUT(7*32+15 downto 7*32)    => ped_data_in(95 downto 80),
--       BUS_DATA_OUT(2*32+31 downto 2*32+16) => open,
--       BUS_DATA_OUT(3*32+31 downto 3*32+16) => open,
--       BUS_DATA_OUT(4*32+31 downto 4*32+16) => open,
--       BUS_DATA_OUT(5*32+31 downto 5*32+16) => open,
--       BUS_DATA_OUT(6*32+31 downto 6*32+16) => open,
--       BUS_DATA_OUT(7*32+31 downto 7*32+16) => open,
--       BUS_READ_ENABLE_OUT(7 downto 2)      => ped_read_en,
--       BUS_WRITE_ENABLE_OUT(7 downto 2)     => ped_write_en,
--       BUS_TIMEOUT_OUT(7 downto 2)          => open,
--       BUS_DATA_IN(2*32+15 downto 2*32)     => ped_data_out(15 downto 0),
--       BUS_DATA_IN(3*32+15 downto 3*32)     => ped_data_out(31 downto 16),
--       BUS_DATA_IN(4*32+15 downto 4*32)     => ped_data_out(47 downto 32),
--       BUS_DATA_IN(5*32+15 downto 5*32)     => ped_data_out(63 downto 48),
--       BUS_DATA_IN(6*32+15 downto 6*32)     => ped_data_out(79 downto 64),
--       BUS_DATA_IN(7*32+15 downto 7*32)     => ped_data_out(95 downto 80),
--       BUS_DATA_IN(2*32+31 downto 2*32+16)  => (others => '0'),
--       BUS_DATA_IN(3*32+31 downto 3*32+16)  => (others => '0'),
--       BUS_DATA_IN(4*32+31 downto 4*32+16)  => (others => '0'),
--       BUS_DATA_IN(5*32+31 downto 5*32+16)  => (others => '0'),
--       BUS_DATA_IN(6*32+31 downto 6*32+16)  => (others => '0'),
--       BUS_DATA_IN(7*32+31 downto 7*32+16)  => (others => '0'),
--       BUS_DATAREADY_IN(7 downto 2)         => ped_read_ack,
--       BUS_WRITE_ACK_IN(7 downto 2)         => ped_write_ack,
--       BUS_NO_MORE_DATA_IN(7 downto 2)      => ped_busy,
--       BUS_UNKNOWN_ADDR_IN(7 downto 2)      => ped_unknown,
    --Spy1 Fifo
--       BUS_ADDR_OUT(8*16+15 downto 8*16)    => open,
--       BUS_DATA_OUT(8*32+31 downto 8*32)    => open,
--       BUS_READ_ENABLE_OUT(8)               => spy1fifo_read,
--       BUS_WRITE_ENABLE_OUT(8)              => open,
--       BUS_TIMEOUT_OUT(8)                   => open,
--       BUS_DATA_IN(8*32+31 downto 8*32)     => spy1fifo_data_out,
--       BUS_DATAREADY_IN(8)                  => spy1fifo_dataready,
--       BUS_WRITE_ACK_IN(8)                  => '0',
--       BUS_NO_MORE_DATA_IN(8)               => spy1fifo_empty,
--       BUS_UNKNOWN_ADDR_IN(8)               => '0',
    --Spy2 Fifo
--       BUS_ADDR_OUT(15*16+15 downto 15*16)    => open,
--       BUS_DATA_OUT(15*32+31 downto 15*32)    => open,
--       BUS_READ_ENABLE_OUT(15)               => spy2fifo_read,
--       BUS_WRITE_ENABLE_OUT(15)              => open,
--       BUS_TIMEOUT_OUT(15)                   => open,
--       BUS_DATA_IN(15*32+31 downto 15*32)     => spy2fifo_data_out,
--       BUS_DATAREADY_IN(15)                  => spy2fifo_dataready,
--       BUS_WRITE_ACK_IN(15)                  => '0',
--       BUS_NO_MORE_DATA_IN(15)               => spy2fifo_empty,
--       BUS_UNKNOWN_ADDR_IN(15)               => '0',
    --SPI for ADC
--       BUS_ADDR_OUT(2*16+7 downto 2*16)      => adcspi_addr(7 downto 0),
--       BUS_ADDR_OUT(3*16+7 downto 3*16)    => adcspi_addr(1*8+7 downto 1*8),
--       BUS_ADDR_OUT(4*16+7 downto 4*16)    => adcspi_addr(2*8+7 downto 2*8),
--       BUS_ADDR_OUT(5*16+7 downto 5*16)    => adcspi_addr(3*8+7 downto 3*8),
--       BUS_ADDR_OUT(6*16+7 downto 6*16)    => adcspi_addr(4*8+7 downto 4*8),
--       BUS_ADDR_OUT(7*16+7 downto 7*16)    => adcspi_addr(5*8+7 downto 5*8),
--       BUS_ADDR_OUT(2*16+15 downto 2*16+8)       => open,
--       BUS_ADDR_OUT(3*16+15 downto 3*16+8)    => open,
--       BUS_ADDR_OUT(4*16+15 downto 4*16+8)    => open,
--       BUS_ADDR_OUT(5*16+15 downto 5*16+8)    => open,
--       BUS_ADDR_OUT(6*16+15 downto 6*16+8)    => open,
--       BUS_ADDR_OUT(7*16+15 downto 7*16+8)    => open,
--       BUS_DATA_OUT(2*32+31 downto 2*32)      => adcspi_data(31 downto 0),
--       BUS_DATA_OUT(3*32+31 downto 3*32)    => adcspi_data(1*32+31 downto 1*32),
--       BUS_DATA_OUT(4*32+31 downto 4*32)    => adcspi_data(2*32+31 downto 2*32),
--       BUS_DATA_OUT(5*32+31 downto 5*32)    => adcspi_data(3*32+31 downto 3*32),
--       BUS_DATA_OUT(6*32+31 downto 6*32)    => adcspi_data(4*32+31 downto 4*32),
--       BUS_DATA_OUT(7*32+31 downto 7*32)    => adcspi_data(5*32+31 downto 5*32),
--       BUS_READ_ENABLE_OUT(7 downto 2)     => adcspi_read,
--       BUS_WRITE_ENABLE_OUT(7 downto 2)    => adcspi_write,
--       BUS_TIMEOUT_OUT(7 downto 2)           => open,
--       BUS_DATA_IN(2*32+31 downto 2*32)       => (others => '0'),
--       BUS_DATA_IN(3*32+31 downto 3*32)     => (others => '0'),
--       BUS_DATA_IN(4*32+31 downto 4*32)     => (others => '0'),
--       BUS_DATA_IN(5*32+31 downto 5*32)     => (others => '0'),
--       BUS_DATA_IN(6*32+31 downto 6*32)     => (others => '0'),
--       BUS_DATA_IN(7*32+31 downto 7*32)     => (others => '0'),
--       BUS_DATAREADY_IN(7 downto 2)          => (others => '0'),
--       BUS_WRITE_ACK_IN(7 downto 2)          => last_adcspi_write,
--       BUS_NO_MORE_DATA_IN(7 downto 2)       => (others => '0'),
--       BUS_UNKNOWN_ADDR_IN(7 downto 2)       => last_adcspi_read,

-- gk 02.11.10
BUS_ADDR_OUT(2*16+15 downto 2*16) => debug_reg_addr,
BUS_DATA_OUT(2*32+31 downto 2*32) => debug_reg_data_out,
BUS_WRITE_ENABLE_OUT(2)            => debug_reg_wr_en,
BUS_READ_ENABLE_OUT(2)             => debug_reg_rd_en,
BUS_TIMEOUT_OUT(2)                 => open,
BUS_DATA_IN(2*32+31 downto 2*32)  => debug_reg_data_in,
BUS_DATAREADY_IN(2)                => debug_reg_ack,
BUS_WRITE_ACK_IN(2)                => debug_reg_ack,
BUS_NO_MORE_DATA_IN(2)             => '0',
BUS_UNKNOWN_ADDR_IN(2)             => '0',
-- BUS_ADDR_OUT(16*16+15 downto 16*16) => debug_reg_addr,
-- BUS_DATA_OUT(16*32+31 downto 16*32) => debug_reg_data_out,
-- BUS_WRITE_ENABLE_OUT(16)            => debug_reg_wr_en,
-- BUS_READ_ENABLE_OUT(16)             => debug_reg_rd_en,
-- BUS_TIMEOUT_OUT(16)                 => open,
-- BUS_DATA_IN(16*32+31 downto 16*32)  => debug_reg_data_in,
-- BUS_DATAREADY_IN(16)                => debug_reg_ack,
-- BUS_WRITE_ACK_IN(16)                => debug_reg_ack,
-- BUS_NO_MORE_DATA_IN(16)             => '0',
-- BUS_UNKNOWN_ADDR_IN(16)             => '0',

      STAT_DEBUG  => open
      );


  process(clk_100)
    begin
      if rising_edge(clk_100) then
        last_adcspi_write <= adcspi_write;
        last_adcspi_read  <= adcspi_read;
        for i in 0 to NUMBER_OF_ADC-1  loop
          if (adcspi_write(i) = '1') then
              last_adcspi_data(i*32+31 downto i*32) <= adcspi_data(i*32+31 downto i*32);
          end if;
        end loop;
      end if;
    end process;

---------------------------------------------------------------------------
-- Status Registers
---------------------------------------------------------------------------
 fee_trg_statusbits             <= (others => '0');
 regio_stat_registers           <= (others => '0');
 regio_common_stat_reg          <= (others => '0');


--   store_serpar_fifo_full_proc : process(clk_100)
--     begin
--       if rising_edge(clk_100) then
--         spy1fifo_dataready              <= spy1fifo_read;
--         spy2fifo_dataready              <= spy2fifo_read;
--         regio_stat_registers           <= (others => '0');
--         if stat_reg_strobe(0) = '1' or reset_i = '1' then
--           regio_stat_registers(NUMBER_OF_ADC-1+8 downto 0) <= (others => '0');
--         else
--           regio_stat_registers(NUMBER_OF_ADC-1 downto 0) <= serpar_fifo_empty or regio_stat_registers(NUMBER_OF_ADC-1 downto 0);
--           regio_stat_registers(NUMBER_OF_ADC-1+8 downto 8) <= serpar_fifo_full or regio_stat_registers(NUMBER_OF_ADC-1+8 downto 8);
--         end if;
--       end if;
--     end process;

---------------------------------------------------------------------------
-- Control Registers
---------------------------------------------------------------------------

   store_control_reg_proc : process(clk_100)
     begin
       if rising_edge(clk_100) then
         if reset_i = '1' then
           regio_ctrl_registers(32*2**(NUM_CTRL_REGS)-1 downto 0) <= (others => '0');
         else
           for i in 0 to 2**(NUM_CTRL_REGS)-1  loop
             if (ctrl_reg_strobe(i) = '1') then
               regio_ctrl_registers(i*32+31 downto i*32) <= regio_ctrl_registers_in(i*32+31 downto i*32);
             end if;
           end loop;
         end if;
       end if;
     end process store_control_reg_proc;

-- gk 02.11.10
---------------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------------
DEBUG : gbe_setup
port map(
  CLK                       => clk_100,
  RESET                     => reset_i,

  -- interface to regio bus
  BUS_ADDR_IN               => debug_reg_addr(7 downto 0),
  BUS_DATA_IN               => debug_reg_data_out,
  BUS_DATA_OUT              => debug_reg_data_in,
  BUS_WRITE_EN_IN           => debug_reg_wr_en,
  BUS_READ_EN_IN            => debug_reg_rd_en,
  BUS_ACK_OUT               => debug_reg_ack,

--   LVL1_STATE_IN             => lvl1_state_num,
--   ADC_WR_STATE_IN           => adc_wr_state,
--   FEB_ENGINE_STATE_IN       => feb_engine_state,
  DESYNC_IN                 => desync_vec,

  OSC_MODE_OUT              => osc_mode,
  SUM_SAMPLES_OUT           => sum_samples,
  TRIGGER_POS_OUT           => trigger_pos,
  THRESHOLD_OUT		    => threshold,
  POSITION_OUT              => position,
  MAX_SAMPLES_OUT           => max_samples
);



---------------------------------------------------------------------------
-- Spyfifo
---------------------------------------------------------------------------
-- spy1InputVector <= debug_adc(95 downto 88) &  -- x"00" &
--                   debug_adc(80+3 downto 80+0) &
--                   debug_adc(64+3 downto 64+0) &
--                   debug_adc(48+3 downto 48+0) &
--                   debug_adc(32+3 downto 32+0) &
--                   debug_adc(16+3 downto 16+0) &
--                   debug_adc(3 downto 0);

--spy1InputVector <= x"000" & "00" & debug_adc(197 downto 180); -- &  -- x"00" &
--spy1InputVector <=fee_data(31 downto 0);

-- spy1_write_enable: process(clk_100, HOLD_IN, fee_trg_release) begin
-- if rising_edge(clk_100) then
--   if reset_i = '1' then
--     spy1fifo_write <= '0';
--   elsif HOLD_IN = '1' or trg_valid_notiming = '1' then
--       spy1fifo_write <= '1';
--   end if;
--   if fee_trg_release(0) = '1' then
--       spy1fifo_write <= '0';
--   end if;  
-- end if;
-- end process spy1_write_enable;
-- 
-- spy1fifo_read_fifo <= spy1fifo_read or spy1_fifo_almost_full;
-- 
-- spy1InputVector <= HOLD_IN & '0' & feb_mux_new_chan_rdy &
-- --                  debug_adc(180+7 downto 180+0) &
-- --                  debug_adc(144+7 downto 144+0) &
-- --                  debug_adc(108+7 downto 108+0);
--                     trg_data_valid & trg_type & "000" & trg_valid_timing & "000" & trg_valid_notiming & trg_number;
-- 
-- spyFifo1: spyFifo
-- port map(
--     Data                                => spy1InputVector,
--     WrClock                             => clk_100,
--     RdClock                             => clk_100,
--     WrEn                                => spy1fifo_write,
--     RdEn                                => spy1fifo_read_fifo,
--     Reset                               => reset_i,
--     RPReset                             => reset_i,
--     Q                                   => spy1fifo_data_out,
--     Empty                               => spy1fifo_empty,
--     Full                                => open,
--     AlmostEmpty                         => open,
--     AlmostFull                          => spy1_fifo_almost_full);


---------------------------------------------------------------------------
-- Spyfifo
---------------------------------------------------------------------------
-- spy2_write_enable: process(clk_100, HOLD_IN, fee_trg_release) begin
-- if rising_edge(clk_100) then
--   if reset_i = '1' then
--     spy2fifo_write <= '0';
--   elsif HOLD_IN = '1' or trg_valid_notiming = '1' then
--       spy2fifo_write <= '1';
--   end if;
--   if fee_trg_release(0) = '1' then
--       spy2fifo_write <= '0';
--   end if;  
-- end if;
-- end process spy2_write_enable;

-- spy2_write_enable: process(clk_100, HOLD_IN, fee_trg_release) begin
-- if rising_edge(clk_100) then
--   if reset_i = '1' then
--     spy2fifo_write <= '0';
--   else
--       spy2fifo_write <= fee_data_write(0);
--   end if;
-- end if;
-- end process spy2_write_enable;
-- 
-- spy2fifo_read_fifo <= spy2fifo_read or spy2_fifo_almost_full;
-- 
-- --spy2InputVector <= trg_int_trg_number & "00" & fee_trg_release & event_taken & '0' & fee_data_finished;
-- spy2InputVector <= fee_data(31 downto 0); --trg_int_trg_number & "00" & fee_trg_release & event_taken & '0' & fee_data_finished;
-- 
-- spyFifo2: spyFifo
-- port map(
--     Data                                => spy2InputVector,
--     WrClock                             => clk_100,
--     RdClock                             => clk_100,
--     WrEn                                => spy2fifo_write,
--     RdEn                                => spy2fifo_read_fifo,
--     Reset                               => reset_i,
--     RPReset                             => reset_i,
--     Q                                   => spy2fifo_data_out,
--     Empty                               => spy2fifo_empty,
--     Full                                => open,
--     AlmostEmpty                         => open,
--     AlmostFull                          => spy2_fifo_almost_full);

---
------------------------------------------------------------------------
-- SPI / Flash
---------------------------------------------------------------------------

  THE_SPI_MASTER: spi_master
    port map(
      CLK_IN         => clk_100,
      RESET_IN       => reset_i,
      -- Slave bus
      BUS_READ_IN    => spictrl_read_en,
      BUS_WRITE_IN   => spictrl_write_en,
      BUS_BUSY_OUT   => spictrl_busy,
      BUS_ACK_OUT    => spictrl_ack,
      BUS_ADDR_IN(0) => spictrl_addr,
      BUS_DATA_IN    => spictrl_data_in,
      BUS_DATA_OUT   => spictrl_data_out,
      -- SPI connections
      SPI_CS_OUT     => SPI_CS_OUT,
      SPI_SDI_IN     => SPI_SO_IN,
      SPI_SDO_OUT    => SPI_SI_OUT,
      SPI_SCK_OUT    => SPI_CLK_OUT,
      -- BRAM for read/write data
      BRAM_A_OUT     => spi_bram_addr,
      BRAM_WR_D_IN   => spi_bram_wr_d,
      BRAM_RD_D_OUT  => spi_bram_rd_d,
      BRAM_WE_OUT    => spi_bram_we,
      -- Status lines
      STAT           => open
      );

  -- data memory for SPI accesses
  THE_SPI_MEMORY: spi_databus_memory
    port map(
      CLK_IN        => clk_100,
      RESET_IN      => reset_i,
      -- Slave bus
      BUS_ADDR_IN   => spimem_addr,
      BUS_READ_IN   => spimem_read_en,
      BUS_WRITE_IN  => spimem_write_en,
      BUS_ACK_OUT   => spimem_ack,
      BUS_DATA_IN   => spimem_data_in,
      BUS_DATA_OUT  => spimem_data_out,
      -- state machine connections
      BRAM_ADDR_IN  => spi_bram_addr,
      BRAM_WR_D_OUT => spi_bram_wr_d,
      BRAM_RD_D_IN  => spi_bram_rd_d,
      BRAM_WE_IN    => spi_bram_we,
      -- Status lines
      STAT          => open
      );


---------------------------------------------------------------------------
-- Reboot FPGA
---------------------------------------------------------------------------
  PROC_REBOOT : process (clk_100)
    begin
      if reset_i = '1' then
        PROGRAMB_OUT             <= '1';
        delayed_restart_fpga     <= '0';
        restart_fpga_counter     <= x"FFF";
      elsif rising_edge(clk_100) then
        PROGRAMB_OUT             <= not delayed_restart_fpga;
        delayed_restart_fpga     <= '0';
        if regio_common_ctrl_reg(15) = '1' then
          restart_fpga_counter   <= x"000";
        elsif restart_fpga_counter /= x"FFF" then
          restart_fpga_counter   <= restart_fpga_counter + 1;
          if restart_fpga_counter >= x"F00" then
            delayed_restart_fpga <= '1';
          end if;
        end if;
      end if;
    end process;


---------------------------------------------------------------------------
-- Unused Ports
---------------------------------------------------------------------------
  F1_F2(23 downto 0)   <= ( others => 'Z');
  F1_F3(22 downto 0)   <= ( others => 'Z');


---------------------------------------------------------------------------
-- Debug
------------------------------------------------------------------------
-- logic_anal_clk <= debug_adc(21); -- ADC_DCO_IN(0) 
-- 
-- THE_TESTLINE_PROC: process( logic_anal_clk )
-- begin
--   if( rising_edge(logic_anal_clk) ) then
--     logic_anal_data(14)           <= '0';
--     logic_anal_data(13)           <= reset_i;                --'0';
--     logic_anal_data(12)           <= debug_adc(20);          -- realstore(0)
--     logic_anal_data(11)           <= debug_adc(19);          -- swap(0)
--     logic_anal_data(10)           <= debug_adc(18);          -- recstore
--     logic_anal_data(9 downto 0)   <= debug_adc(17 downto 8); -- ADC 0 parallelized data
--   end if;
-- end process;


-- proc_testline : process(clk_100)
--     begin
--       if rising_edge(clk_100) then
--         TEST_LINE(14 downto 0) <= MED_DATAREADY_OUT & MED_DATAREADY_IN & reset_i & reset_i_q & stat_reg_strobe(0) & MED_DATA_IN(9 downto 0);
--       end if;
-- end process;

-- TEST_LINE(15) <= clk_100;
-- TEST_LINE(15)          <= logic_anal_clk;
-- TEST_LINE(14)          <= clk_100;
-- TEST_LINE(13 downto 0) <= logic_anal_data(13 downto 0);

end architecture;