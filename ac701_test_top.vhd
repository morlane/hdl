--------------------------------------------------------------------------------
-- File    : ac701_test_top.vhd
-- Target  : Xilinx AC701 / Artix-7
-- Purpose : Top-level wrapper for mb_base_wrapper with PL AXI-lite register module
-- Notes   :
--   1. mb_base_wrapper is the Vivado block-design wrapper generated from mb_base.bd.
--   2. ac701_axi_reg_if is the user PL-side AXI-lite register/interface module.
--      Replace this component name/ports with the final proven module name if needed.
--   3. Reset convention here assumes reset is active-high into mb_base_wrapper.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity ac701_test_top is
  port (
    --------------------------------------------------------------------------
    -- AC701 board-level ports
    --------------------------------------------------------------------------
    SYSCLK_P      : in  std_logic;
    SYSCLK_N      : in  std_logic;
    RESET         : in  std_logic;

    UART_RXD      : in  std_logic;
    UART_TXD      : out std_logic

--    GPIO_IN       : in  std_logic_vector(31 downto 0);
--    GPIO_OUT      : out std_logic_vector(31 downto 0);

--    PWM_OUT       : out std_logic;
--    PL_INTR_IN    : in  std_logic
  );
end entity ac701_test_top;

architecture rtl of ac701_test_top is

  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------
  constant C_AXI_ADDR_WIDTH : integer := 32;
  constant C_AXI_DATA_WIDTH : integer := 32;
  constant C_AXI_STRB_WIDTH : integer := C_AXI_DATA_WIDTH / 8;

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------
  component mb_base_wrapper is
    port (
      MB_AXI_ACLK          : out std_logic;
      MB_AXI_ARESETN0      : out std_logic_vector(0 to 0);

      MB_AXI_REG_araddr    : out std_logic_vector(31 downto 0);
      MB_AXI_REG_arprot    : out std_logic_vector(2 downto 0);
      MB_AXI_REG_arready   : in  std_logic_vector(0 to 0);
      MB_AXI_REG_arvalid   : out std_logic_vector(0 to 0);

      MB_AXI_REG_awaddr    : out std_logic_vector(31 downto 0);
      MB_AXI_REG_awprot    : out std_logic_vector(2 downto 0);
      MB_AXI_REG_awready   : in  std_logic_vector(0 to 0);
      MB_AXI_REG_awvalid   : out std_logic_vector(0 to 0);

      MB_AXI_REG_bready    : out std_logic_vector(0 to 0);
      MB_AXI_REG_bresp     : in  std_logic_vector(1 downto 0);
      MB_AXI_REG_bvalid    : in  std_logic_vector(0 to 0);

      MB_AXI_REG_rdata     : in  std_logic_vector(31 downto 0);
      MB_AXI_REG_rready    : out std_logic_vector(0 to 0);
      MB_AXI_REG_rresp     : in  std_logic_vector(1 downto 0);
      MB_AXI_REG_rvalid    : in  std_logic_vector(0 to 0);

      MB_AXI_REG_wdata     : out std_logic_vector(31 downto 0);
      MB_AXI_REG_wready    : in  std_logic_vector(0 to 0);
      MB_AXI_REG_wstrb     : out std_logic_vector(3 downto 0);
      MB_AXI_REG_wvalid    : out std_logic_vector(0 to 0);

      MB_GPIO_IN           : in  std_logic_vector(31 downto 0);
      MB_GPIO_OUT          : out std_logic_vector(31 downto 0);
      MB_PWM               : out std_logic;

      MB_UART_rxd          : in  std_logic;
      MB_UART_txd          : out std_logic;

      PL_INTR              : in  std_logic_vector(0 to 0);

      clk_in               : in  std_logic;
      reset                : in  std_logic
    );
  end component;

  -- PL-side AXI-lite register/interface module.
  -- Replace this component declaration if the final module has a different name.
  component ac701_axi_reg_if is
    generic (
      C_S_AXI_ADDR_WIDTH : integer := C_AXI_ADDR_WIDTH;
      C_S_AXI_DATA_WIDTH : integer := C_AXI_DATA_WIDTH
    );
    port (
      s_axi_aclk     : in  std_logic;
      s_axi_aresetn  : in  std_logic;

      s_axi_awaddr   : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
      s_axi_awprot   : in  std_logic_vector(2 downto 0);
      s_axi_awvalid  : in  std_logic;
      s_axi_awready  : out std_logic;

      s_axi_wdata    : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
      s_axi_wstrb    : in  std_logic_vector(C_AXI_STRB_WIDTH-1 downto 0);
      s_axi_wvalid   : in  std_logic;
      s_axi_wready   : out std_logic;

      s_axi_bresp    : out std_logic_vector(1 downto 0);
      s_axi_bvalid   : out std_logic;
      s_axi_bready   : in  std_logic;

      s_axi_araddr   : in  std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
      s_axi_arprot   : in  std_logic_vector(2 downto 0);
      s_axi_arvalid  : in  std_logic;
      s_axi_arready  : out std_logic;

      s_axi_rdata    : out std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
      s_axi_rresp    : out std_logic_vector(1 downto 0);
      s_axi_rvalid   : out std_logic;
      s_axi_rready   : in  std_logic;

      gpio_in        : in  std_logic_vector(31 downto 0);
      gpio_out       : out std_logic_vector(31 downto 0);
      pwm_out        : out std_logic;
      intr_in        : in  std_logic
    );
  end component;

  ------------------------------------------------------------------------------
  -- Signals
  ------------------------------------------------------------------------------
  signal sysclk_ibuf        : std_logic;

  signal mb_axi_aclk        : std_logic;
  signal mb_axi_aresetn_v   : std_logic_vector(0 to 0);
  signal mb_axi_aresetn     : std_logic;

  signal mb_axi_araddr      : std_logic_vector(31 downto 0);
  signal mb_axi_arprot      : std_logic_vector(2 downto 0);
  signal mb_axi_arready_v   : std_logic_vector(0 to 0);
  signal mb_axi_arready     : std_logic;
  signal mb_axi_arvalid_v   : std_logic_vector(0 to 0);
  signal mb_axi_arvalid     : std_logic;

  signal mb_axi_awaddr      : std_logic_vector(31 downto 0);
  signal mb_axi_awprot      : std_logic_vector(2 downto 0);
  signal mb_axi_awready_v   : std_logic_vector(0 to 0);
  signal mb_axi_awready     : std_logic;
  signal mb_axi_awvalid_v   : std_logic_vector(0 to 0);
  signal mb_axi_awvalid     : std_logic;

  signal mb_axi_bready_v    : std_logic_vector(0 to 0);
  signal mb_axi_bready      : std_logic;
  signal mb_axi_bresp       : std_logic_vector(1 downto 0);
  signal mb_axi_bvalid_v    : std_logic_vector(0 to 0);
  signal mb_axi_bvalid      : std_logic;

  signal mb_axi_rdata       : std_logic_vector(31 downto 0);
  signal mb_axi_rready_v    : std_logic_vector(0 to 0);
  signal mb_axi_rready      : std_logic;
  signal mb_axi_rresp       : std_logic_vector(1 downto 0);
  signal mb_axi_rvalid_v    : std_logic_vector(0 to 0);
  signal mb_axi_rvalid      : std_logic;

  signal mb_axi_wdata       : std_logic_vector(31 downto 0);
  signal mb_axi_wready_v    : std_logic_vector(0 to 0);
  signal mb_axi_wready      : std_logic;
  signal mb_axi_wstrb       : std_logic_vector(3 downto 0);
  signal mb_axi_wvalid_v    : std_logic_vector(0 to 0);
  signal mb_axi_wvalid      : std_logic;

  signal mb_gpio_in         : std_logic_vector(31 downto 0);
  signal mb_gpio_out        : std_logic_vector(31 downto 0);
  signal mb_pwm             : std_logic;
  signal pl_intr_v          : std_logic_vector(0 to 0);

begin

  ------------------------------------------------------------------------------
  -- AC701 differential system clock input
  ------------------------------------------------------------------------------
  u_sysclk_ibufds : IBUFDS
    generic map (
      DIFF_TERM    => true,
      IBUF_LOW_PWR => false
    )
    port map (
      I  => SYSCLK_P,
      IB => SYSCLK_N,
      O  => sysclk_ibuf
    );

  ------------------------------------------------------------------------------
  -- Board-level signal tie-ins
  ------------------------------------------------------------------------------
 -- mb_gpio_in      <= GPIO_IN;
  --GPIO_OUT        <= mb_gpio_out;
 -- PWM_OUT         <= mb_pwm;
  --pl_intr_v(0)    <= PL_INTR_IN;

  ------------------------------------------------------------------------------
  -- Convert single-bit std_logic_vector ports from BD wrapper to scalar AXI-lite
  ------------------------------------------------------------------------------
  mb_axi_aresetn       <= mb_axi_aresetn_v(0);

  mb_axi_awvalid       <= mb_axi_awvalid_v(0);
  mb_axi_awready_v(0)  <= mb_axi_awready;

  mb_axi_wvalid        <= mb_axi_wvalid_v(0);
  mb_axi_wready_v(0)   <= mb_axi_wready;

  mb_axi_bready        <= mb_axi_bready_v(0);
  mb_axi_bvalid_v(0)   <= mb_axi_bvalid;

  mb_axi_arvalid       <= mb_axi_arvalid_v(0);
  mb_axi_arready_v(0)  <= mb_axi_arready;

  mb_axi_rready        <= mb_axi_rready_v(0);
  mb_axi_rvalid_v(0)   <= mb_axi_rvalid;

  ------------------------------------------------------------------------------
  -- MicroBlaze block-design wrapper
  ------------------------------------------------------------------------------
  u_mb_base_wrapper : mb_base_wrapper
    port map (
      MB_AXI_ACLK          => mb_axi_aclk,
      MB_AXI_ARESETN0      => mb_axi_aresetn_v,

      MB_AXI_REG_araddr    => mb_axi_araddr,
      MB_AXI_REG_arprot    => mb_axi_arprot,
      MB_AXI_REG_arready   => mb_axi_arready_v,
      MB_AXI_REG_arvalid   => mb_axi_arvalid_v,

      MB_AXI_REG_awaddr    => mb_axi_awaddr,
      MB_AXI_REG_awprot    => mb_axi_awprot,
      MB_AXI_REG_awready   => mb_axi_awready_v,
      MB_AXI_REG_awvalid   => mb_axi_awvalid_v,

      MB_AXI_REG_bready    => mb_axi_bready_v,
      MB_AXI_REG_bresp     => mb_axi_bresp,
      MB_AXI_REG_bvalid    => mb_axi_bvalid_v,

      MB_AXI_REG_rdata     => mb_axi_rdata,
      MB_AXI_REG_rready    => mb_axi_rready_v,
      MB_AXI_REG_rresp     => mb_axi_rresp,
      MB_AXI_REG_rvalid    => mb_axi_rvalid_v,

      MB_AXI_REG_wdata     => mb_axi_wdata,
      MB_AXI_REG_wready    => mb_axi_wready_v,
      MB_AXI_REG_wstrb     => mb_axi_wstrb,
      MB_AXI_REG_wvalid    => mb_axi_wvalid_v,

      MB_GPIO_IN           => mb_gpio_in,
      MB_GPIO_OUT          => mb_gpio_out,
      MB_PWM               => mb_pwm,

      MB_UART_rxd          => UART_RXD,
      MB_UART_txd          => UART_TXD,

      PL_INTR              => pl_intr_v,

      clk_in               => sysclk_ibuf,
      reset                => RESET
    );

  ------------------------------------------------------------------------------
  -- User PL AXI-lite register/interface module
  ------------------------------------------------------------------------------
  --u_ac701_axi_reg_if : ac701_axi_reg_if
    --generic map (
      --C_S_AXI_ADDR_WIDTH => C_AXI_ADDR_WIDTH,
      --C_S_AXI_DATA_WIDTH => C_AXI_DATA_WIDTH
    --)
    --port map (
      --s_axi_aclk     => mb_axi_aclk,
      --s_axi_aresetn  => mb_axi_aresetn,

      --s_axi_awaddr   => mb_axi_awaddr,
      --s_axi_awprot   => mb_axi_awprot,
      --s_axi_awvalid  => mb_axi_awvalid,
      --s_axi_awready  => mb_axi_awready,

      --s_axi_wdata    => mb_axi_wdata,
      --s_axi_wstrb    => mb_axi_wstrb,
      --s_axi_wvalid   => mb_axi_wvalid,
      --s_axi_wready   => mb_axi_wready,

      --s_axi_bresp    => mb_axi_bresp,
      --s_axi_bvalid   => mb_axi_bvalid,
      --s_axi_bready   => mb_axi_bready,

      --s_axi_araddr   => mb_axi_araddr,
      --s_axi_arprot   => mb_axi_arprot,
      --s_axi_arvalid  => mb_axi_arvalid,
      --s_axi_arready  => mb_axi_arready,

      --s_axi_rdata    => mb_axi_rdata,
      --s_axi_rresp    => mb_axi_rresp,
      --s_axi_rvalid   => mb_axi_rvalid,
      --s_axi_rready   => mb_axi_rready,

      --gpio_in        => mb_gpio_in,
      --gpio_out       => mb_gpio_out,
      --pwm_out        => mb_pwm,
      --intr_in        => PL_INTR_IN
    --);

end architecture rtl;
