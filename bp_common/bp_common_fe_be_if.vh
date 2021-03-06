/**
 *
 * bp_common_fe_be_if.vh
 *
 * bp_fe_be_interface.vh declares the interface between the BlackParrot Front End
 * and Back End For simplicity and flexibility, these signals are declared as
 * parameterizable structures. Each structure declares its width separately to
 * avoid preprocessor ordering issues.
 *
 * Logically, the BE controls the FE and may command the FE to flush all the states,
 * redirect the PC, etc. The FE uses its queue to supply the BE with (possibly
 * speculative) instruction/PC pairs and inform the BE of any exceptions that have
 * occurred within the unit (e.g., misaligned instruction fetch) so the BE may
 * ensure all exceptions are taken precisely.  The BE checks the PC in the
 * instruction/PC pairs to make sure that the FE predictions correspond to
 * correct architectural execution.
 *
 */

`ifndef BP_COMMON_FE_BE_IF
`define BP_COMMON_FE_BE_IF

`include "bsg_defines.v"

import bp_common_pkg::*;

/*
 * Clients need only use this macro to declare all parameterized structs for FE<->BE interface.
 */
`define declare_bp_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    /*                                                                                             \
     *                                                                                             \
     * bp_fe_fetch_s contains the pc/instruction pair, along with additional                       \
     * information including virtual address. The branch metadata is for the branch                \
     * predictor to update its internal data based on feedbacks from the BE as to                  \
     * whether this particular PC/instruction pair was correct.  The BE does not look              \
     * at the branch metadata, since this would mean that the BE implementation is                 \
     * tightly coupled to the FE implementation.                                                   \
     */                                                                                            \
    typedef struct packed {                                                                        \
        logic [bp_eaddr_width_gp-1:0]             pc;                                              \
        logic [bp_instr_width_gp-1:0]             instr;                                           \
        logic [branch_metadata_fwd_width_p-1:0]   branch_metadata_fwd;                             \
        logic [`bp_fe_fetch_padding_width-1:0]    padding;                                         \
    } bp_fe_fetch_s;                                                                               \
                                                                                                   \
    /*                                                                                             \
     *                                                                                             \
     * bp_fe_exception_s contains FE exception information.  Exceptions should be                  \
     * serviced inline with instructions. Otherwise we have no way of knowing if this              \
     * exception is eclipsed by a preceding branch mispredict.  FE does not receive                \
     * interrupts, but may raise exceptions.                                                       \
     */                                                                                            \
    typedef struct packed {                                                                        \
        logic [vaddr_width_p-1:0]                  vaddr;                                          \
        bp_fe_exception_code_e                     exception_code;                                 \
        logic [`bp_fe_exception_padding_width-1:0] padding;                                        \
    } bp_fe_exception_s;                                                                           \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_queue_s is the struct that the FE feeds the queue connecting the FE to                \
     * the BE bp_fe_queue_type_e specifies which type of information is forwarded to               \
     * the backend, choosing between bp_fe_fetch_s or bp_fe_exception_s.                           \
     * NOTE: VCS can only handle packed unions where each member is the same size                  \
     */                                                                                            \
    typedef struct packed {                                                                        \
        bp_fe_queue_type_e    msg_type;                                                            \
        union packed {                                                                             \
            bp_fe_fetch_s         fetch;                                                           \
            bp_fe_exception_s     exception;                                                       \
        } msg;                                                                                     \
    } bp_fe_queue_s;                                                                               \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_pc_redirect_operands_s provides the information needed during the pc              \
     * redirection.  command_queue_subopcode provides the reasons for pc redirection.              \
     * branch_metadata_fwd provides the information of branch misprediction.                       \
     * translation_enabled tells whether the pc is virtual or physical in the case of              \
     * context switch.                                                                             \
    */                                                                                             \
    typedef struct packed {                                                                        \
        logic [bp_eaddr_width_gp-1:0]           pc;                                                \
        bp_fe_command_queue_subopcodes_e        subopcode;                                         \
        logic [branch_metadata_fwd_width_p-1:0] branch_metadata_fwd;                               \
        bp_fe_misprediction_reason_e            misprediction_reason;                              \
        logic                                   translation_enabled;                               \
        logic [`bp_fe_cmd_pc_redirect_operands_padding_width-1:0]                                  \
                                                padding;                                           \
    } bp_fe_cmd_pc_redirect_operands_s;                                                            \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_attaboy_s provides branch prediction metadata back to the FE on the case of           \
     * correct prediction, so that the FE can update its predictors accordingly.                   \
     */                                                                                            \
    typedef struct packed {                                                                        \
        logic [bp_eaddr_width_gp-1:0]           pc;                                                \
        logic [branch_metadata_fwd_width_p-1:0] branch_metadata_fwd;                               \
        logic [`bp_fe_cmd_attaboy_padding_width-1:0]                                               \
                                                padding;                                           \
    } bp_fe_cmd_attaboy_s;                                                                         \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_pte_entry_leaf_s provides the information needed in the case of the page              \
     * walk. The bp_fe_pte_entry_leaf_s contains the physical address and the                      \
     * additional bits in the page table entry (pte).                                              \
    */                                                                                             \
    typedef struct packed {                                                                        \
        logic [paddr_width_p-1:0] paddr;                                                           \
        logic                     extent;                                                          \
        logic                     u;                                                               \
        logic                     g;                                                               \
        logic                     l;                                                               \
        logic                     x;                                                               \
    } bp_fe_pte_entry_leaf_s;                                                                      \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_itlb_map_s provides the virtual, physical translation plus the                    \
     * additional permission bits to the itlb in the case of page walk. Once the                   \
     * frontend sends the page fill request to the backend, the backend performs the               \
     * page walk, and responds to the frontend with bp_fe_cmd_itlb_map_s.                          \
    */                                                                                             \
    typedef struct packed {                                                                        \
        logic [vaddr_width_p-1:0] vaddr;                                                           \
        bp_fe_pte_entry_leaf_s    pte_entry_leaf;                                                  \
        logic [`bp_fe_cmd_itlb_map_padding_width-1:0]                                              \
                                  padding;                                                         \
    } bp_fe_cmd_itlb_map_s;                                                                        \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_itlb_fence_s consists of virtual address, asid, and flags for whether to flush    \
     * all addresses and/or all asids. In the case of context switch, the itlb will perform itlb   \
     * fence according to the asid.                                                                \
    */                                                                                             \
    typedef struct packed {                                                                        \
        logic [vaddr_width_p-1:0] vaddr;                                                           \
        logic [asid_width_p-1:0]  asid;                                                            \
        logic                     flush_all_addresses;                                             \
        logic                     flush_all_asid;                                                  \
        logic [`bp_fe_cmd_itlb_fence_padding_width-1:0]                                            \
                                  padding;                                                         \
    } bp_fe_cmd_itlb_fence_s;                                                                      \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_s is the information backend provides to the frontend in the case of              \
     * misprediction.  It contains the branch_metadata_fwd information and                         \
     * misprediction reason. The BE does not examine the branch metadata, but does                 \
     * supply the misprediction reason.                                                            \
     * NOTE: VCS can only handle packed unions where each member is the same size                  \
     */                                                                                            \
    typedef struct packed {                                                                        \
        bp_fe_command_queue_opcodes_e                 opcode;                                      \
        union packed {                                                                             \
            bp_fe_cmd_pc_redirect_operands_s              pc_redirect_operands;                    \
            bp_fe_cmd_attaboy_s                           attaboy;                                 \
            bp_fe_cmd_itlb_map_s                          itlb_fill_response;                      \
            bp_fe_cmd_itlb_fence_s                        itlb_fence;                              \
        } operands;                                                                                \
     } bp_fe_cmd_s;                                                                                \

/*
 * bp_fe_queue_s can either contain an instruction or exception.
 * bp_fe_queue_type_e specifies which information it contains.
 */
typedef enum bit {
    e_fe_fetch       = 0
    ,e_fe_exception  = 1
} bp_fe_queue_type_e;

/*
 * bp_fe_command_queue_opcodes_e defines the opcodes from backend to frontend in
 * the cases of an exception. bp_fe_command_queue_opcodes_e explains the reason
 * of why pc is redirected.
 * e_op_state_reset is used after the reset, which flushes all the states.
 * e_op_pc_redirection defines the changes of PC, which happens during the branches.
 * e_op_icache_fence happens when there is flush in the icache.
 * e_op_attaboy informs the frontend that the prediction is correct.
 * e_op_itlb_fill_response happens when itlb populates translation.
 * e_op_itlb_fence issues a fence operation to itlb.
 */
typedef enum bit[2:0] {
    e_op_state_reset
    ,e_op_pc_redirection
    ,e_op_interrupt
    ,e_op_icache_fence
    ,e_op_attaboy
    ,e_op_itlb_fill_response
    ,e_op_itlb_fence
} bp_fe_command_queue_opcodes_e;

/*
 * bp_fe_misprediction_reason_e is the misprediction reason provided by the backend.
 */
typedef enum bit {
    e_incorrect_prediction = 0
    ,e_not_a_branch        = 1
} bp_fe_misprediction_reason_e;

/*
 * The exception code types. e_instr_addr_misaligned is when the instruction
 * addresses are not aligned. e_itlb_miss is when the instruction has a miss in
 * the iTLB. ITLB misses can cause the instruction misaligned. Thus the frontend
 * detects the instruction miss first and then detect whether there is an ITLB
 * miss. e_instruction_access_fault is when the access control is violated.
 * e_illegal_instruction is when the instruction is not legitimate.
 */
typedef enum bit[1:0] {
    e_instr_addr_misaligned     = 0
    ,e_itlb_miss                = 1
    ,e_instruction_access_fault = 2
    ,e_illegal_instruction      = 3
} bp_fe_exception_code_e;

/*
 * bp_fe_command_queue_subopcodes_e defines the subopcodes in the case of pc_redirection in
 * bp_fe_command_queue_opcodes_e. It provides the reasons of why pc are redirected.
 * e_subop_uret,sret,mret are the returns from trap and contain the pc where it returns.
 * e_subop_interrupt is no-fault pc redirection.
 * e_subop_branch_mispredict is at-fault PC redirection.
 * e_subop_trap is at-fault PC redirection. It will changes the permission bits.
 * e_subop_context_switch is no-fault PC redirection. It redirect pc to a new address space.
*/
typedef enum bit [2:0] {
    e_subop_uret
    ,e_subop_sret
    ,e_subop_mret
    ,e_subop_interrupt
    ,e_subop_branch_mispredict
    ,e_subop_trap
    ,e_subop_context_switch
} bp_fe_command_queue_subopcodes_e;

/* Declare width macros so that clients can use structs in ports before struct declaration */
`define bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)                               \
    ($bits(bp_fe_queue_type_e)                                                                     \
     +`bp_fe_queue_msg_u_width(vaddr_width_p,branch_metadata_fwd_width_p))

`define bp_fe_fetch_width(vaddr_width_p,branch_metadata_fwd_width_p)                               \
    (`bp_fe_queue_msg_u_width(vaddr_width_p,branch_metadata_fwd_width_p))

`define bp_fe_exception_width(vaddr_width_p,branch_metadata_fwd_width_p)                           \
    (`bp_fe_queue_msg_u_width(vaddr_width_p,branch_metadata_fwd_width_p))

`define bp_fe_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p)      \
    ($bits(bp_fe_command_queue_opcodes_e)                                                          \
     +`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                         \
                                  ,branch_metadata_fwd_width_p))                                   \

`define bp_fe_cmd_pc_redirect_operands_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)

`define bp_fe_cmd_attaboy_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)

`define bp_fe_cmd_itlb_map_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)

`define bp_fe_pte_entry_leaf_width(paddr_width_p)                                                  \
    (paddr_width_p+5*1)

`define bp_fe_cmd_itlb_fence_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)

/* Ensure all members of packed unions have the same size */
`define bp_fe_fetch_width_no_padding(branch_metadata_fwd_width_p)                                  \
    (bp_eaddr_width_gp+bp_instr_width_gp+branch_metadata_fwd_width_p)

`define bp_fe_exception_width_no_padding(vaddr_width_p)                                            \
    (vaddr_width_p+$bits(bp_fe_exception_code_e))

`define bp_fe_queue_msg_u_width(vaddr_width_p,branch_metadata_fwd_width_p)                         \
    (1+`BSG_MAX(`bp_fe_fetch_width_no_padding(branch_metadata_fwd_width_p)                         \
                ,`bp_fe_exception_width_no_padding(vaddr_width_p)))

`define bp_fe_fetch_padding_width                                                                  \
    (`bp_fe_queue_msg_u_width(vaddr_width_p,branch_metadata_fwd_width_p)                           \
     -`bp_fe_fetch_width_no_padding(branch_metadata_fwd_width_p))

`define bp_fe_exception_padding_width                                                              \
    (`bp_fe_queue_msg_u_width(vaddr_width_p,branch_metadata_fwd_width_p)                           \
     -`bp_fe_exception_width_no_padding(vaddr_width_p))

`define bp_fe_cmd_pc_redirect_operands_width_no_padding(branch_metadata_fwd_width_p)               \
    (bp_eaddr_width_gp+$bits(bp_fe_command_queue_subopcodes_e)                                     \
     +branch_metadata_fwd_width_p+$bits(bp_fe_misprediction_reason_e)+1)

`define bp_fe_cmd_attaboy_width_no_padding(branch_metadata_fwd_width_p)                            \
    (bp_eaddr_width_gp+branch_metadata_fwd_width_p)

`define bp_fe_cmd_itlb_map_width_no_padding(vaddr_width_p,paddr_width_p)                           \
    (vaddr_width_p+`bp_fe_pte_entry_leaf_width(paddr_width_p))

`define bp_fe_cmd_itlb_fence_width_no_padding(vaddr_width_p,asid_width_p)                          \
    (vaddr_width_p+asid_width_p+2*1)

`define bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    (1+`BSG_MAX(`bp_fe_cmd_pc_redirect_operands_width_no_padding(branch_metadata_fwd_width_p)      \
                ,`BSG_MAX(`bp_fe_cmd_attaboy_width_no_padding(branch_metadata_fwd_width_p)         \
                          ,`BSG_MAX(`bp_fe_cmd_itlb_map_width_no_padding(vaddr_width_p             \
                                                                         ,paddr_width_p)           \
                                    ,`bp_fe_cmd_itlb_fence_width_no_padding(vaddr_width_p          \
                                                                            ,asid_width_p)))))

`define bp_fe_cmd_pc_redirect_operands_padding_width                                               \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)                                     \
     -`bp_fe_cmd_pc_redirect_operands_width_no_padding(branch_metadata_fwd_width_p))

`define bp_fe_cmd_attaboy_padding_width                                                            \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)                                     \
     -`bp_fe_cmd_attaboy_width_no_padding(branch_metadata_fwd_width_p))

`define bp_fe_cmd_itlb_map_padding_width                                                           \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)                                     \
     -`bp_fe_cmd_itlb_map_width_no_padding(vaddr_width_p,paddr_width_p))

`define bp_fe_cmd_itlb_fence_padding_width                                                         \
    (`bp_fe_cmd_operands_u_width(vaddr_width_p,paddr_width_p,asid_width_p                          \
                                 ,branch_metadata_fwd_width_p)                                     \
     -`bp_fe_cmd_itlb_fence_width_no_padding(vaddr_width_p,asid_width_p))

`endif

