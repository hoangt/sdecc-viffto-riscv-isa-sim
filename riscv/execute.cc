// See LICENSE for license details.

#include "processor.h"
#include "mmu.h"
#include "cachesim.h" //MWG HACK
#include <cassert>

extern size_t total_steps; //MWG

static void commit_log_stash_privilege(state_t* state)
{
#ifdef RISCV_ENABLE_COMMITLOG
  state->last_inst_priv = get_field(state->mstatus, MSTATUS_PRV);
#endif
}

static void commit_log_print_insn(state_t* state, reg_t pc, insn_t insn)
{
#ifdef RISCV_ENABLE_COMMITLOG
  int32_t priv = state->last_inst_priv;
  uint64_t mask = (insn.length() == 8 ? uint64_t(0) : (uint64_t(1) << (insn.length() * 8))) - 1;
  if (state->log_reg_write.addr) {
    fprintf(stderr, "%1d 0x%016" PRIx64 " (0x%08" PRIx64 ") %c%2" PRIu64 " 0x%016" PRIx64 "\n",
            priv,
            pc,
            insn.bits() & mask,
            state->log_reg_write.addr & 1 ? 'f' : 'x',
            state->log_reg_write.addr >> 1,
            state->log_reg_write.data);
  } else {
    fprintf(stderr, "%1d 0x%016" PRIx64 " (0x%08" PRIx64 ")\n", priv, pc, insn.bits() & mask);
  }
  state->log_reg_write.addr = 0;
#endif
}

inline void processor_t::update_histogram(reg_t pc)
{
#ifdef RISCV_ENABLE_HISTOGRAM
  pc_histogram[pc]++;
#endif
}

static reg_t execute_insn(processor_t* p, reg_t pc, insn_fetch_t fetch)
{
  commit_log_stash_privilege(p->get_state());
  reg_t npc = fetch.func(p, fetch.insn, pc);
  if (npc != PC_SERIALIZE) {
    commit_log_print_insn(p->get_state(), pc, fetch.insn);
    p->update_histogram(pc);
  }
  return npc;
}

// fetch/decode/execute loop
void processor_t::step(size_t n)
{
  while (run && n > 0) {
    size_t instret = 0;
    reg_t pc = state.pc;
    mmu_t* _mmu = mmu;

    #define advance_pc() \
     if (unlikely(pc == PC_SERIALIZE)) { \
       pc = state.pc; \
       state.serialized = true; \
       break; \
     } else { \
       state.pc = pc; \
       instret++; \
     }

    try
    {
      check_timer();
      take_interrupt();

      if (unlikely(debug))
      {
        while (instret < n)
        {
          //MWG: error injection armed on inst fetch
          if (likely(mmu->err_inj_enable) && mmu->err_inj_target.compare("inst") == 0 && total_steps >= mmu->err_inj_step) {
              mmu->inject_error_now = true;
              //std::cout << "ERROR INJECTION ARMED for instruction memory on step " << the_sim->total_steps << "." << std::endl;
              std::cout << "ERROR INJECTION ARMED for instruction memory on step " << total_steps << "." << std::endl;
          }

          insn_fetch_t fetch = mmu->load_insn(pc); //MWG: if error injection is armed, this will be the victim memory access.
          
          if (unlikely(mmu->inject_error_now)) {
              std::cout << "ERROR INJECTION COMPLETED, now disarmed. It should have affected instruction memory access." << std::endl;
              mmu->inject_error_now = false; //MWG: Disarm
              mmu->err_inj_enable = false; //MWG: Disarm
          }

          if (!state.serialized)
            disasm(fetch.insn);
          pc = execute_insn(this, pc, fetch);
          advance_pc();
        }
      }
      else while (instret < n)
      {
        //MWG: error injection armed on inst fetch
        if (likely(mmu->err_inj_enable) && mmu->err_inj_target.compare("inst") == 0 && total_steps >= mmu->err_inj_step) {
            mmu->inject_error_now = true;
            std::cout << "ERROR INJECTION ARMED for instruction memory on step " << total_steps << "." << std::endl;
        }

        //MWG: check for err inj step here
        size_t idx = _mmu->icache_index(pc);
        auto ic_entry = _mmu->access_icache(pc);
          
        if (unlikely(mmu->inject_error_now)) {
            std::cout << "ERROR INJECTION COMPLETED, now disarmed. It should have affected instruction memory access." << std::endl;
            mmu->inject_error_now = false; //MWG: Disarm
            mmu->err_inj_enable = false; //MWG: Disarm
        }

        #define ICACHE_ACCESS(i) { \
          insn_fetch_t fetch = ic_entry->data; \
          ic_entry++; \
          pc = execute_insn(this, pc, fetch); \
          if (i == mmu_t::ICACHE_ENTRIES-1) break; \
          if (unlikely(ic_entry->tag != pc)) goto miss; \
          if (unlikely(instret+1 == n)) break; \
          instret++; \
          state.pc = pc; \
        }

        switch (idx) {
          #include "icache.h"
        }

        advance_pc();
        continue;

miss:
        advance_pc();
        // refill I$ if it looks like there wasn't a taken branch
        if (pc > (ic_entry-1)->tag && pc <= (ic_entry-1)->tag + MAX_INSN_LENGTH)
          _mmu->refill_icache(pc, ic_entry);
      }
    }
    //Begin MWG
    catch(trap_memory_due& t) {
        take_trap(t, pc);

        if (pb.rdy) {
            std::cerr << "Abort! memory DUE trap handler completed without clearing Penalty Box RDY bit" << std::endl;
            exit(-1);
        }

        if (!pb.mem_due_load_type.compare("int64") || !pb.mem_due_load_type.compare("uint64")) {
            uint64_t value = *((uint64_t*)(pb.victim_msg+pb.msg_offset));
            if (pb.mem_due_dest_reg_type) //int
                state.XPR.write(pb.mem_due_dest_reg, value);
            else //float
                state.FPR.write(pb.mem_due_dest_reg, value);
        } else if (!pb.mem_due_load_type.compare("int32") || !pb.mem_due_load_type.compare("uint32")) {
            uint32_t value = *((uint32_t*)(pb.victim_msg+pb.msg_offset));
            if (pb.mem_due_dest_reg_type) //int
                state.XPR.write(pb.mem_due_dest_reg, value);
            else //float
                state.FPR.write(pb.mem_due_dest_reg, value);
        } else if (!pb.mem_due_load_type.compare("int16") || !pb.mem_due_load_type.compare("uint16")) {
            uint16_t value = *((uint16_t*)(pb.victim_msg+pb.msg_offset));
            if (pb.mem_due_dest_reg_type) //int
                state.XPR.write(pb.mem_due_dest_reg, value);
            else //float
                state.FPR.write(pb.mem_due_dest_reg, value);
        } else if (!pb.mem_due_load_type.compare("int8") || !pb.mem_due_load_type.compare("uint8")) {
            uint8_t value = *((uint8_t*)(pb.victim_msg+pb.msg_offset));
            if (pb.mem_due_dest_reg_type) //int
                state.XPR.write(pb.mem_due_dest_reg, value);
            else //float
                state.FPR.write(pb.mem_due_dest_reg, value);
        } else {
            std::cerr << "ERROR! Unknown type of memory load that suffered DUE" << std::endl;
            exit(-1);
        }

    }
    //End MWG
    catch(trap_t& t)
    {
      take_trap(t, pc);
    }

    state.minstret += instret;
    n -= instret;
  }
}
