`include "..\cpu_defs.svh"

module pre_mem_stage(
    input  clk  ,
    input  reset,
    // pipeline 
    input  ms_allowin ,
    output pms_allowin,
    // from EXE
    input  es_to_pms_bus_t   es_to_pms_bus,
    // to MEM
    output pms_to_ms_bus_t   pms_to_ms_bus,
    // forward bus
    output pms_forward_bus_t pms_forward_bus,
    // cp0 and exception
    input   wr_disable,
    output  pms_wr_disable,
    pipeline_flush_t    pipeline_flush,
    // data sram interface
    output logic        data_req,
    output logic        data_wr,
    output logic [1:0]  data_size,
    output logic [3:0]  data_wstrb,
    output virt_t       data_addr,
    output uint32_t     data_wdata,
    input  logic        data_addr_ok
);


// pre_MEM
logic   pms_valid;
logic   pms_ready_go;
logic   pms_to_ms_valid;

// from EXE
logic res_from_mem;
logic res_to_mem;
es_to_pms_bus_t es_to_pms_bus_r;
assign res_from_mem = es_to_pms_bus_r.res_from_mem;
assign res_to_mem   = es_to_pms_bus_r.res_to_mem;

// exception
logic       mem_ex;
logic [4:0] mem_exccode;
exception_t exception;

// data_sram interface
logic req;
logic req_ok;
assign req = pms_valid && ms_allowin && !wr_disable && !exception.ex
           && (res_from_mem || res_to_mem);

// pre_MEM stage
assign req_ok           = req && data_addr_ok;
assign pms_ready_go     = req_ok || !(res_from_mem || res_to_mem) || exception.ex;
assign pms_allowin      = !pms_valid || pms_ready_go && ms_allowin ;
assign pms_to_ms_valid  = pms_valid && pms_ready_go;
always_ff @(posedge clk) begin
    if(reset)
        pms_valid <= 1'b0;
    else if(pipeline_flush.eret | pipeline_flush.ex)
        pms_valid <= 1'b0;
    else if(pms_allowin)
        pms_valid <= es_to_pms_bus.valid;

    if(es_to_pms_bus.valid && pms_allowin)
        es_to_pms_bus_r <= es_to_pms_bus;
end

// mem_req
assign data_req = req;
mem_req u_mem_req (
    .res_from_mem   (es_to_pms_bus_r.res_from_mem),
    .load_op        (es_to_pms_bus_r.load_op     ),
    .res_to_mem     (es_to_pms_bus_r.res_to_mem  ),
    .store_op       (es_to_pms_bus_r.store_op    ),
    .mem_addr       (es_to_pms_bus_r.mem_addr    ),
    .mem_wdata      (es_to_pms_bus_r.result      ),
    // exception
    .mem_ex         (mem_ex     ),
    .mem_exccode    (mem_exccode),
    // data_sram interface
    .data_wr        (data_wr   ),
    .data_size      (data_size ),
    .data_wstrb     (data_wstrb),
    .data_addr      (data_addr ),
    .data_wdata     (data_wdata)
);

// exception
assign op_mfc0 = es_to_pms_bus_r.c0_op[2] & pms_valid;
assign pms_wr_disable = exception.ex;
assign exception.bd = es_to_pms_bus_r.exception.bd;
assign {exception.ex, exception.exccode} = es_to_pms_bus_r.exception.ex ? {es_to_pms_bus_r.exception.ex, es_to_pms_bus_r.exception.exccode} :
                                           mem_ex & pms_valid           ? {1'b1, mem_exccode                                            } :
                                                                          6'h0;
assign exception.badvaddr = es_to_pms_bus_r.exception.ex ? es_to_pms_bus_r.exception.badvaddr :
                            mem_ex & pms_valid           ? es_to_pms_bus_r.mem_addr           :
                                                           32'h0;

// forward bus
assign pms_forward_bus = {op_mfc0,
                          es_to_pms_bus_r.res_from_mem & pms_valid,
                          es_to_pms_bus_r.dest & {5{pms_valid}},
                          es_to_pms_bus_r.result
                        };

// to MEM
assign pms_to_ms_bus = {pms_to_ms_valid,
                        es_to_pms_bus_r.load_op,
                        es_to_pms_bus_r.c0_op,
                        es_to_pms_bus_r.c0_addr,
                        req_ok,
                        es_to_pms_bus_r.res_from_mem,
                        es_to_pms_bus_r.res_to_mem,
                        es_to_pms_bus_r.rf_we,
                        es_to_pms_bus_r.dest,
                        es_to_pms_bus_r.result,
                        es_to_pms_bus_r.pc,
                        exception
                        };

endmodule
