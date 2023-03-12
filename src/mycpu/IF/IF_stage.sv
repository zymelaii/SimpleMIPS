`include "..\cpu_defs.svh"

module if_stage (
    input clk,
    input reset,
    // pipeline
    input  ds_allowin,
    output fs_allowin,
    // from pre_IF
    input pfs_to_fs_bus_t pfs_to_fs_bus,
    // to IF
    output logic fs_to_pfs_valid,
    // to ID
    output fs_to_ds_bus_t fs_to_ds_bus,
    // cp0 and exception
    input pipeline_flush_t pipeline_flush,
    input virt_t c0_epc,
    // inst sram interface
    input logic     inst_data_ok,
    input uint32_t  inst_rdata
);

// IF
logic fs_valid;
logic fs_ready_go;
logic fs_to_ds_valid;
logic pfs_fs_lock;
logic    fs_inst_valid;
uint32_t fs_inst;

// from pre_IF
pfs_to_fs_bus_t pfs_to_fs_bus_r;

// exception
exception_t exception;
logic data_cancel;

// IF stage
assign pfs_fs_lock = pfs_to_fs_bus.br_op && !pfs_to_fs_bus.valid && fs_valid;
assign fs_ready_go = (inst_data_ok || fs_inst_valid) && !data_cancel && !pfs_to_fs_bus.stall || pfs_to_fs_bus_r.exception.ex;
assign fs_allowin = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid = fs_valid && fs_ready_go && !pfs_fs_lock;

always_ff @( posedge clk ) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if(pipeline_flush.ex | pipeline_flush.eret || pipeline_flush.tlb_op) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin && !pfs_fs_lock) begin
        fs_valid <= pfs_to_fs_bus.valid;
    end

    if(pfs_to_fs_bus.valid && fs_allowin && !pfs_fs_lock)
        pfs_to_fs_bus_r <= pfs_to_fs_bus;
    
    if(reset || pipeline_flush.ex || pipeline_flush.eret || pipeline_flush.tlb_op)
        fs_inst_valid <= 1'b0;
    else if(inst_data_ok && (!ds_allowin || pfs_to_fs_bus.stall || pfs_fs_lock)) begin
        fs_inst_valid <= 1'b1;
        fs_inst       <= inst_rdata;
    end
    else if(ds_allowin && fs_ready_go && !pfs_fs_lock)
        fs_inst_valid <= 1'b0;
end

// to IF
assign fs_to_pfs_valid = fs_valid;

// cp0 and ex
always_ff @(posedge clk) begin
    if(reset)
        data_cancel <= 1'b0;
    else if((pipeline_flush.eret || pipeline_flush.ex || pipeline_flush.tlb_op) && (pfs_to_fs_bus.req || !fs_ready_go && fs_valid))
        data_cancel <= 1'b1;
    else if(inst_data_ok)
        data_cancel <= 1'b0;
end
assign exception = { pfs_to_fs_bus_r.exception.tlb_refill,
                     pfs_to_fs_bus.br_op,
                     pfs_to_fs_bus_r.exception.ex,
                     pfs_to_fs_bus_r.exception.exccode,
                     pfs_to_fs_bus_r.exception.badvaddr};
// to ID
assign fs_to_ds_bus = { fs_to_ds_valid,
                        fs_inst_valid ? fs_inst : inst_rdata,
                        pfs_to_fs_bus_r.pc,
                        exception
                      };

endmodule
