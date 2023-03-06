`ifndef COMMON_DEFS_SVH
`define COMMON_DEFS_SVH

/*
common_defs:定义在整个cpu中使用的常量和数据结构
*/

//项目配置
`default_nettype wire
`timescale 1ns / 1ps

typedef logic [ 7:0] uint8_t;
typedef logic [15:0] uint16_t;
typedef logic [31:0] uint32_t;
typedef logic [63:0] uint64_t;
typedef uint32_t     virt_t;
typedef uint32_t     phys_t;

//AXI接口
typedef struct packed {
	// ar
    logic [31:0] araddr;
    logic [3 :0] arlen;
    logic [2 :0] arsize;
    logic [1 :0] arburst;
    logic        arlock;
    logic [3 :0] arcache;
    logic [2 :0] arprot;
    logic        arvalid;
	// r
    logic        rready;
	// aw
    logic [31:0] awaddr;
    logic [3 :0] awlen;
    logic [2 :0] awsize;
    logic [1 :0] awburst;
    logic        awlock;
    logic [3 :0] awcache;
    logic [2 :0] awprot;
    logic        awvalid;
	// w
    logic [31:0] wdata;
    logic [3 :0] wstrb;
    logic        wlast;
    logic        wvalid;
	// b
    logic        bready;
} axi_req;

typedef struct packed {
	// ar
	logic        arready;
	// r
	logic [31:0] rdata;
	logic [1 :0] rresp;
	logic        rlast;
	logic        rvalid;
	// aw
	logic        awready;
	// w
	logic        wready;
	// b
	logic [1 :0] bresp;
	logic        bvalid;
} axi_resp;

`endif