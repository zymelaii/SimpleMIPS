`include "..\cpu_defs.svh"

module if_stage (
    input clk,
    input reset,
    // pipeline
    input ds_allowin,
    // branch bus
    input br_bus_t br_bus,
    // to ID
    output fs_to_ds_bus_t fs_to_ds_bus,
    // cp0 and exception
    input pipeline_flush_t pipeline_flush,
    input virt_t c0_epc,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata
);

// IF
logic fs_valid;
logic fs_ready_go;
logic fs_allowin;
logic fs_to_ds_valid;
virt_t fs_pc;

// pre_IF
logic   pre_if_ready_go;
logic   to_fs_valid;
virt_t  seq_pc;
virt_t  next_pc;

// exception
exception_t exception;

// pre-IF stage
assign pre_if_ready_go = ~br_bus.stall;
assign to_fs_valid = ~reset & pre_if_ready_go;
assign seq_pc = fs_pc + 4;
assign next_pc = br_bus.taken ? br_bus.target : seq_pc;

// IF stage
assign fs_ready_go = ~br_bus.stall;
assign fs_allowin = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid = fs_valid && fs_ready_go;
always_ff @( posedge clk ) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if(pipeline_flush.ex | pipeline_flush.eret) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if(pipeline_flush.ex) begin
        fs_pc <= 32'hbfc0037c;
    end
    else if(pipeline_flush.eret) begin
        fs_pc <= c0_epc-3'h4;
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= next_pc;
    end
end

// cp0 and ex
assign exception.bd = br_bus.bd;
assign exception.ex = fs_valid && (fs_pc[1:0] != 2'h0);
assign exception.exccode = `EXCCODE_ADEL;
assign exception.badvaddr = fs_pc;

// to ID
assign fs_to_ds_bus = { fs_to_ds_valid,
                        inst_sram_rdata,
                        fs_pc,
                        exception
                      };

assign inst_sram_en    = to_fs_valid && fs_allowin && !br_bus.stall;
assign inst_sram_wen   = 4'h0;
assign inst_sram_addr  = next_pc;
assign inst_sram_wdata = 32'b0;

endmodule
