`include "cpu_defs.svh"

module cpu_core(
    input logic clk,
    input logic resetn,
    // ex
    input logic [5:0] ext_int,
    // axi
    //ar
    output [3 :0]   arid   ,
    output virt_t   araddr ,
    output [7 :0]   arlen  ,
    output [2 :0]   arsize ,
    output [1 :0]   arburst,
    output [1 :0]   arlock ,
    output [3 :0]   arcache,
    output [2 :0]   arprot ,
    output          arvalid,
    input           arready,
    //r     
    input  [3 :0]   rid    ,
    input  uint32_t rdata  ,
    input  [1 :0]   rresp  ,
    input           rlast  ,
    input           rvalid ,
    output          rready ,
    //aw    
    output [3 :0]   awid   ,
    output virt_t   awaddr ,
    output [7 :0]   awlen  ,
    output [2 :0]   awsize ,
    output [1 :0]   awburst,
    output [1 :0]   awlock ,
    output [3 :0]   awcache,
    output [2 :0]   awprot ,
    output          awvalid,
    input           awready,
    //w    
    output [3 :0]   wid    ,
    output uint32_t wdata  ,
    output [3 :0]   wstrb  ,
    output          wlast  ,
    output          wvalid ,
    input           wready ,
    //b     
    input  [3 :0]   bid    ,
    input  [1 :0]   bresp  ,
    input           bvalid ,
    output          bready ,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg reset;
always @(posedge clk) reset <= ~resetn;

// pipeline control
logic fs_allowin, ds_allowin, es_allowin, pms_allowin, ms_allowin, ws_allowin;
// branch
logic    pfs_db;
virt_t   pfs_pc;
logic    fs_valid;
logic    br_bus_en;
br_bus_t br_bus;
// pipeline bus
pfs_to_fs_bus_t pfs_to_fs_bus;
fs_to_ds_bus_t  fs_to_ds_bus;
ds_to_es_bus_t  ds_to_es_bus;
es_to_pms_bus_t es_to_pms_bus;
pms_to_ms_bus_t pms_to_ms_bus;
ms_to_ws_bus_t  ms_to_ws_bus;
ws_to_rf_bus_t  ws_to_rf_bus;
ws_to_c0_bus_t  ws_to_c0_bus;
// forward bus
es_forward_bus_t  es_forward_bus;
pms_forward_bus_t pms_forward_bus;
ms_forward_bus_t  ms_forward_bus;
ws_forward_bus_t  ws_forward_bus;

// interface
WB_C0_Interface WB_C0_Bus();

// cp0 and ex
logic [ 5:0]     c0_hw;
logic [ 1:0]     c0_sw;
virt_t           c0_epc;
pipeline_flush_t pipeline_flush;
logic            pms_wr_disable;
logic            ms_wr_disable;
logic            wr_disable;
assign wr_disable = ms_wr_disable | pipeline_flush.eret | pipeline_flush.ex;

// cpu axi interface

// inst sram interface
logic        inst_sram_req    ;
logic        inst_sram_wr     ;
logic [1:0]  inst_sram_size   ;
logic [3:0]  inst_sram_wstrb  ;
virt_t       inst_sram_addr   ;
uint32_t     inst_sram_wdata  ;
logic        inst_sram_addr_ok;
logic        inst_sram_data_ok;
uint32_t     inst_sram_rdata  ;
// data sram interface
logic        data_sram_req    ;
logic        data_sram_wr     ;
logic [1:0]  data_sram_size   ;
logic [3:0]  data_sram_wstrb  ;
virt_t       data_sram_addr   ;
uint32_t     data_sram_wdata  ;
logic        data_sram_addr_ok;
logic        data_sram_data_ok;
uint32_t     data_sram_rdata  ;

cpu_axi_interface u_cpu_axi_interface(
    .clk            (clk            ),
    .resetn         (resetn         ),
    // inst_sram
    .inst_req       (inst_sram_req    ),
    .inst_wr        (inst_sram_wr     ),
    .inst_size      (inst_sram_size   ),
    .inst_wstrb     (inst_sram_wstrb  ),
    .inst_addr      (inst_sram_addr   ),
    .inst_wdata     (inst_sram_wdata  ),
    .inst_addr_ok   (inst_sram_addr_ok),
    .inst_data_ok   (inst_sram_data_ok),
    .inst_rdata     (inst_sram_rdata  ),
    // data_sram
    .data_req       (data_sram_req    ),
    .data_wr        (data_sram_wr     ),
    .data_size      (data_sram_size   ),
    .data_wstrb     (data_sram_wstrb  ),
    .data_addr      (data_sram_addr   ),
    .data_wdata     (data_sram_wdata  ),
    .data_addr_ok   (data_sram_addr_ok),
    .data_data_ok   (data_sram_data_ok),
    .data_rdata     (data_sram_rdata  ),
    // axi
    // ar
    .arid           (arid             ),
    .araddr         (araddr           ),
    .arlen          (arlen            ),
    .arsize         (arsize           ),
    .arburst        (arburst          ),
    .arlock         (arlock           ),
    .arcache        (arcache          ),
    .arprot         (arprot           ),
    .arvalid        (arvalid          ),
    .arready        (arready          ),
    // r                
    .rid            (rid              ),
    .rdata          (rdata            ),
    .rresp          (rresp            ),
    .rlast          (rlast            ),
    .rvalid         (rvalid           ),
    .rready         (rready           ),
    // aw                  
    .awid           (awid             ),
    .awaddr         (awaddr           ),
    .awlen          (awlen            ),
    .awsize         (awsize           ),
    .awburst        (awburst          ),
    .awlock         (awlock           ),
    .awcache        (awcache          ),
    .awprot         (awprot           ),
    .awvalid        (awvalid          ),
    .awready        (awready          ),
    // w
    .wid            (wid              ),
    .wdata          (wdata            ),
    .wstrb          (wstrb            ),
    .wlast          (wlast            ),
    .wvalid         (wvalid           ),
    .wready         (wready           ),
    // b   
    .bid            (bid              ),
    .bresp          (bresp            ),
    .bvalid         (bvalid           ),
    .bready         (bready           )
);

// pre_IF stage
pre_if_stage u_pre_if_stage (
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .fs_allowin     (fs_allowin     ),
    // from IF
    .fs_valid       (fs_valid       ),
    // br_bus
    .br_bus_en      (br_bus_en      ),
    .br_bus         (br_bus         ),
    // to IF
    .pfs_to_fs_bus  (pfs_to_fs_bus  ),
    // to ID
    .pfs_bd         (pfs_bd         ),
    .pfs_pc         (pfs_pc         ),
    // cp0 and exception
    .pipeline_flush (pipeline_flush ),
    .c0_epc         (c0_epc         ),
    // inst_sram interface
    .inst_req       (inst_sram_req    ),
    .inst_wr        (inst_sram_wr     ),
    .inst_size      (inst_sram_size   ),
    .inst_wstrb     (inst_sram_wstrb  ),
    .inst_addr      (inst_sram_addr   ),
    .inst_wdata     (inst_sram_wdata  ),
    .inst_addr_ok   (inst_sram_addr_ok)
);

// IF stage
if_stage u_if_stage (
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .ds_allowin     (ds_allowin     ),
    .fs_allowin     (fs_allowin     ),
    // from IF
    .pfs_to_fs_bus  (pfs_to_fs_bus  ),
    // to IF
    .fs_to_pfs_valid(fs_valid       ),
    // to ID
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // cp0 and exception
    .pipeline_flush (pipeline_flush ),
    .c0_epc         (c0_epc         ),
    // inst sram interface
    .inst_data_ok   (inst_sram_data_ok),
    .inst_rdata     (inst_sram_rdata  )
);

// ID stage
id_stage u_idstage (
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    // from pre_IF
    .pfs_bd         (pfs_bd         ),
    .pfs_pc         (pfs_pc         ),
    // from IF
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // from WB to regfile
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    // forward bus
    .es_forward_bus (es_forward_bus ),
    .pms_forward_bus(pms_forward_bus),
    .ms_forward_bus (ms_forward_bus ),
    .ws_forward_bus (ws_forward_bus ),
    // to EXE
    .ds_to_es_bus   (ds_to_es_bus   ),
    // br bus
    .br_bus_en      (br_bus_en      ),
    .br_bus         (br_bus         ),
    // cp0 and exception
    .c0_hw          (c0_hw          ),
    .c0_sw          (c0_sw          ),
    .pipeline_flush (pipeline_flush )
);

// EXE stage
exe_stage u_exe_stage (
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .pms_allowin    (pms_allowin    ),
    .es_allowin     (es_allowin     ),
    // from ID
    .ds_to_es_bus   (ds_to_es_bus   ),
    // to pre_MEM
    .es_to_pms_bus  (es_to_pms_bus  ),
    // forward bus
    .es_forward_bus (es_forward_bus ),
    // cp0 and exception
    .pms_wr_disable (pms_wr_disable ),
    .wr_disable     (wr_disable     ),
    .pipeline_flush (pipeline_flush )
);

// pre_MEM stage
pre_mem_stage u_pre_mem_stage (
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline
    .ms_allowin     (ms_allowin     ),
    .pms_allowin    (pms_allowin    ),
    // from EXE
    .es_to_pms_bus  (es_to_pms_bus  ),
    // to MEM
    .pms_to_ms_bus  (pms_to_ms_bus  ),
    // forward bus
    .pms_forward_bus(pms_forward_bus),
    // cp0 and exception
    .wr_disable     (wr_disable     ),
    .pms_wr_disable (pms_wr_disable ),
    .pipeline_flush (pipeline_flush ),
    // data_sram interface
    .data_req       (data_sram_req    ),
    .data_wr        (data_sram_wr     ),
    .data_size      (data_sram_size   ),
    .data_wstrb     (data_sram_wstrb  ),
    .data_addr      (data_sram_addr   ),
    .data_wdata     (data_sram_wdata  ),
    .data_addr_ok   (data_sram_addr_ok)
);

// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from pre_MEM
    .pms_to_ms_bus  (pms_to_ms_bus   ),
    //to WB
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // forward bus
    .ms_forward_bus (ms_forward_bus ),
    // cp0 and exception
    .ms_wr_disable  (ms_wr_disable  ),
    .pipeline_flush (pipeline_flush ),
    //from data-sram
    .data_data_ok   (data_sram_data_ok),
    .data_rdata     (data_sram_rdata  )
);

// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // allowin
    .ws_allowin     (ws_allowin     ),
    // from MEM
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // forward
    .ws_forward_bus (ws_forward_bus ),
    // to regfile
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    // to c0
    .ws_to_c0_bus   (ws_to_c0_bus   ),
    // WB_C0_Interface
    .wb_c0_bus      (WB_C0_Bus.WB   ),
    // exception
    .pipeline_flush (pipeline_flush ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

// CP0
reg_cp0 u_reg_cp0(
    .clk            (clk            ),
    .reset          (reset          ),
    // from WB
    .ws_to_c0_bus   (ws_to_c0_bus   ),
    // interface
    .c0_wb_bus      (WB_C0_Bus.C0   ),
    // interrupt
    .ext_int_in     (ext_int        ),
    .c0_hw          (c0_hw          ),
    .c0_sw          (c0_sw          ),
    // EPC
    .epc            (c0_epc         )
);

endmodule