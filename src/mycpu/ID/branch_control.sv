`include "..\cpu_defs.svh"

module branch_control (
    input  ds_valid,
    input logic [11:0] br_op,
    input uint32_t rs_value,
    input uint32_t rt_value,
    input virt_t fs_pc,
    input uint16_t imm,
    input logic [25:0] jidx,
    input  ds_stall,
    output br_stall,
    output br_taken,
    output virt_t br_target
);

logic  inst_beq;
logic  inst_bne;
logic  inst_bgez;
logic  inst_bgtz;
logic  inst_blez;
logic  inst_bltz;
logic  inst_bgezal;
logic  inst_bltzal;
logic  inst_j;
logic  inst_jal;
logic  inst_jr;
logic  inst_jalr;

assign  inst_beq        = br_op[0];
assign  inst_bne        = br_op[1];
assign  inst_bgez       = br_op[2];
assign  inst_bgtz       = br_op[3];
assign  inst_blez       = br_op[4];
assign  inst_bltz       = br_op[5];
assign  inst_bgezal     = br_op[6];
assign  inst_bltzal     = br_op[7];
assign  inst_j          = br_op[8];
assign  inst_jal        = br_op[9];
assign  inst_jr         = br_op[10];
assign  inst_jalr       = br_op[11];

assign rs_eq_rt = (rs_value == rt_value);
assign rs_eq_z  = ~|rs_value;
assign rs_lt_z  = rs_value[31];
assign rs_ge_z  = ~rs_lt_z;
assign rs_gt_z  = ~rs_lt_z & ~rs_eq_z;
assign rs_le_z  = rs_lt_z | rs_eq_z;

assign br_stall = (|br_op) & ds_stall;
assign br_taken = (    inst_beq                  &&  rs_eq_rt
                   ||  inst_bne                  && !rs_eq_rt
                   || (inst_bgez | inst_bgezal)  &&  rs_ge_z
                   ||  inst_bgtz                 &&  rs_gt_z
                   ||  inst_blez                 &&  rs_le_z
                   || (inst_bltz | inst_bltzal)  &&  rs_lt_z
                   ||  inst_j
                   ||  inst_jal
                   ||  inst_jr
                   ||  inst_jalr
                  ) && ds_valid;
assign br_target = (inst_j  || inst_jal ) ? {fs_pc[31:28], jidx[25:0], 2'b0}:
                   (inst_jr || inst_jalr) ? rs_value :
                  /*inst_bXX*/              (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0});
endmodule
