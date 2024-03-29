-- Module Name:    shower_components
-- Project Name:
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.trb_net_std.all;


package shower_components is

type ADC_FIFO_OUT_ARRAY is array (2 downto 1) of std_logic_vector(17 downto 0);
type ADC_OUT_ARRAY is array (8 downto 1) of std_logic_vector(9 downto 0);
type PEDESTAL_OUT_ARRAY is array (8 downto 1) of std_logic_vector (15 downto 0);
type S_2_P_ARRAY is array(8 downto 1) of std_logic_vector(4 downto 0);
type THRESHOLD_ARRAY is array (8 downto 1) of std_logic_vector(31 downto 0);
type write_state_type is (write_idle, write_one, write_two, write_three, write_four, write_five, write_six, write_seven, write_eight);
type read_state_type is (read_idle, read_one, read_two, read_three, read_four, read_five, read_six, read_seven, read_eight);
type lvl1_state_type is (IDLE, REALISE_DELAY, GENERATE_HOLD);

component substractor is
    port (
        DataA: in  std_logic_vector(11 downto 0); 
        DataB: in  std_logic_vector(11 downto 0); 
        Result: out  std_logic_vector(11 downto 0));
end component;

component start is
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
end component;

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
      THRESHOLD_IN    : in std_logic_vector(11 downto 0);
      POSITION_IN	: in std_logic_vector(3 downto 0);
      SUM_SAMPLES_IN  : in std_logic_vector(31 downto 0);
      EVENT_SAVED_OUT : out std_logic
);
end component;

component fifo_1kx18 is
    port (
        Data: in  std_logic_vector(17 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(17 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic;
        AlmostEmpty: out  std_logic);
end component;

component pll_in100_out10 is
    port (
        CLK: in std_logic; 
        CLKOP: out std_logic; 
        LOCK: out std_logic);
end component;

component gbe_setup is
port(
  CLK                       : in std_logic;
  RESET                     : in std_logic;

  -- interface to regio bus
  BUS_ADDR_IN               : in std_logic_vector(7 downto 0);
  BUS_DATA_IN               : in std_logic_vector(31 downto 0);
  BUS_DATA_OUT              : out std_logic_vector(31 downto 0);
  BUS_WRITE_EN_IN           : in std_logic;
  BUS_READ_EN_IN            : in std_logic;
  BUS_ACK_OUT               : out std_logic;

--inputs
--   LVL1_STATE_IN             : in std_logic_vector(2 downto 0);
--   ADC_WR_STATE_IN           : in std_logic_vector(31 downto 0);
--   FEB_ENGINE_STATE_IN       : in std_logic_vector(7 downto 0);

  DESYNC_IN                 : in std_logic_vector(5 downto 0);

--outputs
  OSC_MODE_OUT              : out std_logic;
  SUM_SAMPLES_OUT           : out std_logic_vector(31 downto 0);
  TRIGGER_POS_OUT           : out std_logic_vector(9 downto 0);
  THRESHOLD_OUT             : out std_logic_vector(11 downto 0);
  POSITION_OUT              : out std_logic_vector(3 downto 0);
  MAX_SAMPLES_OUT           : out std_logic_vector(9 downto 0)
);
end component;

component pll_20MHz is
    port (	CLK		: in std_logic;
    		CLKOP		: out std_logic;
    		LOCK		: out std_logic);
end component;

component ddr_generic is
    port (
        Clk: in  std_logic; 
        Data: in  std_logic_vector(1 downto 0); 
        Q: out  std_logic_vector(0 downto 0));
end component;


component serpar2 is
    port (
      RESET          		: in std_logic;
      ADC_CLOCK      		: in std_logic;
      SYS_CLOCK      		: in std_logic;
      ADC_INPUT      		: in std_logic_vector(15 downto 0);
      FRAME_CLOCK    		: in std_logic_vector(1 downto 0);
      ADC_RESULT_OUT 		: out std_logic_vector(79 downto 0);
      ADC_RESULT_VALID_OUT 	: out std_logic;
      fifo_full			: out std_logic;
      fifo_empty		: out std_logic;
      debug         : out std_logic_vector(31 downto 0)
      );
end component;

component pedestal_DPRAM_32x16 is
    port(
		WrAddress	: in  std_logic_vector(4 downto 0);
        RdAddress	: in  std_logic_vector(4 downto 0);
 		DATA		: in  std_logic_vector(15 downto 0);
		WE			: in  std_logic;
		RdClock		: in  std_logic;
		RdClockEn	: in  std_logic;
		Reset		: in  std_logic;
        WrClock		: in  std_logic;
		WrClockEn	: in  std_logic;
		Q			: out std_logic_vector(15 downto 0));
end component;


component fifo_dc_18x8 is
      port (
          Data			: in  std_logic_vector(17 downto 0);
          WrClock		: in  std_logic;
          RdClock		: in  std_logic;
          WrEn			: in  std_logic;
          RdEn			: in  std_logic;
          Reset			: in  std_logic;
          RPReset		: in  std_logic;
          Q			: out  std_logic_vector(17 downto 0);
          Empty			: out  std_logic;
          Full			: out  std_logic
          );
end component;

component fifo_af_dc_18x8 is
    port (
        Data        : in  std_logic_vector(17 downto 0); 
        WrClock     : in  std_logic; 
        RdClock     : in  std_logic; 
        WrEn        : in  std_logic; 
        RdEn        : in  std_logic; 
        Reset       : in  std_logic; 
        RPReset     : in  std_logic; 
        Q           : out  std_logic_vector(17 downto 0); 
        RCNT        : out  std_logic_vector(3 downto 0); 
        Empty       : out  std_logic; 
        Full        : out  std_logic; 
        AlmostEmpty : out  std_logic);
end component;

component ddr_input_ff is
      port (
          Del			: in  std_logic_vector(3 downto 0);
          Clk			: in  std_logic;
          Rst			: in  std_logic;
          Data			: in  std_logic_vector(0 downto 0);
          Q			: out  std_logic_vector(1 downto 0));
end component;

component ddr_iff_sysclk is
    port (
        Del: in  std_logic_vector(3 downto 0); 
        ECLK: in  std_logic; 
        SCLK: in  std_logic; 
        Rst: in  std_logic; 
        Data: in  std_logic_vector(0 downto 0); 
        Q: out  std_logic_vector(1 downto 0));
end component;


component FEB_engine is
       port( RESET             : in std_logic;
              CLOCK             : in std_logic;         -- 100 MHz

			-- hold generated outside of FEB_engine
				REAL_HOLD_IN	: in std_logic;

			-- lvl1 trigger handling
				LVL1_VALID_NOTIMING_TRG_IN    : in std_logic;
				LVL1_INVALID_TRG_IN : in std_logic;

				LVL1_TRG_DATA_VALID_IN	: 	in std_logic;
				LVL1_TRG_TYPE_IN		: in std_logic_vector(3  downto 0);
				LVL1_TRG_INFORMATION_IN	: in std_logic_vector(23  downto 0);

			-- defines end of BUSY from ShowerAddOn
				FEE_TRG_RELEASE_OUT : out std_logic;
        FEB_64TH_PEDESTAL_IN     : in std_logic;

			-- 10ns pulse indicating that FEB multiplexed another channel at the output
         FEB_MUX_NEW_CHAN_RDY_OUT	: out std_logic;
         ADC_VALID_SYNCH_IN     : in std_logic;

			-- hardware output signal driving front-ends
              INT_HOLD_OUT          : out std_logic;
              FEB_CLOCK_OUT         : out std_logic;
              FEB_RESET_OUT         : out std_logic;
              FEB_RBITIN_OUT        : out std_logic;
              FEB_ENABLE_OUT        : out std_logic;
              FEB_EVEN_OUT          : out std_logic;
              FEB_ODD_OUT           : out std_logic;

        ENGINE_STATE_OUT            : out std_logic_vector(7 downto 0);  -- gk 02.11.10
        PED_PAUSE_IN                : in std_logic_vector(31 downto 0);  -- gk 09.11.10
        PED_NUM_OF_SAMPLES_IN       : in std_logic_vector(6 downto 0);  -- gk 10.11.10

				DEBUG_OUT			: out std_logic_vector(15 downto 0)
				);
end component;

component read_ADC is
    generic (
--       LOCAL_ID   : std_logic_vector := "0000";
       IOFF_DELAY : in std_logic_vector := "0000";
	 ADC_ID       : integer range 0 to 7 := 0
       );
  	port (	RESET					: in std_logic;
			  CLOCK					    : in std_logic;
        --Pedestal / connection to bus handler
		PED_DATA_IN            : in std_logic_vector(9 downto 0);
		PED_DATA_OUT           : out std_logic_vector(9 downto 0);
		TRB_PED_ADDR_IN        : in std_logic_vector(8 downto 0);
        PED_READ_IN            : in std_logic;
        PED_WRITE_IN           : in std_logic;
        PED_READ_ACK_OUT       : out std_logic;
        PED_WRITE_ACK_OUT      : out std_logic;
        PED_BUSY_OUT           : out std_logic;
        PED_UNKNOWN_OUT        : out std_logic;

			IOFF_DELAY_IN			    : in std_logic_vector(3 downto 0);
			LOCAL_ID_IN				    : in std_logic_vector(3 downto 0);
			SAMPLING_PATTERN_IN		: in std_logic_vector (3 downto 0);
			THRESHOLD_IN			    : in std_logic_vector (3 downto 0);

         --ADC inputs
			ADC_DATA_CLOCK_IN 			  : in std_logic;
			ADC_FRAME_CLOCK_IN			  : in std_logic;
			ADC_SERIAL_IN		          : in std_logic_vector(7 downto 0);

--         --Control signals from FEB
-- 10 ns pulse when FEB multiplexer advances input channel
			FEB_MUX_NEW_CHAN_RDY_IN	  : in std_logic;
      ADC_VALID_SYNCH_OUT       : out std_logic;

			--  data/trigger interface to endpoint handler
			FEE_TRG_TYPE_IN			      : in std_logic_vector(3  downto 0);
      FEE_TRG_RELEASE_OUT       : out std_logic;
      FEE_TRG_DATA_VALID_IN     : in std_logic;
      FEE_VALID_TIMING_TRG_IN   : in std_logic;
      FEE_VALID_NOTIMING_TRG_IN : in std_logic;
			FEE_DATA_OUT			        : out std_logic_vector(31 downto 0);
			FEE_DATA_WRITE_OUT		    : out std_logic;
			FEE_DATA_FINISHED_OUT	    : out std_logic;

         --Data Output to ipu_handler
        IPU_DAT_DATA_OUT        : out std_logic_vector(26 downto 0);
        IPU_DAT_DATA_READ_IN    : in std_logic;
        IPU_DAT_DATA_EMPTY_OUT  : out std_logic;
        IPU_HDR_DATA_OUT        : out std_logic_vector(17 downto 0);
        IPU_HDR_DATA_READ_IN    : in std_logic;
        IPU_HDR_DATA_EMPTY_OUT  : out std_logic;

-- outputs to trb Slow Control REGIO_STAT_REG
      SERPAR_INPUT_FIFO_EMPTY   : out std_logic;
      SERPAR_INPUT_FIFO_FULL    : out std_logic;
        --Debug

        WRITE_STATE_OUT        : out std_logic_vector(3 downto 0);  -- gk 02.11.10
	DESYNC_OUT              : out std_logic;

        TRIGGER_POS_IN          : in std_logic_vector(9 downto 0);  -- gk 21.12.10
        MAX_SAMPLES_IN          : in std_logic_vector(9 downto 0);  -- gk 21.12.10
        SUM_SAMPLES_IN          : in std_logic_vector(31 downto 0);
        OSC_MODE_IN             : in std_logic;  -- gk 10.01.11
	THRESHOLD_CF_IN            : in std_logic_vector(11 downto 0);
	POSITION_IN	: in std_logic_vector(3 downto 0);

        ENABLE_DEBUG_IN         : in std_logic;
			ADC_INSPECT_BUS			      : out std_logic_vector(35 downto 0)
		);
end component;

component display is
  generic (
    NUMBER_OF_LETTERS : positive
    );
	port (
	RESET    : in  std_logic;
	CLK      : in  std_logic;
	DISP_A   : out  std_logic_vector(1 downto 0);
	DISP_D   : out std_logic_vector(6 downto 0);
	DISP_WR  : out std_logic;
	SENTENCE : in  std_logic_vector(NUMBER_OF_LETTERS*8-1 downto 0));
end component;


component shower_spi_adc_master
generic(
  RESET_VALUE_CTRL    : std_logic_vector(7 downto 0) := x"00"
);
port(
  CLK_IN          : in    std_logic;
  RESET_IN        : in    std_logic;
  -- Slave bus
  SLV_READ_IN     : in    std_logic;
  SLV_WRITE_IN    : in    std_logic;
  SLV_BUSY_OUT    : out   std_logic;
  SLV_ACK_OUT     : out   std_logic;
  SLV_DATA_IN     : in    std_logic_vector(31 downto 0);
  SLV_DATA_OUT    : out   std_logic_vector(31 downto 0);
  -- SPI connections
  SPI_CS_OUT      : out   std_logic;
  SPI_SDO_OUT     : out   std_logic;
  SPI_SCK_OUT     : out   std_logic;
  -- ADC connections
  ADC_LOCKED_IN   : in    std_logic;
  ADC_PD_OUT      : out   std_logic;
  ADC_RST_OUT     : out   std_logic;
  ADC_DEL_OUT     : out   std_logic_vector(3 downto 0);
  -- Status lines
  STAT            : out   std_logic_vector(31 downto 0) -- DEBUG
);
end component;

component shower_adc_data_handler

port(
  CLK_IN          : in    std_logic;                    -- SYSCLK from fabric
  RESET_IN        : in    std_logic;                    -- synchronous reset (SYSCLK clock domain)
  ADC_RESET_IN    : in    std_logic;                    -- synchronous reset (ADC_DCO clock domain)
  ADC_DCO_IN     : in    std_logic;                    -- DCO clock from ADC (direct I/O connection)
  ADC_FCO_IN    : in    std_logic;                    -- FCO clock from ADC (direct I/O connection)
  ADC_CHNL_IN     : in    std_logic_vector(7 downto 0); -- DDR data stream from ADC (direct I/O connection)
  ADC_DATA7_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (7)
  ADC_DATA6_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (6)
  ADC_DATA5_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (5)
  ADC_DATA4_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (4)
  ADC_DATA3_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (3)
  ADC_DATA2_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (2)
  ADC_DATA1_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (1)
  ADC_DATA0_OUT   : out   std_logic_vector(9 downto 0); -- parallel ADC data stream (0)
  ADC_CE_OUT      : out   std_logic;                    -- ADC data valid signal, centered into valid data
  DEBUG_OUT       : out   std_logic_vector(15 downto 0)
);
end component;

component shower_adc_ch_in 
port( 
  DEL   : in  std_logic_vector(3 downto 0); -- not used, just for compatibility
  ECLK  : in  std_logic; -- "edge" clock, taken from AD9212 DCO
    SCLK  : in  std_logic;
  RST   : in  std_logic; -- not used yet
  DATA  : in  std_logic_vector(0 downto 0); -- input from one AD9212 data stream
  Q   : out std_logic_vector(1 downto 0)
);
end component;

component shower_adc_twochannels 
port(
  CLK_IN      : in    std_logic;                     -- DDR bit clock
  RESET_IN    : in    std_logic;
  CLOCK_IN    : in    std_logic_vector(1 downto 0);  -- word clock
  DATA_0_IN   : in    std_logic_vector(1 downto 0);  -- ADC channel one
  DATA_1_IN   : in    std_logic_vector(1 downto 0);  -- ADC channel two
  DATA_0_OUT  : out   std_logic_vector(9 downto 0);  -- demultiplexed ADC channel one
  DATA_1_OUT  : out   std_logic_vector(9 downto 0);  -- demultiplexed ADC channel two
  STORE_OUT   : out   std_logic;
  SWAP_OUT    : out   std_logic;
  CLOCK_OUT   : out   std_logic;
  DEBUG_OUT   : out   std_logic_vector(31 downto 0)
);
end component;

component program_ADC
	port (
	      RESET			: in std_logic;
        CLOCK			: in std_logic;
        START_IN		      : in std_logic;
        ADC_READY_OUT		  : out std_logic;
        CSB_OUT		      	: out std_logic;
        SDIO_INOUT	     	: inout std_logic;
        SCLK_OUT 	       	: out std_logic;
        ADC_SELECT_IN	  	: in std_logic;
        MEMORY_ADDRESS_IN	: in std_logic_vector(7 downto 0);
        DATA_IN		        : in std_logic_vector(31 downto 0);
	      DATA_OUT	      	: out std_logic_vector(31 downto 0)
        );
end component;

  component spyFifo is
    port (
        Data            : in  std_logic_vector(31 downto 0);
        WrClock         : in  std_logic;
        RdClock         : in  std_logic;
        WrEn            : in  std_logic;
        RdEn            : in  std_logic;
        Reset           : in  std_logic;
        RPReset         : in  std_logic;
        Q               : out  std_logic_vector(31 downto 0);
        Empty           : out  std_logic;
        Full            : out  std_logic;
        AlmostEmpty	: out std_logic;
        AlmostFull	: out std_logic);
  end component;

  component edge_to_pulse
    port (
      clock     : in  std_logic;
      en_clk    : in  std_logic;
      signal_in : in  std_logic;
      pulse     : out std_logic);
  end component;


end shower_components;

