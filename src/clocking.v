// Edited by Hydronic1219
// Date: 2025-09-28
// Instance naming convention unified to u_<module>


`timescale 1ps/1ps

(* CORE_GENERATION_INFO = "clocking,clk_wiz_v5_4_2_0,{component_name=clocking,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,enable_axi=0,feedback_source=FDBK_AUTO,PRIMITIVE=MMCM,num_out_clk=2,clkin1_period=10.000,clkin2_period=10.000,use_power_down=false,use_reset=true,use_locked=true,use_inclk_stopped=false,feedback_type=SINGLE,CLOCK_MGR_TYPE=NA,manual_override=false}" *)

module clocking 
 (
  // Clock out ports
  output        CLK_50,
  output        CLK_25,
  // Status and control signals
  input         reset,
  output        locked,
 // Clock in ports
  input         CLK_100
 );

  clocking_clk_wiz u_clocking_clk_wiz
  (
  // Clock out ports  
  .CLK_50(CLK_50),
  .CLK_25(CLK_25),
  // Status and control signals               
  .reset(reset), 
  .locked(locked),
 // Clock in ports
  .CLK_100(CLK_100)
  );

endmodule
