`include "..\cpu_defs.svh"

module mem_stage (
    input clk,
    input reset,
    // pipeline control
    input  ws_allowin,
    output ms_allowin,
    // from EXE
    input  es_to_ms_bus_t   es_to_ms_bus,
    // to WB
    output ms_to_ws_bus_t   ms_to_ws_bus,
    // forward bus
    output ms_forward_bus_t ms_forward_bus,
    // cp0 and exception
    output ms_wr_disable,
    input  pipeline_flush_t pipeline_flush,
    // from data sram
    input  uint32_t data_sram_rdata
);

// MEM
logic ms_valid;
logic ms_ready_go;
logic ms_to_ws_valid;

// from EXE
es_to_ms_bus_t es_to_ms_bus_r;

// mem_load
logic [3:0] rf_we;
uint32_t    mem_result;

// forward bus
logic op_mfc0;

// exception
logic op_eret;
exception_t exception;

// to WB
uint32_t final_result;

// MEM stage
assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if(pipeline_flush.eret | pipeline_flush.ex)
        ms_valid <= 1'b0;
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_bus.valid;
    end

    if (es_to_ms_bus.valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end

// mem_load
mem_load u_mem_load (
    .load_op    (es_to_ms_bus_r.load_op ),
    .rf_wr      (es_to_ms_bus_r.rf_we   ),
    .mem_addr   (es_to_ms_bus_r.result  ),
    .data_sram_rdata    (data_sram_rdata),

    .rf_we      (rf_we                  ),
    .mem_result (mem_result             )
);

// forward bus
assign op_mfc0 = es_to_ms_bus_r.c0_op[2] & ms_valid;
assign ms_forward_bus = { op_mfc0,
                          rf_we,
                          es_to_ms_bus_r.dest & {5{ms_valid}},
                          final_result
                        };

// exception
assign exception = es_to_ms_bus_r.exception;
assign op_eret = es_to_ms_bus_r.c0_op[0];
assign ms_wr_disable = op_eret | exception.ex;

// to WB
assign final_result = es_to_ms_bus_r.res_from_mem ? mem_result : es_to_ms_bus_r.result;
assign ms_to_ws_bus = { ms_to_ws_valid,
                        es_to_ms_bus_r.c0_op,
                        es_to_ms_bus_r.c0_addr,
                        rf_we,
                        es_to_ms_bus_r.dest,
                        final_result,
                        es_to_ms_bus_r.pc,
                        exception};

endmodule
