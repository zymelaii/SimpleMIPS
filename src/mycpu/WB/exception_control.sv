`include "..\cpu_defs.svh"

module  exception_control (
    input  ws_valid,

    input  logic [2:0] c0_op,
    input  logic [7:0] ws_c0_addr,
    input  uint32_t    ws_result,
    // cp0 interface
    output             c0_we,
    output logic [7:0] c0_addr,
    output uint32_t    c0_wdata,
    input  uint32_t    c0_rdata,
    // exception
    output eret_flush,
    output ex_en,
    // to cp0
    input  virt_t           ws_pc,
    input  exception_t      ws_exception,
    output                  c0_eret_flush,
    output exception_t      c0_exception,
    output virt_t           c0_pc
);

wire        op_eret;
wire        op_mtc0;
wire        op_mfc0;

assign op_eret = c0_op[0];
assign op_mtc0 = c0_op[1];
assign op_mfc0 = c0_op[2];

// cp0 interface
assign c0_we    = ws_valid & op_mtc0;
assign c0_addr  = ws_c0_addr;
assign c0_wdata = ws_result;

// exception
assign eret_flush = op_eret & ws_valid;
assign ex_en      = ws_exception.ex & ws_valid;

// to cp0
assign c0_eret_flush  = op_eret & ws_valid;
assign c0_exception   = {ws_exception.bd,
                         ex_en,
                         ws_exception.exccode,
                         ws_exception.badvaddr
                         };
assign c0_pc          = ws_pc;

endmodule
