`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_internal_if.vh"
// FIXME: Parameter passing from OpenPiton infrastructure instead
module bp_top_piton
 #(parameter core_els_p=1
   ,parameter vaddr_width_p=22
   ,parameter paddr_width_p=22
   ,parameter asid_width_p=10
   ,parameter branch_metadata_fwd_width_p=36
   ,parameter num_cce_p=1
   ,parameter num_lce_p=2
   ,parameter num_mem_p=1
   ,parameter coh_states_p=4
   ,parameter lce_assoc_p=8
   ,parameter lce_sets_p=16
   ,parameter cce_block_size_in_bytes_p=64
 
   ,localparam lg_core_els_p=`BSG_SAFE_CLOG2(core_els_p)
   ,localparam lg_num_lce_p=`BSG_SAFE_CLOG2(num_lce_p)

   ,localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
   ,localparam fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)
   ,localparam fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p
                                                ,paddr_width_p
                                                ,branch_metadata_fwd_width_p
                                                ,asid_width_p
                                                )

   ,localparam icache_lce_id_lp=0
   ,localparam dcache_lce_id_lp=1

   ,localparam reg_data_width_lp=RV64_reg_data_width_gp
   )
  (input logic                  clk_i
   ,input logic                 reset_i

   ,output logic [`NOC_DATA_WIDTH-1:0]                    noc1_data_o
   ,output logic                                          noc1_v_o
   ,input                                                 noc1_ready_i

   ,input [`NOC_DATA_WIDTH-1:0]                           noc2_data_i
   ,input                                                 noc2_v_i
   ,output logic                                          noc2_ready_o

   ,output logic [`NOC_DATA_WIDTH-1:0]                    noc3_data_o
   ,output logic                                          noc3_v_o
   ,input                                                 noc3_ready_i
  );

`declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);

/* TODO: Change to monolithic declare in bp_common */
/* TODO: Converge 'addr_width' and 'paddr_width', etc. */
`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, coh_states_p);
`declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);

// Top-level interface connections
bp_fe_queue_s[core_els_p-1:0] fe_fe_queue, be_fe_queue;
logic[core_els_p-1:0] fe_fe_queue_v, be_fe_queue_v, fe_fe_queue_rdy, be_fe_queue_rdy;

logic [core_els_p-1:0] fe_queue_clr, fe_queue_ckpt_inc, fe_queue_rollback;

bp_fe_cmd_s[core_els_p-1:0] fe_fe_cmd, be_fe_cmd;
logic [core_els_p-1:0] fe_fe_cmd_v, be_fe_cmd_v, fe_fe_cmd_rdy, be_fe_cmd_rdy;

bp_lce_cce_req_s[num_lce_p-1:0] lce_req, lce_cce_req;
logic [num_lce_p-1:0] lce_cce_req_v, lce_cce_req_rdy;

bp_lce_cce_resp_s [num_lce_p-1:0] lce_cce_resp;
logic [num_lce_p-1:0] lce_cce_resp_v, lce_cce_resp_rdy;

bp_lce_cce_data_resp_s [num_lce_p-1:0] lce_cce_data_resp;
logic [num_lce_p-1:0] lce_cce_data_resp_v, lce_cce_data_resp_rdy;

bp_cce_lce_cmd_s [num_lce_p-1:0] cce_lce_cmd;
logic [num_lce_p-1:0] cce_lce_cmd_v, cce_lce_cmd_rdy;

bp_cce_lce_data_cmd_s [num_lce_p-1:0] cce_lce_data_cmd;
logic [num_lce_p-1:0] cce_lce_data_cmd_v, cce_lce_data_cmd_rdy;

bp_lce_lce_tr_resp_s [num_lce_p-1:0] local_lce_tr_resp, remote_lce_tr_resp;
logic [num_lce_p-1:0] local_lce_tr_resp_v, local_lce_tr_resp_rdy;
logic [num_lce_p-1:0] remote_lce_tr_resp_v, remote_lce_tr_resp_rdy;


// Module instantiations
/* TODO: Settle on parameter names and converge redundant parameters */
genvar core_id;
generate
for(core_id = 0; core_id < core_els_p; core_id = core_id + 1) begin
    localparam icache_id = core_id*2+icache_lce_id_lp;
    localparam dcache_id = core_id*2+dcache_lce_id_lp;

    bp_fe_top#(.vaddr_width_p(vaddr_width_p)
               ,.paddr_width_p(paddr_width_p)
               ,.eaddr_width_p(64)
               ,.btb_indx_width_lp(9)
               ,.bht_indx_width_lp(5)
               ,.ras_addr_width_lp(vaddr_width_p)
               ,.asid_width_lp(10)
               ,.bp_first_pc(bp_pc_entry_point_gp) /* TODO: Not ideal to couple to RISCV-tests */

               ,.data_width_p(64)
               ,.inst_width_p(32)
               ,.lce_sets_p(lce_sets_p)
               ,.lce_assoc_p(lce_assoc_p)
               ,.tag_width_p(12)
               ,.coh_states_p(coh_states_p)
               ,.num_cce_p(num_cce_p)
               ,.num_lce_p(num_lce_p)
               ,.lce_id_p(icache_id) /* TODO: What should this be? Globally set? */
               ,.block_size_in_bytes_p(8) /* TODO: This is ways not blocks */

               /* TODO: DEFINITELY RENAME */
               ,.els_p(100)
               ,.width(100)
               )
            fe(.clk_i(clk_i)
               ,.reset_i(reset_i)

               ,.bp_fe_queue_o(fe_fe_queue[core_id])
               ,.bp_fe_queue_v_o(fe_fe_queue_v[core_id])
               ,.bp_fe_queue_ready_i(fe_fe_queue_rdy[core_id])

               ,.bp_fe_cmd_i(fe_fe_cmd[core_id])
               ,.bp_fe_cmd_v_i(fe_fe_cmd_v[core_id])
               ,.bp_fe_cmd_ready_o(fe_fe_cmd_rdy[core_id])

               ,.lce_cce_req_o(lce_cce_req[icache_id])
               ,.lce_cce_req_v_o(lce_cce_req_v[icache_id])
               ,.lce_cce_req_ready_i(lce_cce_req_rdy[icache_id])

               ,.lce_cce_resp_o(lce_cce_resp[icache_id])
               ,.lce_cce_resp_v_o(lce_cce_resp_v[icache_id])
               ,.lce_cce_resp_ready_i(lce_cce_resp_rdy[icache_id])

               ,.lce_cce_data_resp_o(lce_cce_data_resp[icache_id])
               ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v[icache_id])
               ,.lce_cce_data_resp_ready_i(lce_cce_data_resp_rdy[icache_id])

               ,.cce_lce_cmd_i(cce_lce_cmd[icache_id])
               ,.cce_lce_cmd_v_i(cce_lce_cmd_v[icache_id])
               ,.cce_lce_cmd_ready_o(cce_lce_cmd_rdy[icache_id])

               ,.cce_lce_data_cmd_i(cce_lce_data_cmd[icache_id])
               ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v[icache_id])
               ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_rdy[icache_id])

               ,.lce_lce_tr_resp_i(local_lce_tr_resp[icache_id])
               ,.lce_lce_tr_resp_v_i(local_lce_tr_resp_v[icache_id])
               ,.lce_lce_tr_resp_ready_o(local_lce_tr_resp_rdy[icache_id])

               ,.lce_lce_tr_resp_o(remote_lce_tr_resp[icache_id])
               ,.lce_lce_tr_resp_v_o(remote_lce_tr_resp_v[icache_id])
               ,.lce_lce_tr_resp_ready_i(remote_lce_tr_resp_rdy[icache_id])
               );

    bsg_fifo_1r1w_rolly #(.width_p(fe_queue_width_lp)
                          ,.els_p(16)
                          ,.ready_THEN_valid_p(1)
                          )
            fe_queue_fifo(.clk_i(clk_i)
                          ,.reset_i(reset_i)

                          ,.clr_v_i(fe_queue_clr[core_id])
                          ,.ckpt_v_i(fe_queue_ckpt_inc[core_id])
                          ,.roll_v_i(fe_queue_rollback[core_id])

                          ,.data_i(fe_fe_queue[core_id])
                          ,.v_i(fe_fe_queue_v[core_id])
                          ,.ready_o(fe_fe_queue_rdy[core_id])

                          ,.data_o(be_fe_queue[core_id])
                          ,.v_o(be_fe_queue_v[core_id])
                          ,.yumi_i(be_fe_queue_rdy[core_id] & be_fe_queue_v[core_id])
                          );

    bsg_fifo_1r1w_small #(.width_p(109) /* TODO: Fix padding issue */
                          ,.els_p(8)    /* TODO: Make ready-then-valid */
                          )
              fe_cmd_fifo(.clk_i(clk_i)
                          ,.reset_i(reset_i)
                          
                          ,.data_i(be_fe_cmd[core_id])
                          ,.v_i(be_fe_cmd_v[core_id])
                          ,.ready_o(be_fe_cmd_rdy[core_id])
                    
                          ,.data_o(fe_fe_cmd[core_id])
                          ,.v_o(fe_fe_cmd_v[core_id])
                          ,.yumi_i(fe_fe_cmd_rdy[core_id] & fe_fe_cmd_v[core_id])
                          );

    bp_be_top #(.mhartid_p(core_id)
                ,.vaddr_width_p(vaddr_width_p)
                ,.paddr_width_p(paddr_width_p)
                ,.asid_width_p(asid_width_p)
                ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
                ,.num_cce_p(num_cce_p)
                ,.num_lce_p(num_lce_p)
                ,.num_mem_p(num_mem_p)
                ,.coh_states_p(coh_states_p)
                ,.lce_assoc_p(lce_assoc_p)
                ,.lce_sets_p(lce_sets_p)
                ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)

                ,.dcache_id_p(dcache_id)
                )
             be(.clk_i(clk_i)
                ,.reset_i(reset_i)

                ,.fe_queue_i(be_fe_queue[core_id])
                ,.fe_queue_v_i(be_fe_queue_v[core_id])
                ,.fe_queue_rdy_o(be_fe_queue_rdy[core_id])

                ,.fe_queue_clr_o(fe_queue_clr[core_id])
                ,.fe_queue_ckpt_inc_o(fe_queue_ckpt_inc[core_id])
                ,.fe_queue_rollback_o(fe_queue_rollback[core_id])

                ,.fe_cmd_o(be_fe_cmd[core_id])
                ,.fe_cmd_v_o(be_fe_cmd_v[core_id])
                ,.fe_cmd_rdy_i(be_fe_cmd_rdy[core_id])

                ,.lce_cce_req_o(lce_cce_req[dcache_id])
                ,.lce_cce_req_v_o(lce_cce_req_v[dcache_id])
                ,.lce_cce_req_rdy_i(lce_cce_req_rdy[dcache_id])

                ,.lce_cce_resp_o(lce_cce_resp[dcache_id])
                ,.lce_cce_resp_v_o(lce_cce_resp_v[dcache_id])
                ,.lce_cce_resp_rdy_i(lce_cce_resp_rdy[dcache_id])

                ,.lce_cce_data_resp_o(lce_cce_data_resp[dcache_id])
                ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v[dcache_id])
                ,.lce_cce_data_resp_rdy_i(lce_cce_data_resp_rdy[dcache_id])

                ,.cce_lce_cmd_i(cce_lce_cmd[dcache_id])
                ,.cce_lce_cmd_v_i(cce_lce_cmd_v[dcache_id])
                ,.cce_lce_cmd_rdy_o(cce_lce_cmd_rdy[dcache_id])

                ,.cce_lce_data_cmd_i(cce_lce_data_cmd[dcache_id])
                ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v[dcache_id])
                ,.cce_lce_data_cmd_rdy_o(cce_lce_data_cmd_rdy[dcache_id])

                ,.lce_lce_tr_resp_i(local_lce_tr_resp[dcache_id])
                ,.lce_lce_tr_resp_v_i(local_lce_tr_resp_v[dcache_id])
                ,.lce_lce_tr_resp_rdy_o(local_lce_tr_resp_rdy[dcache_id])

                ,.lce_lce_tr_resp_o(remote_lce_tr_resp[dcache_id])
                ,.lce_lce_tr_resp_v_o(remote_lce_tr_resp_v[dcache_id])
                ,.lce_lce_tr_resp_rdy_i(remote_lce_tr_resp_rdy[dcache_id])
                );
end
endgenerate
        transducer transducer(.clk_i(clk_i)
                              ,.reset_i(reset_i)
                                

                              /* ****I cache ports **** */
                              ,.icache_lce_req_i()
                              ,.icache_lce_req_v_i()
                              ,.icache_lce_req_ready_o()
                              
                              ,.icache_lce_resp_i()
                              ,.icache_lce_resp_v_i()
                              ,.icache_lce_resp_ready_o()
                              
                              ,.icache_data_resp_i()
                              ,.icache_lce_data_resp_v_i()
                              ,.icache_lce_data_resp_ready_o()
                              
                              ,.icache_lce_cmd_o()
                              ,.icache_lce_cmd_v_o()
                              ,.icache_lce_cmd_ready_i()
                              
                              ,.icache_lce_data_cmd_o()
                              ,.icache_lce_data_cmd_v_o()
                              ,.icache_lce_data_cmd_ready_i()
                              
                              /* ****D cache ports **** */
                              ,.dcache_lce_req_i()
                              ,.dcache_lce_req_v_i()
                              ,.dcache_lce_req_ready_o()
                              
                              ,.dcache_lce_resp_i()
                              ,.dcache_lce_resp_v_i()
                              ,.dcache_lce_resp_ready_o()
                              
                              ,.dcache_data_resp_i()
                              ,.dcache_lce_data_resp_v_i()
                              ,.dcache_lce_data_resp_ready_o()
                              
                              ,.dcache_lce_cmd_o()
                              ,.dcache_lce_cmd_v_o()
                              ,.dcache_lce_cmd_ready_i()
                              
                              ,.dcache_lce_data_cmd_o()
                              ,.dcache_lce_data_cmd_v_o()
                              ,.dcache_lce_data_cmd_ready_i()

                              /* ****noc ports **** */
                              ,.noc1_data_o(noc1_data_o)
                              ,.noc1_v_o(noc1_v_o)
                              ,.noc1_ready_i(noc1_ready_i)

                              ,.noc2_data_i(noc2_data_i)
                              ,.noc2_v_i(noc2_v_i)
                              ,.noc2_ready_o(noc2_ready_o)

                              ,.noc3_data_o(noc3_data_o)
                              ,.noc3_v_o(noc3_v_o)
                              ,.noc3_ready_i(noc3_ready_i)
                            );

endmodule : bp_top_piton
