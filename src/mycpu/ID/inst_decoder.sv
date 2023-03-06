`include "..\cpu_defs.svh"

module inst_decoder (
    input   uint32_t        inst,
    output  decoded_inst_t  inst_d
);

wire        alu_ov;
wire [11:0] alu_op;
wire [11:0] br_op;
wire [ 7:0] hi_lo_op;
wire [ 6:0] load_op;
wire [ 4:0] store_op;
wire [ 2:0] c0_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_simm;
wire        src2_is_zimm;
wire        src2_is_8;
wire        res_from_mem;
wire        res_to_mem;
wire        rf_we;
wire        dst_is_r31;  
wire        dst_is_rt;   
wire [ 4:0] dest;
wire [15:0] imm;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [19:0] code;
wire [ 2:0] sel;
wire [ 5:0] func;
wire [25:0] jidx;
wire [ 7:0] c0_addr;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire        code_d;
wire [63:0] func_d;

// add and substract
wire        inst_add, inst_addi, inst_addu, inst_addiu, inst_sub, inst_subu;
// compare and set
wire        inst_slt, inst_slti, inst_sltu, inst_sltiu;
// multiplication and division
wire        inst_div, inst_divu, inst_mult, inst_multu;
// logical
wire        inst_and, inst_andi, inst_or, inst_ori, inst_xor, inst_xori, inst_nor;
// shift
wire        inst_sll, inst_sllv, inst_srl, inst_srlv, inst_sra, inst_srav;
// HI/LO move
wire        inst_mfhi, inst_mflo, inst_mthi, inst_mtlo;
// set
wire        inst_lui;
// breakpoint and syscall
wire        inst_break, inst_syscall;
// privileged instructions
wire        inst_eret, inst_mfc0, inst_mtc0;
// load
wire        inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw, inst_lwl, inst_lwr;
// store
wire        inst_sb, inst_sh, inst_sw, inst_swl, inst_swr;
// branch
wire        inst_beq, inst_bne, inst_bgez, inst_bgtz, inst_blez, inst_bltz, inst_bgezal, inst_bltzal;
// jump
wire        inst_j, inst_jal, inst_jr, inst_jalr;
// invalid
wire        inst_invalid;

assign op   = inst[31:26];
assign rs   = inst[25:21];
assign rt   = inst[20:16];
assign rd   = inst[15:11];
assign sa   = inst[10: 6];
assign code = inst[25: 6];
assign sel  = inst[ 2: 0];
assign func = inst[ 5: 0];
assign imm  = inst[15: 0];
assign jidx = inst[25: 0];
assign c0_addr = {sel, rd};

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign code_d = code == 20'h80000;

// add and substract
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
// compare and set
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_slti   = op_d[6'h0a];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_sltiu  = op_d[6'h0b];
// multiplication and division
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00];
// logical
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_andi   = op_d[6'h0c];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_ori    = op_d[6'h0d];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_xori   = op_d[6'h0e];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
// shift
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
// HI/LO move
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
// set
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
// breakpoint and syscall
assign inst_break  = op_d[6'h00] & func_d[6'h0d];
assign inst_syscall= op_d[6'h00] & func_d[6'h0c];
// privileged instructions
assign inst_eret   = op_d[6'h10] & func_d[6'h18] & code_d;
assign inst_mfc0   = op_d[6'h10] & (~|func[5:3]) & rs_d[5'h00] & sa_d[5'h00];
assign inst_mtc0   = op_d[6'h10] & (~|func[5:3]) & rs_d[5'h04] & sa_d[5'h00];
// load
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lw     = op_d[6'h23];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
// store
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_sw     = op_d[6'h2b];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];
// branch
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
// jump
assign inst_j      = op_d[6'h02];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
// invalid
assign inst_invalid= (~|alu_op) & (~|hi_lo_op) & (~|br_op) & ~inst_syscall & ~inst_break & ~inst_mfc0 & ~inst_mtc0 & ~inst_eret;


assign alu_ov     = inst_add  | inst_addi | inst_sub;
assign alu_op[ 0] = inst_addu | inst_add  | inst_addiu  | inst_addi  | res_from_mem | res_to_mem | 
                    inst_jal  | inst_jalr | inst_bltzal | inst_bgezal;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and  | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or   | inst_ori;
assign alu_op[ 7] = inst_xor  | inst_xori;
assign alu_op[ 8] = inst_sll  | inst_sllv;
assign alu_op[ 9] = inst_srl  | inst_srlv;
assign alu_op[10] = inst_sra  | inst_srav;
assign alu_op[11] = inst_lui;

assign br_op[ 0] = inst_beq   ;
assign br_op[ 1] = inst_bne   ;
assign br_op[ 2] = inst_bgez  ;
assign br_op[ 3] = inst_bgtz  ;
assign br_op[ 4] = inst_blez  ;
assign br_op[ 5] = inst_bltz  ;
assign br_op[ 6] = inst_bgezal;
assign br_op[ 7] = inst_bltzal;
assign br_op[ 8] = inst_j     ;
assign br_op[ 9] = inst_jal   ;
assign br_op[10] = inst_jr    ;
assign br_op[11] = inst_jalr  ;

assign hi_lo_op[0] = inst_div;
assign hi_lo_op[1] = inst_divu;
assign hi_lo_op[2] = inst_mult;
assign hi_lo_op[3] = inst_multu;
assign hi_lo_op[4] = inst_mthi;
assign hi_lo_op[5] = inst_mtlo;
assign hi_lo_op[6] = inst_mfhi;
assign hi_lo_op[7] = inst_mflo;

assign load_op[0] = inst_lb; //* 增加load_op相应控制
assign load_op[1] = inst_lbu;
assign load_op[2] = inst_lh;
assign load_op[3] = inst_lhu;
assign load_op[4] = inst_lw;
assign load_op[5] = inst_lwl;
assign load_op[6] = inst_lwr;

assign store_op[0] = inst_sb;
assign store_op[1] = inst_sh;
assign store_op[2] = inst_sw;
assign store_op[3] = inst_swl;
assign store_op[4] = inst_swr;

assign c0_op[ 0] = inst_eret;
assign c0_op[ 1] = inst_mtc0;
assign c0_op[ 2] = inst_mfc0;

assign src1_is_sa   = inst_sll   | inst_srl    | inst_sra;
assign src1_is_pc   = inst_jal   | inst_jalr   | inst_bgezal | inst_bltzal;
assign src2_is_simm = inst_addiu | inst_addi   | 
                      inst_lui   | res_from_mem| res_to_mem  |
                      inst_slti  | inst_sltiu;
assign src2_is_zimm = inst_andi  | inst_ori    | inst_xori;
assign src2_is_8    = inst_jal   | inst_jalr   | inst_bgezal | inst_bltzal;
assign res_from_mem = |load_op;
assign res_to_mem   = |store_op;
assign dst_is_r31   = inst_jal   | inst_bgezal | inst_bltzal;
assign dst_is_rt    = inst_addiu | inst_addi   |
                      inst_lui   | res_from_mem| inst_mfc0 |
                      inst_slti  | inst_sltiu  |
                      inst_andi  | inst_ori    | inst_xori;
assign rf_we        = ~(res_to_mem)
                    & ~inst_beq  & ~inst_bne  & ~inst_bgez & ~inst_bgtz
                    & ~inst_blez & ~inst_bltz & ~inst_j    & ~inst_jr
                    & ~inst_div  & ~inst_divu & ~inst_mult & ~inst_multu
                    & ~inst_mthi & ~inst_mtlo & ~inst_mtc0 & ~inst_eret;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                      !rf_we     ? 5'd0  : //* 不写回时目的寄存器号默认为0
                                   rd    ;

assign inst_d = {inst_invalid,
                 rs,
                 rt,
                 rd,
                 alu_op,
                 alu_ov,
                 br_op,
                 hi_lo_op,
                 load_op,
                 store_op,
                 c0_op,
                 c0_addr,
                 src1_is_sa,
                 src1_is_pc,
                 src2_is_simm,
                 src2_is_zimm,
                 src2_is_8,
                 res_from_mem,
                 res_to_mem,
                 rf_we,
                 dest,
                 imm,
                 jidx,
                 inst_syscall,
                 inst_break
                };

endmodule
