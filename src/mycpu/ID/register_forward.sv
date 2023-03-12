`include "..\cpu_defs.svh"

module register_forward(
    input ds_valid,
    input decoded_inst_t inst_d,
    // regfile
    input uint32_t   rf_rdata1,
    input uint32_t   rf_rdata2,
    // es forward
    input            es_mfc0,
    input            es_tlb,
    input            es_load,
    input reg_addr_t es_dest,
    input uint32_t   es_result,
    // pms forward
    input            pms_mfc0,
    input            pms_tlb,
    input            pms_load,
    input reg_addr_t pms_dest,
    input uint32_t   pms_result,
    // ms forward
    input            ms_mfc0,
    input            ms_tlb,
    input            ms_load,
    input [ 3:0]     ms_rf_we,
    input reg_addr_t ms_dest,
    input uint32_t   ms_result,
    // ws forward
    input            ws_mfc0,
    input            ws_tlb,
    input [ 3:0]     ws_rf_we,
    input reg_addr_t ws_dest,
    input uint32_t   ws_result,
    //result
    output uint32_t  rs_value,
    output uint32_t  rt_value,
    // stall
    output           ds_stall
);


//* 写后读数据冲突
assign rs_wait = inst_d.rs != 5'd0
                 & ( (inst_d.rs == es_dest) | (inst_d.rs == pms_dest) | (inst_d.rs == ms_dest) | (inst_d.rs == ws_dest)) ;
assign rt_wait = inst_d.rt != 5'd0 & ~inst_d.src2_is_zimm & (~inst_d.src2_is_simm | (inst_d.res_to_mem)) 
                 & ~inst_d.src2_is_8
                 & ( (inst_d.rt == es_dest) | (inst_d.rt == pms_dest) | (inst_d.rt == ms_dest) | (inst_d.rt == ws_dest)) ;
assign ds_stall = ds_valid & 
                ( ( es_load  & (rs_wait & (inst_d.rs == es_dest ) | rt_wait & (inst_d.rt == es_dest )) )
                | ( pms_load & (rs_wait & (inst_d.rs == pms_dest) | rt_wait & (inst_d.rt == pms_dest)) )
                | ( ms_load  & (rs_wait & (inst_d.rs == ms_dest ) | rt_wait & (inst_d.rt == ms_dest )) )
                | ( (es_mfc0 | pms_mfc0 | ms_mfc0 | ws_mfc0) & (rs_wait | rt_wait) ) )
                | ( (es_tlb  | pms_tlb  | ms_tlb  | ws_tlb)); //* load指令冲突, mfc0冲突, tlb指令

// bypass
assign rs_value = !rs_wait             ? rf_rdata1                                           :
                  inst_d.rs == es_dest ? es_result                                           :
                  inst_d.rs == pms_dest? pms_result                                          :
                  inst_d.rs == ms_dest ? {ms_rf_we[3] ? ms_result[31:24] : rf_rdata1[31:24],
                                          ms_rf_we[2] ? ms_result[23:16] : rf_rdata1[23:16],
                                          ms_rf_we[1] ? ms_result[15: 8] : rf_rdata1[15: 8],
                                          ms_rf_we[0] ? ms_result[ 7: 0] : rf_rdata1[ 7: 0]} :
                                         {ws_rf_we[3] ? ws_result[31:24] : rf_rdata1[31:24],
                                          ws_rf_we[2] ? ws_result[23:16] : rf_rdata1[23:16],
                                          ws_rf_we[1] ? ws_result[15: 8] : rf_rdata1[15: 8],
                                          ws_rf_we[0] ? ws_result[ 7: 0] : rf_rdata1[ 7: 0]} ;
assign rt_value = !rt_wait             ? rf_rdata2                                           :
                  inst_d.rt == es_dest ? es_result                                           :
                  inst_d.rt == pms_dest? pms_result                                          :
                  inst_d.rt == ms_dest ? {ms_rf_we[3] ? ms_result[31:24] : rf_rdata2[31:24],
                                          ms_rf_we[2] ? ms_result[23:16] : rf_rdata2[23:16],
                                          ms_rf_we[1] ? ms_result[15: 8] : rf_rdata2[15: 8],
                                          ms_rf_we[0] ? ms_result[ 7: 0] : rf_rdata2[ 7: 0]} :
                                         {ws_rf_we[3] ? ws_result[31:24] : rf_rdata2[31:24],
                                          ws_rf_we[2] ? ws_result[23:16] : rf_rdata2[23:16],
                                          ws_rf_we[1] ? ws_result[15: 8] : rf_rdata2[15: 8],
                                          ws_rf_we[0] ? ws_result[ 7: 0] : rf_rdata2[ 7: 0]} ;

endmodule
