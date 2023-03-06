`include "cpu_defs.svh"

module cpu_core(
    input logic clk,
    input logic resetn,
    //ex
    input logic [5:0] ext_int,
    //inst sram interface
    output logic        inst_sram_en,
    output logic [ 3:0] inst_sram_wen,
    output logic [31:0] inst_sram_addr,
    output logic [31:0] inst_sram_wdata,
    input  logic [31:0] inst_sram_rdata,
    // data sram interface
    output logic        data_sram_en,
    output logic [ 3:0] data_sram_wen,
    output logic [31:0] data_sram_addr,
    output logic [31:0] data_sram_wdata,
    input  logic [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg reset;
always @(posedge clk) reset <= ~resetn;

// pipeline control
logic ds_allowin, es_allowin, ms_allowin, ws_allowin;
// branch
br_bus_t br_bus;
// pipelien bus
fs_to_ds_bus_t fs_to_ds_bus;
ds_to_es_bus_t ds_to_es_bus;
es_to_ms_bus_t es_to_ms_bus;
ms_to_ws_bus_t ms_to_ws_bus;
ws_to_rf_bus_t ws_to_rf_bus;
ws_to_c0_bus_t ws_to_c0_bus;
// forward bus
es_forward_bus_t es_forward_bus;
ms_forward_bus_t ms_forward_bus;
ws_forward_bus_t ws_forward_bus;

// interface
WB_C0_Interface WB_C0_Bus();

// cp0 and ex
logic [ 5:0]     c0_hw;
logic [ 1:0]     c0_sw;
virt_t           c0_epc;
pipeline_flush_t pipeline_flush;
logic            ms_wr_disable;
logic            wr_disable;
assign wr_disable = ms_wr_disable | pipeline_flush.eret | pipeline_flush.ex;

// IF stage
if_stage u_if_stage (
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .ds_allowin     (ds_allowin     ),
    // branch control
    .br_bus         (br_bus         ),
    // to ID
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // cp0 and exception
    .pipeline_flush (pipeline_flush ),
    .c0_epc         (c0_epc         ),
    // inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_wen  (inst_sram_wen  ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
);

// ID stage
id_stage u_idstage (
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    // from IF
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // from WB to regfile
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    // forward bus
    .es_forward_bus (es_forward_bus ),
    .ms_forward_bus (ms_forward_bus ),
    .ws_forward_bus (ws_forward_bus ),
    // to EXE
    .ds_to_es_bus   (ds_to_es_bus   ),
    // br bus
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
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    // from ID
    .ds_to_es_bus   (ds_to_es_bus   ),
    // to MEM
    .es_to_ms_bus   (es_to_ms_bus   ),
    // forward bus
    .es_forward_bus (es_forward_bus ),
    // cp0 and exception
    .wr_disable     (wr_disable     ),
    .pipeline_flush (pipeline_flush ),
    // data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_wen  (data_sram_wen  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata)
);

// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    // pipeline control
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from EXE
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to WB
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    // forward bus
    .ms_forward_bus (ms_forward_bus ),
    // cp0 and exception
    .ms_wr_disable  (ms_wr_disable  ),
    .pipeline_flush (pipeline_flush ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata)
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