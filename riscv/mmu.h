// See LICENSE for license details.

#ifndef _RISCV_MMU_H
#define _RISCV_MMU_H

#include "decode.h"
#include "trap.h"
#include "common.h"
#include "config.h"
#include "processor.h"
#include "memtracer.h"
#include <stdlib.h>
#include <vector>
#include "swd_ecc.h" //MWG

// virtual memory configuration
#define PGSHIFT 12
const reg_t PGSIZE = 1 << PGSHIFT;

struct insn_fetch_t
{
  insn_func_t func;
  insn_t insn;
};

struct icache_entry_t {
  reg_t tag;
  reg_t pad;
  insn_fetch_t data;
};

// this class implements a processor's port into the virtual memory system.
// an MMU and instruction cache are maintained for simulator performance.
class mmu_t
{
public:
  mmu_t(char* _mem, size_t _memsz);
  ~mmu_t();

  // template for functions that load an aligned value from memory
  //MWG modifications: error injection for data memory only
  #define load_func(type) \
    type##_t load_##type(reg_t addr) __attribute__((always_inline)) { \
      if (addr & (sizeof(type##_t)-1)) \
        throw trap_load_address_misaligned(addr); \
      reg_t vpn = addr >> PGSHIFT; \
      type##_t correct_retval; \
      type##_t retval; \
      if (likely(tlb_load_tag[vpn % TLB_ENTRIES] == vpn)) \
        correct_retval = *(type##_t*)(tlb_data[vpn % TLB_ENTRIES] + addr); \
      else \
          load_slow_path(addr, sizeof(type##_t), (uint8_t*)&correct_retval); \
      if (unlikely(inject_error_now_) && err_inj_target_ == ERR_INJ_DATA_MEM) { \
          type##_t* tmp = reinterpret_cast<type##_t*>(swdecc_.heuristicRecovery(reinterpret_cast<char*>(&correct_retval), NULL, 0)); \
          retval = *tmp; \
          inject_error_now_ = false; \
      } else \
          retval = correct_retval; \
      return retval; \
    }

  // load value from memory at aligned address; zero extend to register width
  load_func(uint8)
  load_func(uint16)
  load_func(uint32)
  load_func(uint64)

  // load value from memory at aligned address; sign extend to register width
  load_func(int8)
  load_func(int16)
  load_func(int32)
  load_func(int64)

  // template for functions that store an aligned value to memory
  #define store_func(type) \
    void store_##type(reg_t addr, type##_t val) { \
      if (addr & (sizeof(type##_t)-1)) \
        throw trap_store_address_misaligned(addr); \
      reg_t vpn = addr >> PGSHIFT; \
      if (likely(tlb_store_tag[vpn % TLB_ENTRIES] == vpn)) \
        *(type##_t*)(tlb_data[vpn % TLB_ENTRIES] + addr) = val; \
      else \
        store_slow_path(addr, sizeof(type##_t), (const uint8_t*)&val); \
    }

  // store value to memory at aligned address
  store_func(uint8)
  store_func(uint16)
  store_func(uint32)
  store_func(uint64)

  static const reg_t ICACHE_ENTRIES = 1024;

  inline size_t icache_index(reg_t addr)
  {
    return (addr / PC_ALIGN) % ICACHE_ENTRIES;
  }

  inline icache_entry_t* refill_icache(reg_t addr, icache_entry_t* entry)
  {
    const uint16_t* iaddr = translate_insn_addr(addr);
    insn_bits_t insn = *iaddr;
    int length = insn_length(insn);

    if (likely(length == 4)) {
      if (likely(addr % PGSIZE < PGSIZE-2))
        insn |= (insn_bits_t)*(const int16_t*)(iaddr + 1) << 16;
      else
        insn |= (insn_bits_t)*(const int16_t*)translate_insn_addr(addr + 2) << 16;
    } else if (length == 2) {
      insn = (int16_t)insn;
    } else if (length == 6) {
      insn |= (insn_bits_t)*(const int16_t*)translate_insn_addr(addr + 4) << 32;
      insn |= (insn_bits_t)*(const uint16_t*)translate_insn_addr(addr + 2) << 16;
    } else {
      static_assert(sizeof(insn_bits_t) == 8, "insn_bits_t must be uint64_t");
      insn |= (insn_bits_t)*(const int16_t*)translate_insn_addr(addr + 6) << 48;
      insn |= (insn_bits_t)*(const uint16_t*)translate_insn_addr(addr + 4) << 32;
      insn |= (insn_bits_t)*(const uint16_t*)translate_insn_addr(addr + 2) << 16;
    }

    //MWG BEGIN: error injection armed here
    if (unlikely(inject_error_now_) && err_inj_target_ == ERR_INJ_INST_MEM) {
    //TODO
    }


    //MWG END

    insn_fetch_t fetch = {proc->decode_insn(insn), insn};
    entry->tag = addr;
    entry->data = fetch;

    reg_t paddr = (const char*)iaddr - mem;
    if (tracer.interested_in_range(paddr, paddr + 1, FETCH)) {
      entry->tag = -1;
      tracer.trace(paddr, length, FETCH);
    }
    return entry;
  }

  inline icache_entry_t* access_icache(reg_t addr)
  {
    icache_entry_t* entry = &icache[icache_index(addr)];
    if (likely(entry->tag == addr) && likely(!inject_error_now_)) //MWG
      return entry;
    return refill_icache(addr, entry);
  }

  inline insn_fetch_t load_insn(reg_t addr)
  {
    return access_icache(addr)->data;
  }

  void set_processor(processor_t* p) { proc = p; flush_tlb(); }

  void flush_tlb();
  void flush_icache();

  void register_memtracer(memtracer_t*);

  //MWG
  void enableErrInj(
    size_t err_inj_step,
    err_inj_targets_t err_inj_target,
    uint32_t n,
    uint32_t k,
    ecc_codes_t ecc_code,
    uint32_t err_inj_bitpos0,
    uint32_t err_inj_bitpos1,
    uint32_t words_per_block
    );
  bool errInjEnabled() { return err_inj_enable_; } //MWG

private:
  char* mem;
  size_t memsz;
  processor_t* proc;
  memtracer_list_t tracer;

  bool err_inj_enable_; //MWG
  size_t err_inj_step_; //MWG
  err_inj_targets_t err_inj_target_; //MWG
  uint32_t n_; //MWG
  uint32_t k_; //MWG
  ecc_codes_t ecc_code_; //MWG
  uint32_t err_inj_bitpos0_; //MWG
  uint32_t err_inj_bitpos1_; //MWG
  uint32_t words_per_block_; //MWG
  bool inject_error_now_; //MWG
  SwdEcc_t swdecc_; //MWG

  // implement an instruction cache for simulator performance
  icache_entry_t icache[ICACHE_ENTRIES];

  // implement a TLB for simulator performance
  static const reg_t TLB_ENTRIES = 256;
  char* tlb_data[TLB_ENTRIES];
  reg_t tlb_insn_tag[TLB_ENTRIES];
  reg_t tlb_load_tag[TLB_ENTRIES];
  reg_t tlb_store_tag[TLB_ENTRIES];

  // finish translation on a TLB miss and upate the TLB
  void refill_tlb(reg_t vaddr, reg_t paddr, access_type type);

  // perform a page table walk for a given VA; set referenced/dirty bits
  reg_t walk(reg_t addr, bool supervisor, access_type type);

  // handle uncommon cases: TLB misses, page faults, MMIO
  const uint16_t* fetch_slow_path(reg_t addr);
  void load_slow_path(reg_t addr, reg_t len, uint8_t* bytes);
  void store_slow_path(reg_t addr, reg_t len, const uint8_t* bytes);
  bool get_page_permissions(reg_t addr, bool& ur, bool& uw, bool& ux, bool& sr, bool& sw, bool& sx); //MWG
  reg_t translate(reg_t addr, access_type type);

  // ITLB lookup
  const uint16_t* translate_insn_addr(reg_t addr) __attribute__((always_inline)) {
    reg_t vpn = addr >> PGSHIFT;
    if (likely(tlb_insn_tag[vpn % TLB_ENTRIES] == vpn))
      return (uint16_t*)(tlb_data[vpn % TLB_ENTRIES] + addr);
    return fetch_slow_path(addr);
  }
  
  friend class processor_t;
  friend class cache_sim_t; //MWG
};

#endif
