LIBRARY ieee;
use ieee.std_logic_1164.all;
USE IEEE.numeric_std.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb_net16_hub_func.all;
use work.version.all;


entity shower_fpga3 is
  generic(
    USE_GBE : integer range c_NO to c_YES := c_NO
    );
  port(
    --Clocks
    CLK_100_IN          : in  std_logic;
    CLK_125_IN          : in  std_logic;
    --Resets
    RESET_F3            : in  std_logic;
    ADDON_RESET         : in  std_logic;

    --LED
    DADC_OFF            : out std_logic;
    DBUSY               : out std_logic;
    DEADTIME            : out std_logic;
    DTRIGGER            : out std_logic;
    DWAIT               : out std_logic;
    TRBNET_OK           : out std_logic;
    TRBNET_RX           : out std_logic;
    TRBNET_TX           : out std_logic;
    GBE_OK              : out std_logic;
    GBE_RX              : out std_logic;
    GBE_TX              : out std_logic;

    --TRB
    ADO_TTL             : inout std_logic_vector(32 downto 0);
    ADO_LV              : inout std_logic_vector(32 downto 0);
    FS_PE               : inout std_logic_vector(17 downto 5);
    --FPGA1
    F1_F3               : inout std_logic_vector(22 downto 0);
    F1_100_RXN          : in  std_logic;
    F1_100_RXP          : in  std_logic;
    F1_100_TXN          : out std_logic;
    F1_100_TXP          : out std_logic;
    F1_125_RXN          : in  std_logic;
    F1_125_RXP          : in  std_logic;
    F1_125_TXN          : out std_logic;
    F1_125_TXP          : out std_logic;
    --FPGA2
    F2_F3               : inout std_logic_vector(22 downto 0);
    F2_100_RXN          : in  std_logic;
    F2_100_RXP          : in  std_logic;
    F2_100_TXN          : out std_logic;
    F2_100_TXP          : out std_logic;
    F2_125_RXN          : in  std_logic;
    F2_125_RXP          : in  std_logic;
    F2_125_TXN          : out std_logic;
    F2_125_TXP          : out std_logic;

    --SFP TrbNet
    TRBNET_TXP          : out std_logic;
    TRBNET_TXN          : out std_logic;
    TRBNET_RXP          : in  std_logic;
    TRBNET_RXN          : in  std_logic;
    TRBNET_TXDIS        : out std_logic;  --disable sfp
    TRBNET_MOD          : inout std_logic_vector(2 downto 0);
    TRBNET_LOS          : in  std_logic;

    --SFP GbE
    GBE_TXP             : out std_logic;
    GBE_TXN             : out std_logic;
    GBE_RXP             : in  std_logic;
    GBE_RXN             : in  std_logic;
    GBE_TXDIS           : out std_logic;  --disable sfp
    GBE_MOD             : inout std_logic_vector(2 downto 0);
    GBE_LOS             : in  std_logic;

    --Display
    SLR_A               : out std_logic_vector(1 downto 0);
    SLR_D               : out std_logic_vector(6 downto 0);
    SLR_RW              : out std_logic;
    DIS1                : out std_logic_vector(2 downto 0);
    DIS2                : out std_logic_vector(2 downto 0);

    --RAM1
    RAM1_A              : out std_logic_vector(19 downto 0);
    RAM1_DQ             : inout std_logic_vector(17 downto 0);
    RAM1_ADSCB          : out std_logic;
    RAM1_ADSPB          : out std_logic;
    RAM1_ADVB           : out std_logic;
    RAM1_CE             : out std_logic;
    RAM1_CLK            : out std_logic;
    RAM1_GWB            : out std_logic;
    RAM1_OEB            : out std_logic;

    --RAM2
    RAM2_A              : out std_logic_vector(19 downto 0);
    RAM2_DQ             : inout std_logic_vector(17 downto 0);
    RAM2_ADSCB          : out std_logic;
    RAM2_ADSPB          : out std_logic;
    RAM2_ADVB           : out std_logic;
    RAM2_CE             : out std_logic;
    RAM2_CLK            : out std_logic;
    RAM2_GWB            : out std_logic;
    RAM2_OEB            : out std_logic;

    --Trigger
    HOLD                : in  std_logic;
    RESERVE             : in  std_logic_vector(1 downto 0);
    SPARE_INP           : in  std_logic;

    --ONEWIRE
    ONEWIRE             : inout std_logic;
    ONEWIRE_MONITOR_OUT : out std_logic_vector(2 downto 1);

    --SPI / Flash
    SPI_CLK_OUT         : out std_logic;
    SPI_CS_OUT          : out std_logic;
    SPI_SO_IN           : in  std_logic;
    SPI_SI_OUT          : out std_logic;
    PROGRAMB            : out std_logic
    );

  attribute syn_useioff : boolean;
  attribute syn_useioff of SPI_CLK_OUT : signal is true;
  attribute syn_useioff of SPI_CS_OUT  : signal is true;
  attribute syn_useioff of SPI_SO_IN   : signal is true;
  attribute syn_useioff of SPI_SI_OUT  : signal is true;

  attribute syn_useioff of RAM1_A      : signal is true;
  attribute syn_useioff of RAM1_DQ     : signal is true;
  attribute syn_useioff of RAM1_ADSCb  : signal is true;
  attribute syn_useioff of RAM1_ADSPb  : signal is true;
  attribute syn_useioff of RAM1_ADVb   : signal is true;
  attribute syn_useioff of RAM1_CE     : signal is true;
  attribute syn_useioff of RAM1_CLK    : signal is true;
  attribute syn_useioff of RAM1_GWb    : signal is true;
  attribute syn_useioff of RAM1_OEb    : signal is true;

  attribute syn_useioff of RAM2_A      : signal is true;
  attribute syn_useioff of RAM2_DQ     : signal is true;
  attribute syn_useioff of RAM2_ADSCb  : signal is true;
  attribute syn_useioff of RAM2_ADSPb  : signal is true;
  attribute syn_useioff of RAM2_ADVb   : signal is true;
  attribute syn_useioff of RAM2_CE     : signal is true;
  attribute syn_useioff of RAM2_CLK    : signal is true;
  attribute syn_useioff of RAM2_GWb    : signal is true;
  attribute syn_useioff of RAM2_OEb    : signal is true;

  attribute syn_useioff of F1_F3       : signal is true;
  attribute syn_useioff of F2_F3       : signal is true;
  attribute syn_useioff of ADO_TTL     : signal is true;
  attribute syn_useioff of ADO_LV      : signal is true;

  attribute syn_useioff of DADC_OFF    : signal is false;
  attribute syn_useioff of DBUSY       : signal is false;
  attribute syn_useioff of DEADTIME    : signal is false;
  attribute syn_useioff of DTRIGGER    : signal is false;
  attribute syn_useioff of DWAIT       : signal is false;
  attribute syn_useioff of TRBNET_OK   : signal is false;
  attribute syn_useioff of TRBNET_RX   : signal is false;
  attribute syn_useioff of TRBNET_TX   : signal is false;
  attribute syn_useioff of GBE_OK      : signal is false;
  attribute syn_useioff of GBE_RX      : signal is false;
  attribute syn_useioff of GBE_TX      : signal is false;

  attribute syn_useioff of ONEWIRE_MONITOR_OUT : signal is false;
  attribute syn_useioff of ONEWIRE     : signal is false;

end entity;

architecture shower_fpga3_arch of shower_fpga3 is

  signal clk_100                : std_logic;
  signal clk_en                 : std_logic;
  signal reset_i                : std_logic;
  signal reset_i_q              : std_logic;
  signal reset_counter          : unsigned(11 downto 0);
  signal pll_locked             : std_logic;
  signal make_reset_via_network : std_logic;

  signal med_stat_op        : std_logic_vector(63  downto 0);
  signal med_ctrl_op        : std_logic_vector(63  downto 0);
  signal med_stat_debug     : std_logic_vector(255 downto 0);
  signal med_ctrl_debug     : std_logic_vector(63  downto 0);
  signal med_data_out       : std_logic_vector(63  downto 0);
  signal med_packet_num_out : std_logic_vector(11  downto 0);
  signal med_dataready_out  : std_logic_vector(3   downto 0);
  signal med_read_out       : std_logic_vector(3   downto 0);
  signal med_data_in        : std_logic_vector(63  downto 0);
  signal med_packet_num_in  : std_logic_vector(11  downto 0);
  signal med_dataready_in   : std_logic_vector(3   downto 0);
  signal med_read_in        : std_logic_vector(3   downto 0);
  signal onewire_monitor    : std_logic;

  signal common_stat_regs   : std_logic_vector (std_COMSTATREG*32-1 downto 0);
  signal common_ctrl_regs   : std_logic_vector (std_COMCTRLREG*32-1 downto 0);
  signal my_address         : std_logic_vector (15 downto 0);

  signal regio_addr_out            : std_logic_vector(16-1 downto 0);
  signal regio_read_enable_out     : std_logic;
  signal regio_write_enable_out    : std_logic;
  signal regio_data_out            : std_logic_vector(32-1 downto 0);
  signal regio_data_in             : std_logic_vector(32-1 downto 0);
  signal regio_dataready_in        : std_logic;
  signal regio_no_more_data_in     : std_logic;
  signal regio_write_ack_in        : std_logic;
  signal regio_unknown_addr_in     : std_logic;
  signal regio_timeout_out         : std_logic;

  signal spictrl_read_en   : std_logic;
  signal spictrl_write_en  : std_logic;
  signal spictrl_data_in   : std_logic_vector(31 downto 0);
  signal spictrl_addr      : std_logic;
  signal spictrl_data_out  : std_logic_vector(31 downto 0);
  signal spictrl_ack       : std_logic;
  signal spictrl_busy      : std_logic;
  signal spimem_read_en   : std_logic;
  signal spimem_write_en  : std_logic;
  signal spimem_data_in   : std_logic_vector(31 downto 0);
  signal spimem_addr      : std_logic_vector(5 downto 0);
  signal spimem_data_out  : std_logic_vector(31 downto 0);
  signal spimem_ack       : std_logic;

  signal spi_bram_addr  : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d  : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d  : std_logic_vector(7 downto 0);
  signal spi_bram_we    : std_logic;

  signal cts_number_out              : std_logic_vector(15 downto 0);
  signal cts_code_out                : std_logic_vector(7 downto 0);
  signal cts_information_out         : std_logic_vector(7 downto 0);
  signal cts_start_readout_out       : std_logic;
  signal cts_readout_type_out        : std_logic_vector(3 downto 0);
  signal cts_data_in                 : std_logic_vector(31 downto 0);
  signal cts_dataready_in            : std_logic;
  signal cts_readout_finished_in     : std_logic;
  signal cts_read_out                : std_logic;
  signal cts_length_in               : std_logic_vector(15 downto 0);
  signal cts_status_bits_in          : std_logic_vector(31 downto 0);
  signal fee_data_out                : std_logic_vector(15 downto 0);
  signal fee_dataready_out           : std_logic;
  signal fee_read_in                 : std_logic;
  signal fee_status_bits_out         : std_logic_vector(31 downto 0);
  signal fee_busy_out                : std_logic;

  signal test_counter            : unsigned(31 downto 0);
  signal delayed_restart_fpga    : std_logic;
  signal restart_fpga_counter    : unsigned(11 downto 0);


begin
---------------------------------------------------------------------------
-- Clock & Reset state machine
---------------------------------------------------------------------------
  clk_en                 <= '1';
  reset_i_q              <= not pll_locked;
  make_reset_via_network <= MED_STAT_OP(0*16 + 13);

  THE_PLL : pll_in100_out100
    port map(
      CLK      => CLK_100_IN,
      CLKOP    => clk_100,
      LOCK     => pll_locked
      );

  THE_RESET_COUNTER_PROC: process( pll_locked, clk_100 )
    begin
      if( pll_locked = '0' ) then
          reset_counter <= (others => '0');
          reset_i       <= '1';
      elsif( rising_edge(clk_100) ) then
          if   ( make_reset_via_network = '1' ) then
              reset_counter <= (others => '0');
              reset_i       <= '1';
          elsif( reset_counter = x"EEE" ) then
              reset_counter <= x"EEE";
              reset_i       <= '0';
          else
              reset_counter <= reset_counter + to_unsigned(1,1);
              reset_i       <= '1';
          end if;
      end if;
    end process;


---------------------------------------------------------------------------
-- Media Interface TrbNet
---------------------------------------------------------------------------
  THE_MEDIA_INTERFACE : trb_net16_med_ecp_sfp_4_gbe
    generic map(
      REVERSE_ORDER => c_NO
      )
    port map(
      CLK                    => CLK_100_IN,
      SYSCLK                 => clk_100,
      RESET                  => reset_i,
      CLEAR                  => reset_i_q,
      CLK_EN                 => clk_en,
      MED_DATA_IN            => med_data_out(4*16-1 downto 0*16),
      MED_PACKET_NUM_IN      => med_packet_num_out(4*3-1 downto 0*3),
      MED_DATAREADY_IN       => med_dataready_out(3 downto 0),
      MED_READ_OUT           => med_read_in(3 downto 0),
      MED_DATA_OUT           => med_data_in(4*16-1 downto 0*16),
      MED_PACKET_NUM_OUT     => med_packet_num_in(4*3-1 downto 0*3),
      MED_DATAREADY_OUT      => med_dataready_in(3 downto 0),
      MED_READ_IN            => med_read_out(3 downto 0),
      REFCLK2CORE_OUT        => open,
      SD_RXD_P_IN(0)         => TRBNET_RXP,
      SD_RXD_N_IN(0)         => TRBNET_RXN,
      SD_TXD_P_OUT(0)        => TRBNET_TXP,
      SD_TXD_N_OUT(0)        => TRBNET_TXN,
      SD_RXD_P_IN(2)         => F1_100_RXP,
      SD_RXD_N_IN(2)         => F1_100_RXN,
      SD_TXD_P_OUT(2)        => F1_100_TXP,
      SD_TXD_N_OUT(2)        => F1_100_TXN,
      SD_RXD_P_IN(3)         => F2_100_RXP,
      SD_RXD_N_IN(3)         => F2_100_RXN,
      SD_TXD_P_OUT(3)        => F2_100_TXP,
      SD_TXD_N_OUT(3)        => F2_100_TXN,
      SD_REFCLK_P_IN         => open,
      SD_REFCLK_N_IN         => open,
      SD_PRSNT_N_IN(0)       => TRBNET_MOD(0),
      SD_PRSNT_N_IN(1)       => '1',
      SD_PRSNT_N_IN(2)       => '0',
      SD_PRSNT_N_IN(3)       => '0',
      SD_LOS_IN(0)           => TRBNET_LOS,
      SD_LOS_IN(1)           => '1',
      SD_LOS_IN(2)           => '0',
      SD_LOS_IN(3)           => '0',
      SD_TXDIS_OUT(0)        => TRBNET_TXDIS,
      STAT_OP                => med_stat_op(4*16-1 downto 0*16),
      CTRL_OP                => med_ctrl_op(4*16-1 downto 0*16),
      STAT_DEBUG             => med_stat_debug(4*64-1 downto 0*64),
      CTRL_DEBUG             => med_ctrl_debug(4*16-1 downto 0*16)
      );

--Debug CTRL is unused
  med_ctrl_debug <= (others => '0');

--Serdes 1 is unused
  med_ctrl_op(31 downto 16)      <= (others => '0');
  med_ctrl_debug(31 downto 16)  <= (others => '0');
  med_data_out(31 downto 16)     <= (others => '0');
  med_packet_num_out(5 downto 3) <= (others => '0');
  med_dataready_out(1)           <= '0';
  med_read_out(1)                <= '0';

---------------------------------------------------------------------------
-- Hub
---------------------------------------------------------------------------
-- 1: FPGA1, 2: FPGA2, 0: Uplink

  gen_normal_hub : if USE_GBE = c_NO generate
    THE_HUB : trb_net16_hub_base
      generic map (
        HUB_USED_CHANNELS => (c_YES,c_YES,c_NO,c_YES),
        IBUF_SECURE_MODE  => c_YES,
        MII_NUMBER        => 3,
        MII_IS_UPLINK     => (0 => 1, others => 0),
        MII_IS_DOWNLINK   => (0 => 0, others => 1),
        INT_NUMBER        => 0,
        INT_CHANNELS      => (0,1,3,3,3,3,3,3),
        USE_ONEWIRE       => c_YES,
        COMPILE_TIME      => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32)),
        HARDWARE_VERSION  => x"42300000",
        INIT_ENDPOINT_ID  => x"0003"
        )
      port map (
        CLK    => clk_100,
        RESET  => reset_i,
        CLK_EN => clk_en,

        --Media interfacces
        MED_DATAREADY_OUT(0)            => med_dataready_out(0),
        MED_DATA_OUT(15 downto 0)       => med_data_out(15 downto 0),
        MED_PACKET_NUM_OUT(2 downto 0)  => med_packet_num_out(2 downto 0),
        MED_READ_IN(0)                  => med_read_in(0),
        MED_DATAREADY_IN(0)             => med_dataready_in(0),
        MED_DATA_IN(15 downto 0)        => med_data_in(15 downto 0),
        MED_PACKET_NUM_IN(2 downto 0)   => med_packet_num_in(2 downto 0),
        MED_READ_OUT(0)                 => med_read_out(0),
        MED_STAT_OP(15 downto 0)        => med_stat_op(15 downto 0),
        MED_CTRL_OP(15 downto 0)        => med_ctrl_op(15 downto 0),

        MED_DATAREADY_OUT(2 downto 1)   => med_dataready_out(3 downto 2),
        MED_DATA_OUT(47 downto 16)      => med_data_out(63 downto 32),
        MED_PACKET_NUM_OUT(8 downto 3)  => med_packet_num_out(11 downto 6),
        MED_READ_IN(2 downto 1)         => med_read_in(3 downto 2),
        MED_DATAREADY_IN(2 downto 1)    => med_dataready_in(3 downto 2),
        MED_DATA_IN(47 downto 16)       => med_data_in(63 downto 32),
        MED_PACKET_NUM_IN(8 downto 3)   => med_packet_num_in(11 downto 6),
        MED_READ_OUT(2 downto 1)        => med_read_out(3 downto 2),
        MED_STAT_OP(47 downto 16)       => med_stat_op(63 downto 32),
        MED_CTRL_OP(47 downto 16)       => med_ctrl_op(63 downto 32),

        COMMON_STAT_REGS                => common_stat_regs,
        COMMON_CTRL_REGS                => common_ctrl_regs,
        MY_ADDRESS_OUT                  => my_address,
        --REGIO INTERFACE
        REGIO_ADDR_OUT                  => regio_addr_out,
        REGIO_READ_ENABLE_OUT           => regio_read_enable_out,
        REGIO_WRITE_ENABLE_OUT          => regio_write_enable_out,
        REGIO_DATA_OUT                  => regio_data_out,
        REGIO_DATA_IN                   => regio_data_in,
        REGIO_DATAREADY_IN              => regio_dataready_in,
        REGIO_NO_MORE_DATA_IN           => regio_no_more_data_in,
        REGIO_WRITE_ACK_IN              => regio_write_ack_in,
        REGIO_UNKNOWN_ADDR_IN           => regio_unknown_addr_in,
        REGIO_TIMEOUT_OUT               => regio_timeout_out,

        ONEWIRE                         => ONEWIRE,
        ONEWIRE_MONITOR_OUT             => onewire_monitor,
        --Status ports (for debugging)
        MPLEX_CTRL            => (others => '0'),
        CTRL_DEBUG            => (others => '0'),
        STAT_DEBUG            => open
        );
  end generate;


  gen_ethernet_hub : if USE_GBE = c_YES generate
   THE_HUB: trb_net16_hub_streaming_port
      generic map(
        HUB_USED_CHANNELS => (c_YES,c_YES,c_NO,c_YES),
        IBUF_SECURE_MODE  => c_YES,
        MII_NUMBER        => 3,
        MII_IS_UPLINK     => (0 => 1, 1 => 0, 2 => 0,others => 1),
        MII_IS_DOWNLINK   => (others => 1),
        USE_ONEWIRE       => c_YES,
        INIT_ENDPOINT_ID  => x"0002",
        HARDWARE_VERSION  => x"42300000",
        COMPILE_TIME      => std_logic_vector(to_unsigned(VERSION_NUMBER_TIME,32))
        )
      port map(
        CLK                       => clk_100,
        RESET                     => reset_i,
        CLK_EN                    => clk_en,
        --Media interfacces
        MED_DATAREADY_OUT(0)            => med_dataready_out(0),
        MED_DATA_OUT(15 downto 0)       => med_data_out(15 downto 0),
        MED_PACKET_NUM_OUT(2 downto 0)  => med_packet_num_out(2 downto 0),
        MED_READ_IN(0)                  => med_read_in(0),
        MED_DATAREADY_IN(0)             => med_dataready_in(0),
        MED_DATA_IN(15 downto 0)        => med_data_in(15 downto 0),
        MED_PACKET_NUM_IN(2 downto 0)   => med_packet_num_in(2 downto 0),
        MED_READ_OUT(0)                 => med_read_out(0),
        MED_STAT_OP(15 downto 0)        => med_stat_op(15 downto 0),
        MED_CTRL_OP(15 downto 0)        => med_ctrl_op(15 downto 0),

        MED_DATAREADY_OUT(2 downto 1)   => med_dataready_out(3 downto 2),
        MED_DATA_OUT(47 downto 16)      => med_data_out(63 downto 32),
        MED_PACKET_NUM_OUT(8 downto 3)  => med_packet_num_out(11 downto 6),
        MED_READ_IN(2 downto 1)         => med_read_in(3 downto 2),
        MED_DATAREADY_IN(2 downto 1)    => med_dataready_in(3 downto 2),
        MED_DATA_IN(47 downto 16)       => med_data_in(63 downto 32),
        MED_PACKET_NUM_IN(8 downto 3)   => med_packet_num_in(11 downto 6),
        MED_READ_OUT(2 downto 1)        => med_read_out(3 downto 2),
        MED_STAT_OP(47 downto 16)       => med_stat_op(63 downto 32),
        MED_CTRL_OP(47 downto 16)       => med_ctrl_op(63 downto 32),

        --Event information coming from CTS
        CTS_NUMBER_OUT            => cts_number_out,
        CTS_CODE_OUT              => cts_code_out,
        CTS_INFORMATION_OUT       => cts_information_out,
        CTS_READOUT_TYPE_OUT      => cts_readout_type_out,
        CTS_START_READOUT_OUT     => cts_start_readout_out,
        --Information sent to CTS
        --status data, equipped with DHDR
        CTS_DATA_IN               => cts_data_in,
        CTS_DATAREADY_IN          => cts_dataready_in,
        CTS_READOUT_FINISHED_IN   => cts_readout_finished_in,
        CTS_READ_OUT              => cts_read_out,
        CTS_LENGTH_IN             => cts_length_in,
        CTS_STATUS_BITS_IN        => cts_status_bits_in,
        -- Data from Frontends
        FEE_DATA_OUT              => fee_data_out,
        FEE_DATAREADY_OUT         => fee_dataready_out,
        FEE_READ_IN               => fee_read_in,
        FEE_STATUS_BITS_OUT       => fee_status_bits_out,
        FEE_BUSY_OUT              => fee_busy_out,
        MY_ADDRESS_IN             => my_address,
        COMMON_STAT_REGS          => common_stat_regs,
        COMMON_CTRL_REGS          => common_ctrl_regs,
        MY_ADDRESS_OUT            => my_address,
        ONEWIRE                   => ONEWIRE,
        ONEWIRE_MONITOR_OUT       => onewire_monitor,
        --REGIO INTERFACE
        REGIO_ADDR_OUT            => regio_addr_out,
        REGIO_READ_ENABLE_OUT     => regio_read_enable_out,
        REGIO_WRITE_ENABLE_OUT    => regio_write_enable_out,
        REGIO_DATA_OUT            => regio_data_out,
        REGIO_DATA_IN             => regio_data_in,
        REGIO_DATAREADY_IN        => regio_dataready_in,
        REGIO_NO_MORE_DATA_IN     => regio_no_more_data_in,
        REGIO_WRITE_ACK_IN        => regio_write_ack_in,
        REGIO_UNKNOWN_ADDR_IN     => regio_unknown_addr_in,
        REGIO_TIMEOUT_OUT         => regio_timeout_out,
        --Fixed status and control ports
        MPLEX_CTRL                => (others => '0'),
        CTRL_DEBUG                => (others => '0')
      );
  end generate;

---------------------------------------------------------------------------
-- Bus Handler
---------------------------------------------------------------------------
  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER    => 2,
      PORT_ADDRESSES => (0 => x"d000", 1 => x"d100", others => x"0000"),
      PORT_ADDR_MASK => (0 => 1, 1 => 6, others => 0)
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
      BUS_READ_ENABLE_OUT(0)              => spictrl_read_en,
      BUS_WRITE_ENABLE_OUT(0)             => spictrl_write_en,
      BUS_DATA_OUT(0*32+31 downto 0*32)   => spictrl_data_in,
      BUS_ADDR_OUT(0*16)                  => spictrl_addr,
      BUS_ADDR_OUT(0*16+15 downto 0*16+1) => open,
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATA_IN(0*32+31 downto 0*32)    => spictrl_data_out,
      BUS_DATAREADY_IN(0)                 => spictrl_ack,
      BUS_WRITE_ACK_IN(0)                 => spictrl_ack,
      BUS_NO_MORE_DATA_IN(0)              => spictrl_busy,
      BUS_UNKNOWN_ADDR_IN(0)              => '0',
    --Bus Handler (SPI Memory)
      BUS_READ_ENABLE_OUT(1)              => spimem_read_en,
      BUS_WRITE_ENABLE_OUT(1)             => spimem_write_en,
      BUS_DATA_OUT(1*32+31 downto 1*32)   => spimem_data_in,
      BUS_ADDR_OUT(1*16+5 downto 1*16)    => spimem_addr,
      BUS_ADDR_OUT(1*16+15 downto 1*16+6) => open,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATA_IN(1*32+31 downto 1*32)    => spimem_data_out,
      BUS_DATAREADY_IN(1)                 => spimem_ack,
      BUS_WRITE_ACK_IN(1)                 => spimem_ack,
      BUS_NO_MORE_DATA_IN(1)              => '0',
      BUS_UNKNOWN_ADDR_IN(1)              => '0',
      STAT_DEBUG  => open
      );

---------------------------------------------------------------------------
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
        PROGRAMB                 <= '1';
        delayed_restart_fpga     <= '0';
        restart_fpga_counter     <= x"FFF";
      elsif rising_edge(clk_100) then
        PROGRAMB                 <= not delayed_restart_fpga;
        delayed_restart_fpga     <= '0';
        if common_ctrl_regs(15) = '1' then
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
-- LED
---------------------------------------------------------------------------
  PROC_REG_LED : process(clk_100)
    begin
      if rising_edge(clk_100) then
        TRBNET_OK <= not med_stat_op(9);
        TRBNET_RX <= not med_stat_op(10);
        TRBNET_TX <= not med_stat_op(11);
      end if;
    end process;

--Unused LED
  DADC_OFF       <= test_counter(25);
  DBUSY          <= test_counter(0);
  DEADTIME       <= test_counter(24);
  DTRIGGER       <= test_counter(26);
  DWAIT          <= test_counter(23);
  GBE_OK         <= '1';
  GBE_RX         <= '0';
  GBE_TX         <= '0';

---------------------------------------------------------------------------
-- I/O
---------------------------------------------------------------------------
  ONEWIRE_MONITOR_OUT(1) <= onewire_monitor;
  ONEWIRE_MONITOR_OUT(2) <= onewire_monitor;

---------------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------------
  process(clk_100)
    begin
      if rising_edge(clk_100) then
        if reset_i = '1' then
          test_counter <= (others => '0');
        else
          test_counter <= test_counter + to_unsigned(1,1);
        end if;
      end if;
    end process;

---------------------------------------------------------------------------
-- Unused Ports
---------------------------------------------------------------------------
--TRB
  ADO_TTL        <= (others => 'Z');
  ADO_LV         <= (others => 'Z');
  FS_PE          <= (others => 'Z');

--Display
  SLR_A          <= "10";--(others => '0');
  SLR_D          <= "1000000";--(others => '0');
  SLR_RW         <= '1';
  DIS1           <= (others => '0');
  DIS2           <= (others => '0');

--RAM1
  RAM1_A         <= (others => '0');
  RAM1_DQ        <= (others => '0');
  RAM1_ADSCb     <= '1';
  RAM1_ADSPb     <= '1';
  RAM1_ADVb      <= '1';
  RAM1_CE        <= '0';
  RAM1_CLK       <= '0';
  RAM1_GWb       <= '1';
  RAM1_OEb       <= '1';

--RAM2
  RAM2_A         <= (others => '0');
  RAM2_DQ        <= (others => '0');
  RAM2_ADSCb     <= '1';
  RAM2_ADSPb     <= '1';
  RAM2_ADVb      <= '1';
  RAM2_CE        <= '0';
  RAM2_CLK       <= '0';
  RAM2_GWb       <= '1';
  RAM2_OEb       <= '1';

--SFP
  GBE_TXDIS      <= '1';
  GBE_MOD        <= (others => 'Z');
  TRBNET_MOD(2 downto 1) <= (others => 'Z');

--Other FPGA
  F1_F3(22 downto 0)   <= ( others => 'Z');
  F2_F3(22 downto 0)   <= ( others => 'Z');



end architecture;

