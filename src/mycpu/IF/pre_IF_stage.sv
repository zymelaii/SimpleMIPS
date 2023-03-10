`include "..\cpu_defs.svh"

module pre_if_stage (
    input clk,
    input reset,
    // pipeline
    input fs_allowin,
    // from IF
    input  logic fs_valid,
    // br_bus
    input  logic        br_bus_en,
    input  br_bus_t     br_bus,
    // to IF
    output pfs_to_fs_bus_t pfs_to_fs_bus,
    // to ID
    output        pfs_bd,
    output virt_t pfs_pc,
    // cp0 and exception
    input pipeline_flush_t pipeline_flush,
    input virt_t c0_epc,
    // inst_sram insterface
    output logic        inst_req,
    output logic        inst_wr,
    output logic [1:0]  inst_size,
    output logic [3:0]  inst_wstrb,
    output virt_t       inst_addr,
    output uint32_t     inst_wdata,
    input  logic        inst_addr_ok
);

// pre_IF
logic   to_pfs_valid;
logic   pfs_valid;
logic   pfs_ready_go;
logic   pfs_allowin;
logic   pfs_to_fs_valid;

virt_t  seq_pc;
virt_t  next_pc;
virt_t  pc;

// br_bus
logic    br_bus_r_valid;
br_bus_t br_bus_r;
br_bus_t final_br_bus;

// inst_sram interface
logic   req;
assign  req = pfs_valid & ~final_br_bus.stall & fs_allowin;

// pre_IF stage
assign to_pfs_valid = ~reset;
assign pfs_ready_go = req & inst_addr_ok;
assign pfs_allowin  = !pfs_valid || pfs_ready_go && fs_allowin;
assign pfs_to_fs_valid  = pfs_valid && pfs_ready_go;

assign pfs_bd    = final_br_bus.br_op & ~fs_valid;
assign seq_pc    = pc + 4;
assign next_pc   = pfs_bd          ? seq_pc              :
                   final_br_bus.taken ? final_br_bus.target :
                                        seq_pc;

always_ff @(posedge clk) begin
    if(reset)
        pfs_valid <= 1'b0;
    else if(pfs_allowin)
        pfs_valid <= to_pfs_valid;
    
    if (reset) begin
        pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if(pipeline_flush.ex) begin
        pc <= 32'hbfc0037c;
    end
    else if(pipeline_flush.eret) begin
        pc <= c0_epc-3'h4;
    end
    else if (to_pfs_valid && fs_allowin && pfs_ready_go) begin
        pc <= next_pc;
    end
end

// br_bus
assign final_br_bus.stall = br_bus.stall;
assign final_br_bus.br_op = br_bus_r_valid ? br_bus_r.br_op  : br_bus.br_op;
assign final_br_bus.taken = br_bus_r_valid ? br_bus_r.taken  : br_bus.taken;
assign final_br_bus.target= br_bus_r_valid ? br_bus_r.target : br_bus.target;

always_ff @(posedge clk) begin
    if(reset || pipeline_flush.ex || pipeline_flush.eret)
        br_bus_r_valid <= 1'b0;
    else if(!pfs_bd && pfs_ready_go && fs_allowin)
        br_bus_r_valid <= 1'b0;
    else if(final_br_bus.br_op && br_bus_en) begin
        br_bus_r_valid <= 1'b1;
        br_bus_r <= br_bus;
    end
end

// to IF
assign pfs_to_fs_bus = {pfs_to_fs_valid,
                        final_br_bus.stall,
                        final_br_bus.br_op,
                        next_pc
                        };

// to ID
assign pfs_pc = next_pc;

// inst_sram interface
assign inst_req   = req;
assign inst_wr    = 1'b0;
assign inst_size  = 2'd2;
assign inst_addr  = next_pc;
assign inst_wstrb = 4'd0;
assign inst_wdata = 32'd0;

endmodule
