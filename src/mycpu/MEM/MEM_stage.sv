`include "..\cpu_defs.svh"

module mem_stage (
    input clk,
    input reset,
    // pipeline control
    input  ws_allowin,
    output ms_allowin,
    // from pre_MEM
    input  pms_to_ms_bus_t  pms_to_ms_bus,
    // to WB
    output ms_to_ws_bus_t   ms_to_ws_bus,
    // forward bus
    output ms_forward_bus_t ms_forward_bus,
    // cp0 and exception
    output ms_wr_disable,
    input  pipeline_flush_t pipeline_flush,
    // from data sram
    input  logic    data_data_ok,
    input  uint32_t data_rdata
);

// MEM
logic ms_valid;
logic ms_ready_go;
logic ms_to_ws_valid;

logic    ms_data_valid;
uint32_t ms_data;

// from pre_MEM
logic res_from_mem;
logic res_to_mem;
pms_to_ms_bus_t pms_to_ms_bus_r;
assign res_from_mem = pms_to_ms_bus_r.res_from_mem & ms_valid;
assign res_to_mem   = pms_to_ms_bus_r.res_to_mem & ms_valid;

// mem_load
logic [3:0] rf_we;
uint32_t    mem_result;

// forward bus
logic op_mfc0;
logic op_tlb;

// exception
logic op_eret;
logic data_cancel;
exception_t exception;

// to WB
uint32_t final_result;

// MEM stage
assign ms_ready_go    = (data_data_ok || ms_data_valid) && !data_cancel || !(res_from_mem || res_to_mem) || exception.ex;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if(pipeline_flush.eret | pipeline_flush.ex)
        ms_valid <= 1'b0;
    else if (ms_allowin) begin
        ms_valid <= pms_to_ms_bus.valid;
    end

    if (pms_to_ms_bus.valid && ms_allowin) begin
        pms_to_ms_bus_r  <= pms_to_ms_bus;
    end

    if(reset || pipeline_flush.ex || pipeline_flush.eret)
        ms_data_valid <= 1'b0;
    else if(data_data_ok && !ws_allowin) begin
        ms_data_valid <= 1'b1;
        ms_data       <= data_rdata;
    end
    else if(ws_allowin && ms_ready_go)
        ms_data_valid <= 1'b0;
end

// mem_load
mem_load u_mem_load (
    .load_op    (pms_to_ms_bus_r.load_op ),
    .rf_wr      (pms_to_ms_bus_r.rf_we   ),
    .mem_addr   (pms_to_ms_bus_r.result  ),
    .data_sram_rdata    (data_rdata     ),

    .rf_we      (rf_we                  ),
    .mem_result (mem_result             )
);

// forward bus
assign op_mfc0 = pms_to_ms_bus_r.c0_op[2] & ms_to_ws_valid;
assign op_tlb  = (pms_to_ms_bus_r.tlb_op[0] | pms_to_ms_bus_r.tlb_op[1] | pms_to_ms_bus_r.tlb_op[2] ) & ms_to_ws_valid;
assign ms_forward_bus = { op_mfc0,
                          res_from_mem,
                          op_tlb,
                          rf_we,
                          pms_to_ms_bus_r.dest & {5{ms_to_ws_valid || res_from_mem || res_to_mem}},
                          final_result
                        };

// exception
assign exception = pms_to_ms_bus_r.exception;
assign op_eret   = pms_to_ms_bus_r.c0_op[0];
assign ms_wr_disable = (op_eret | exception.ex) & ms_valid;
always_ff @(posedge clk) begin
    if(reset)
        data_cancel <= 1'b0;
    else if((pipeline_flush.eret || pipeline_flush.ex) && (pms_to_ms_bus.req_ok || !ms_ready_go && (res_from_mem || res_to_mem)))
        data_cancel <= 1'b1;
    else if(data_data_ok)
        data_cancel <= 1'b0;
end

// to WB
assign final_result = pms_to_ms_bus_r.res_from_mem ? mem_result : pms_to_ms_bus_r.result;
assign ms_to_ws_bus = { ms_to_ws_valid,
                        pms_to_ms_bus_r.c0_op,
                        pms_to_ms_bus_r.c0_addr,
                        rf_we,
                        pms_to_ms_bus_r.dest,
                        final_result,
                        pms_to_ms_bus_r.pc,
                        exception,
                        pms_to_ms_bus_r.tlb_op};

endmodule
