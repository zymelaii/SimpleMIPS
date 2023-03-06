`include "..\cpu_defs.svh"

module alu(
    input  logic [11:0] alu_op,
    
    input  src1_is_sa,
    input  src1_is_pc,
    input  src2_is_simm,
    input  src2_is_zimm,
    input  src2_is_8,
    input  uint32_t     rs_value,
    input  uint32_t     rt_value,
    input  virt_t       pc,
    input  uint16_t     imm,

    output uint32_t     alu_result,
    // 溢出检测
    input   alu_ov,
    output  alu_ex
);

wire op_add;   //加法操作
wire op_sub;   //减法操作
wire op_slt;   //有符号比较，小于置位
wire op_sltu;  //无符号比较，小于置位
wire op_and;   //按位与
wire op_nor;   //按位或非
wire op_or;    //按位或
wire op_xor;   //按位异或
wire op_sll;   //逻辑左移
wire op_srl;   //逻辑右移
wire op_sra;   //算术右移
wire op_lui;   //立即数置于高半部分

uint32_t alu_src1;
uint32_t alu_src2;

assign alu_src1 = src1_is_sa  ? {27'b0, imm[10:6]} : 
                  src1_is_pc  ? pc[31:0]           :
                                rs_value;
assign alu_src2 = src2_is_simm ? {{16{imm[15]}}, imm[15:0]} : 
                  src2_is_zimm ? {16'h0, imm[15:0]}         :
                  src2_is_8    ? 32'd8                      :
                                 rt_value;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];

wire [31:0] add_sub_result; 
wire [31:0] slt_result; 
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result; 
wire [63:0] sr64_result; 
wire [31:0] sr_result; 


// 32-bit adder
wire [32:0] adder_a;
wire [32:0] adder_b;
wire        adder_cin;
wire [32:0] adder_result;
wire        adder_cout;

assign adder_a   = {alu_src1[31], alu_src1};
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~({alu_src2[31], alu_src2}) : {alu_src2[31], alu_src2};
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1                        : 1'b0                    ;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

//溢出
assign alu_ex = alu_ov & (adder_result[32] ^ adder_result[31]);

// ADD, SUB result
assign add_sub_result = adder_result[31:0];

// SLT result
assign slt_result[31:1] = 31'b0;
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2; //* 删除alu_result
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = {alu_src2[15:0], 16'b0};

// SLL result 
assign sll_result = alu_src2 << alu_src1[4:0];

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src2[31]}}, alu_src2[31:0]} >> alu_src1[4:0];

assign sr_result   = sr64_result[31:0]; //最高有效位由30改为31

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result);


endmodule
