/**
 * bp_fe_icache.vh
 *
 * This file declares the internal structs of the BlackParrot Front End I-Cache
 * module. For simplicity and flexibility, these structs are parameterized. Each
 * struct declares its width separately to prevent pre-processor ordering issues.
 */

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

import bp_common_pkg::*;

/*
 * bp_fe_icache_pc_gen_s defines the interface between I-Cache and pc_gen. The
 * I-Cache sends the data (instruction) stored at the virtual pc address to the
 * pc_gen. The width of data (instruction) is specified by the bp_instr_width_gp parameter.
 */
`define declare_bp_fe_icache_pc_gen_s(eaddr_width_p) \
  typedef struct packed {                            \
    logic [bp_instr_width_gp-1:0] instr;             \
    logic [eaddr_width_p-1:0]     addr;              \
  } bp_fe_icache_pc_gen_s

`define bp_fe_icache_pc_gen_width(eaddr_width_p) \
  (bp_instr_width_gp+eaddr_width_p)

/*
 *
 * bp_fe_icache_meta_data_s is the struct that specifies the format of the
 * I-Cache meta-data array. The meta-data array contains the auxiliary
 * information, i.e., dirty bits and LRU bits. A dirty bit indicates whether the
 * corresponding line is dirty. The LRU bits are used to track the recency of
 * access to the ways. The meta-data array format (for a 4-way associative 
 * cache) is as follows:
 * | LRU | dirty | dirty | dirty | dirty |
 *       - way_0 - way_1 - way_2 - way_3 - 
 * For the I-Cache meta-data array, we do not need dirty bits. Upon a miss, the
 * LCE transmits the meta-data (including LRU and dirty bits) information of the
 * tag set to the CCE, and the CCE makes the necessary decisions. 
*/
`define declare_bp_fe_icache_meta_data_s(lce_assoc_p) \
  typedef struct packed {                             \
    logic [lce_assoc_p-2:0] way;                      \
  } bp_fe_icache_meta_data_s

`define bp_fe_icache_meta_data_width(lce_assoc_p) \
  (lce_assoc_p-1)

/*
 *
 * bp_fe_icache_tag_set_s is the struct that defines the format of the I-Cache
 * tag array. The tag array consists of state bits as well as physical tag
 * bits. The state bits indicate the state of the cache line according to the
 * cache coherency protocol. L1 I-Cache only has shared (S) and invalid (I)
 * states. The tag array format (for a 4-way associative cache) is as follows:
 * | S | addr | S | addr | S | addr | S | addr |
 * -   way_0  -   way_1  -   way_2 -    way_3  -
 */
`define declare_bp_fe_icache_tag_set_s(coh_states_p, tag_width_p, lce_assoc_p) \
  typedef struct packed {                                                      \
    logic [`BSG_SAFE_CLOG2(coh_states_p)-1:0]  state;                          \
    logic [tag_width_p-1:0]                    tag;                            \
  } bp_fe_icache_tag_set_s [lce_assoc_p-1:0]

`define bp_fe_icache_tag_set_width(coh_states_p, tag_width_p, lce_assoc_p) \
  ((`BSG_SAFE_CLOG2(coh_states_p)+tag_width_p)*lce_assoc_p)

`define bp_fe_icache_tag_state_width(coh_state_p, tag_width_p) \
  (`BSG_SAFE_CLOG2(coh_states_p)+tag_width_p)

`endif
