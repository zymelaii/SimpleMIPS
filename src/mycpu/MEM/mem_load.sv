`include "..\cpu_defs.svh"

module mem_load (
    input  logic [6:0]  load_op,
    input               rf_wr,
    input  virt_t       mem_addr,
    input  uint32_t     data_sram_rdata,

    output logic [3:0]  rf_we,
    output uint32_t     mem_result
);

wire        op_lb;
wire        op_lbu;
wire        op_lh;
wire        op_lhu;
wire        op_lw;
wire        op_lwl;
wire        op_lwr;

uint32_t mem_data;

assign op_lb  = load_op[0];
assign op_lbu = load_op[1];
assign op_lh  = load_op[2];
assign op_lhu = load_op[3];
assign op_lw  = load_op[4];
assign op_lwl = load_op[5];
assign op_lwr = load_op[6];

assign rf_we =  op_lwl   ?  mem_addr[1] ? mem_addr[0] ? 4'hf : 4'he :
                                          mem_addr[0] ? 4'hc : 4'h8 :
                op_lwr   ?  mem_addr[1] ? mem_addr[0] ? 4'h1 : 4'h3 :
                                          mem_addr[0] ? 4'h7 : 4'hf :
                rf_wr    ?  4'hf :
                            4'h0 ;

assign mem_data = (op_lb | op_lbu) ? {24'h0, (mem_addr[1] ? mem_addr[0] ? data_sram_rdata[31:24] : data_sram_rdata[23:16]   :
                                                            mem_addr[0] ? data_sram_rdata[15: 8] : data_sram_rdata[ 7: 0])} :
                  (op_lh | op_lhu) ? {16'h0, (mem_addr[1] ? data_sram_rdata[31:16] : data_sram_rdata[15:0])} :
                  (op_lwl)         ? mem_addr[1] ? mem_addr[0] ?  data_sram_rdata                : {data_sram_rdata[23: 0],  8'h0} :
                                                   mem_addr[0] ? {data_sram_rdata[15: 0], 16'h0} : {data_sram_rdata[ 7: 0], 24'h0} :
                  (op_lwr)         ? mem_addr[1] ? mem_addr[0] ? {24'h0, data_sram_rdata[31:24]} : {16'h0, data_sram_rdata[31:16]} :
                                                   mem_addr[0] ? { 8'h0, data_sram_rdata[31: 8]} :  data_sram_rdata                :
                                     data_sram_rdata;

assign mem_result = op_lb  ? ({{24{mem_data[ 7]}},  8'h0} | mem_data) :
                    op_lh  ? ({{16{mem_data[15]}}, 16'h0} | mem_data) :
                             mem_data                                 ;

endmodule