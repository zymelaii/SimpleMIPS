`include "..\cpu_defs.svh"

module wb_stage (
    input  clk,
    input  reset,
    // pipeline control
    output ws_allowin,
    // from MEM
    input  ms_to_ws_bus_t   ms_to_ws_bus,
    // forward bus
    output ws_forward_bus_t ws_forward_bus,
    // to regfile
    output ws_to_rf_bus_t   ws_to_rf_bus,
    // to c0
    output ws_to_c0_bus_t   ws_to_c0_bus,
    // WB_C0_Interface
    WB_C0_Interface         wb_c0_bus,
    // exception
    output pipeline_flush_t pipeline_flush,
    // tlb
    output virt_t           tlb_pc,
    // trace dubug interface
    output virt_t           debug_wb_pc,
    output logic [3:0]      debug_wb_rf_wen,
    output reg_addr_t       debug_wb_rf_wnum,
    output uint32_t         debug_wb_rf_wdata
);

// WB
logic ws_valid;
logic ws_ready_go;

// from MEM
ms_to_ws_bus_t ms_to_ws_bus_r;

// forward
logic    op_mfc0;
logic    op_tlb;
uint32_t final_result;

// cp0 and exception
logic eret_flush;
logic ex_en;

// WB stage
assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if(eret_flush | ex_en) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_bus.valid;
    end

    if (ms_to_ws_bus.valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

// to regfile
assign ws_to_rf_bus.we    = ms_to_ws_bus_r.rf_we & {4{ws_valid & ~ex_en}};
assign ws_to_rf_bus.waddr = ms_to_ws_bus_r.dest;
assign ws_to_rf_bus.wdata = final_result;

// forward bus
assign op_mfc0 = ms_to_ws_bus_r.c0_op[2] & ws_valid;
assign op_tlb  = (ms_to_ws_bus_r.tlb_op[`TLBOP_TLBWI]| 
                  ms_to_ws_bus_r.tlb_op[`TLBOP_TLBP] |
                  ms_to_ws_bus_r.tlb_op[`TLBOP_TLBR] ) & ws_valid;
assign final_result = op_mfc0 ? wb_c0_bus.rdata : ms_to_ws_bus_r.result;
assign ws_forward_bus = {op_mfc0,
                         op_tlb,
                         ms_to_ws_bus_r.rf_we,
                         ms_to_ws_bus_r.dest & {5{ws_valid}},
                         final_result
                         };

// cp0 and exception
exception_control u_exception_control (
    .ws_valid   (ws_valid               ),

    .c0_op      (ms_to_ws_bus_r.c0_op   ),
    .ws_c0_addr (ms_to_ws_bus_r.c0_addr ),
    .ws_result  (ms_to_ws_bus_r.result  ),
    // cp0 interface
    .c0_we      (wb_c0_bus.we           ),
    .c0_addr    (wb_c0_bus.addr         ),
    .c0_wdata   (wb_c0_bus.wdata        ),
    .c0_rdata   (wb_c0_bus.rdata        ),
    // exception
    .eret_flush (eret_flush             ),
    .ex_en      (ex_en                  ),
    // to cp0
    .ws_pc          (ms_to_ws_bus_r.pc          ),
    .ws_exception   (ms_to_ws_bus_r.exception   ),
    .c0_eret_flush  (ws_to_c0_bus.eret_flush    ),
    .c0_exception   (ws_to_c0_bus.exception     ),
    .c0_pc          (ws_to_c0_bus.pc            )
);

assign tlb_pc = ms_to_ws_bus_r.pc;

// tlb
assign ws_to_c0_bus.tlb_op = ws_valid ? ms_to_ws_bus_r.tlb_op : 3'b0;

assign pipeline_flush = {ex_en, eret_flush, op_tlb, ms_to_ws_bus_r.exception.tlb_refill};

// trace debug interface
assign debug_wb_pc       = ms_to_ws_bus_r.pc;
assign debug_wb_rf_wen   = ms_to_ws_bus_r.rf_we & {4{ws_valid & ~ex_en}};
assign debug_wb_rf_wnum  = ms_to_ws_bus_r.dest;
assign debug_wb_rf_wdata = (ms_to_ws_bus_r.exception.exccode == `EXCCODE_ADEL 
                        ||  ms_to_ws_bus_r.exception.exccode == `EXCCODE_ADES) ? ms_to_ws_bus_r.exception.badvaddr    :
                                                                                 final_result;

endmodule
