`include "..\cpu_defs.svh"

module mem_operation (
    input logic [6:0] load_op,
    input logic [4:0] store_op,
    input             wr_disable,
    input virt_t      mem_addr,
    input uint32_t    mem_wdata,
    // exception
    output              mem_ex,
    output logic [4:0]  mem_exccode,
    // data sram interface
    output          data_sram_en,
    output [ 3:0]   data_sram_wen,
    output virt_t   data_sram_addr,
    output uint32_t data_sram_wdata
);

logic        op_sb ;
logic        op_sh ;
logic        op_sw ;
logic        op_swl;
logic        op_swr;

logic        op_lh;
logic        op_lhu;
logic        op_lw;

logic [3:0] mem_we;

// exception
logic ex_adel;
logic ex_ades;

assign op_sb  = store_op[0];
assign op_sh  = store_op[1];
assign op_sw  = store_op[2];
assign op_swl = store_op[3];
assign op_swr = store_op[4];

assign op_lh  = load_op[2];
assign op_lhu = load_op[3];
assign op_lw  = load_op[4];

// mem
assign mem_we = op_sb  ? (mem_addr[1] ? mem_addr[0] ? 4'h8 : 4'h4  :
                                        mem_addr[0] ? 4'h2 : 4'h1) :
                op_sh  ? (mem_addr[1] ? 4'hc : 4'h3 )              :
                op_swl ? (mem_addr[1] ? mem_addr[0] ? 4'hf : 4'h7  :
                                        mem_addr[0] ? 4'h3 : 4'h1) :
                op_swr ? (mem_addr[1] ? mem_addr[0] ? 4'h8 : 4'hc  :
                                        mem_addr[0] ? 4'he : 4'hf) :
                op_sw  ? 4'hf                                      :
                         4'h0                                      ;

// exception
assign ex_adel = (op_lh  && mem_addr[0]  )
               | (op_lhu && mem_addr[0]  )
               | (op_lw  && mem_addr[1:0]);
assign ex_ades = (op_sh  && mem_addr[0]  )
               | (op_sw  && mem_addr[1:0]);
assign {mem_ex, mem_exccode} = ({6{ex_adel}} & {1'b1, `EXCCODE_ADEL}) | ({6{ex_ades}} & {1'b1, `EXCCODE_ADES});

// data_sram interface
assign data_sram_en     = 1'b1;
assign data_sram_wen    = {4{~wr_disable}} & mem_we;
assign data_sram_addr   = mem_addr;
assign data_sram_wdata = op_sb  ? {4{mem_wdata[ 7:0]}} :
                         op_sh  ? {2{mem_wdata[15:0]}} :
                         op_swl ? mem_addr[1] ? mem_addr[0] ?  mem_wdata                : { 8'h0, mem_wdata[31: 8]} :
                                                mem_addr[0] ? {16'h0, mem_wdata[31:16]} : {24'h0, mem_wdata[31:24]} :
                         op_swr ? mem_addr[1] ? mem_addr[0] ? {mem_wdata[ 7: 0], 24'h0} : {mem_wdata[15: 0], 16'h0} :
                                                mem_addr[0] ? {mem_wdata[23: 0],  8'h0} :  mem_wdata                :
                                  mem_wdata;

endmodule
