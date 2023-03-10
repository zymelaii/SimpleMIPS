`include "..\cpu_defs.svh"

module exe_stage (
    input clk,
    input reset,
    // pipeline control
    input  pms_allowin,
    output es_allowin,
    // from ID
    input   ds_to_es_bus_t   ds_to_es_bus,
    //to MEM
    output  es_to_pms_bus_t  es_to_pms_bus,
    // forward bus
    input  pms_wr_disable,
    input  wr_disable,
    output  es_forward_bus_t es_forward_bus,
    // cp0 and exception
    input pipeline_flush_t pipeline_flush
);

// EXE
logic es_valid;
logic es_ready_go;
logic es_to_pms_valid;

// from ID
ds_to_es_bus_t ds_to_es_bus_r;

// alu
uint32_t alu_result;
logic    alu_ex;

// hi_lo reg
logic    hi_lo_ready;
uint32_t hi_lo_result;

// forward
logic op_mfc0;

// cp0 and exception
exception_t exception;

// to MEM
logic    op_mtc0;
logic    res_from_hi_lo;
logic    res_from_alu;
uint32_t final_result;

// EXE stage
assign es_ready_go    = es_valid && (res_from_hi_lo && hi_lo_ready || !res_from_hi_lo);
assign es_allowin     = !es_valid || es_ready_go && pms_allowin;
assign es_to_pms_valid =  es_valid && es_ready_go;
always_ff @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if(pipeline_flush.eret | pipeline_flush.ex) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_bus.valid;
    end

    if (ds_to_es_bus.valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

// alu
alu u_alu (
    .alu_op         (ds_to_es_bus_r.alu_op      ),

    .src1_is_sa     (ds_to_es_bus_r.src1_is_sa  ),
    .src1_is_pc     (ds_to_es_bus_r.src1_is_pc  ),
    .src2_is_simm   (ds_to_es_bus_r.src2_is_simm),
    .src2_is_zimm   (ds_to_es_bus_r.src2_is_zimm),
    .src2_is_8      (ds_to_es_bus_r.src2_is_8   ),
    .rs_value       (ds_to_es_bus_r.rs_value    ),
    .rt_value       (ds_to_es_bus_r.rt_value    ),
    .pc             (ds_to_es_bus_r.pc          ),
    .imm            (ds_to_es_bus_r.imm         ),

    .alu_result     (alu_result                 ),

    .alu_ov         (ds_to_es_bus_r.alu_ov      ),
    .alu_ex         (alu_ex                     )
);

// hi_lo
reg_hi_lo u_reg_hi_lo(
    .clk    (clk  ),
    .reset  (reset),

    .hi_lo_op    (ds_to_es_bus_r.hi_lo_op),
    .src1        (ds_to_es_bus_r.rs_value),
    .src2        (ds_to_es_bus_r.rt_value),

    .hi_lo_ready (hi_lo_ready            ),
    .hi_lo_result(hi_lo_result           ),

    .wr_disable (wr_disable | pms_wr_disable | ~es_valid | exception.ex)
);

// forward
assign op_mfc0 = ds_to_es_bus_r.c0_op[2] & es_valid;
assign es_forward_bus = { op_mfc0,
                          ds_to_es_bus_r.res_from_mem & es_valid,
                          ds_to_es_bus_r.dest & {5{es_valid}},
                          final_result
                          };

// exception
assign exception.bd = ds_to_es_bus_r.exception.bd;
assign {exception.ex, exception.exccode} = ds_to_es_bus_r.exception.ex ? {ds_to_es_bus_r.exception.ex, ds_to_es_bus_r.exception.exccode} :
                                           alu_ex & es_valid           ? {1'b1, `EXCCODE_OV}                                             :
                                                                         6'h0;
assign exception.badvaddr = ds_to_es_bus_r.exception.badvaddr;

// to MEM
assign op_mtc0        = ds_to_es_bus_r.c0_op[1];
assign res_from_alu   = (|ds_to_es_bus_r.alu_op) & ~ds_to_es_bus_r.res_to_mem;
assign res_from_hi_lo = |ds_to_es_bus_r.hi_lo_op;
assign final_result   = {32{res_from_alu  }} & alu_result
                      | {32{res_from_hi_lo}} & hi_lo_result
                      | {32{op_mtc0 | ds_to_es_bus_r.res_to_mem}} & ds_to_es_bus_r.rt_value;
assign es_to_pms_bus  = { es_to_pms_valid,
                          ds_to_es_bus_r.load_op,
                          ds_to_es_bus_r.store_op,
                          ds_to_es_bus_r.c0_op,
                          ds_to_es_bus_r.c0_addr,
                          ds_to_es_bus_r.res_from_mem,
                          ds_to_es_bus_r.res_to_mem,
                          ds_to_es_bus_r.rf_we,
                          alu_result,
                          ds_to_es_bus_r.dest,
                          final_result,
                          ds_to_es_bus_r.pc,
                          exception
                          };

endmodule
