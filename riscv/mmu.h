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
#include <iostream> //MWG
#include <iomanip> //MWG
#include <cstdio> //MWG
#include <memory> //MWG
#include <stdexcept> //MWG
#include <string> //MWG
#include <sstream> //MWG
#include <bitset> //MWG
#include "cachesim.h" //MWG
#include "sdecc.h" //MWG

extern size_t total_steps; //MWG

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
    type##_t load_##type(reg_t addr, bool fpunit) __attribute__((always_inline)) { \
      if (addr & (sizeof(type##_t)-1)) \
        throw trap_load_address_misaligned(addr); \
      reg_t vpn = addr >> PGSHIFT; \
      type##_t correct_retval; \
      type##_t retval; \
      if (likely(tlb_load_tag[vpn % TLB_ENTRIES] == vpn)) { \
        correct_retval = *(type##_t*)(tlb_data[vpn % TLB_ENTRIES] + addr); \
      } else { \
          load_slow_path(addr, sizeof(type##_t), (uint8_t*)&correct_retval, fpunit); \
      } \
      if (likely(err_inj_enable) && err_inj_target.compare("data") == 0 && total_steps >= err_inj_step) { \
          inject_error_now = true; \
          std::cout << "ERROR INJECTION ARMED for data memory on step " << total_steps << "." << std::endl; \
      } \
      if (unlikely(inject_error_now) && err_inj_target.compare("data") == 0) { \
          uint8_t correct_word[memwordsize]; \
          reg_t paddr = translate(addr, LOAD); \
          uint8_t cacheline[words_per_block*memwordsize]; \
          unsigned position_in_cacheline = (paddr & (memwordsize*words_per_block-1)) / memwordsize; \
          memcpy(correct_word, reinterpret_cast<char*>(reinterpret_cast<reg_t>(mem+(paddr & (~(memwordsize-1))))), memwordsize); \
          memcpy(cacheline, reinterpret_cast<char*>(reinterpret_cast<reg_t>(mem+(paddr & (~(words_per_block*memwordsize-1))))), words_per_block*memwordsize); \
          \
          std::cout.fill('0'); \
          std::cout << "Injecting DUE on data!" << std::endl; \
          setPenaltyBox(proc, correct_word, cacheline, memwordsize, words_per_block, position_in_cacheline); \
          std::cout << "Correct return value is 0x" \
                    << std::hex \
                    << std::setw(sizeof(type##_t)*2) \
                    << correct_retval \
                    << ", correct message is 0x"; \
          for (size_t i = 0; i < memwordsize; i++) { \
              std::cout << std::hex \
                        << std::setw(2) \
                        << static_cast<uint64_t>(correct_word[i]); \
          } \
          std::cout << "." << std::dec << std::endl; \
          \
          /*std::cout << "Quadword/message is block number " \
                    << std::dec \
                    << position_in_cacheline \
                    << " in: "; \
          for (size_t i = 0; i < words_per_block; i++) { \
              for (size_t j = 0; j < 8; j++) { \
                  std::cout << std::hex \
                            << std::setw(2) \
                            << static_cast<uint64_t>(cacheline[i*8+j]); \
              } \
              if (i < words_per_block-1) \
                  std::cout << ","; \
          } \
          std::cout << "." << std::dec << std::endl; \
          */\
          inject_error_now = false; \
          err_inj_enable = false; \
          std::cout << "ERROR INJECTION COMPLETED, now disarmed. It should affect data memory access." << std::endl; \
          throw trap_memory_due(addr); \
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
    void store_##type(reg_t addr, type##_t val, bool fpunit) { \
      if (addr & (sizeof(type##_t)-1)) \
        throw trap_store_address_misaligned(addr); \
      reg_t vpn = addr >> PGSHIFT; \
      if (likely(tlb_store_tag[vpn % TLB_ENTRIES] == vpn)) \
        *(type##_t*)(tlb_data[vpn % TLB_ENTRIES] + addr) = val; \
      else \
        store_slow_path(addr, sizeof(type##_t), (const uint8_t*)&val, fpunit); \
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
    if (unlikely(inject_error_now) && err_inj_target.compare("inst") == 0) {
        std::cout.fill('0');
        std::cout << "Injecting DUE on instruction! Correct message is 0x"
                  << std::hex
                  << std::setw(8)
                  << (insn & 0x00000000FFFFFFFF) //FIXME: we just mask out upper 32-bits, we are assuming RV64G only here
                  << "."
                  << std::dec
                  << std::endl;
    
        /* Construct command line */
        std::string cmd = inst_sdecc_script_filename + " " + std::bitset<32>(insn).to_string();
        std::cout << "Cmd: " << cmd << std::endl;
        std::string script_stdout = myexec(cmd);    
        std::cout << "Raw script stdout: " << script_stdout << std::endl;
        
        /* Parse recovery */
        insn_bits_t recovered_message = 0; 

        /* Output is expected to be simply a k-bit message in binary characters, e.g. '001010100101001...001010' */
        for (size_t i = 0; i < 32; i++) //FIXME
            recovered_message |= (script_stdout[i] == '1' ? (1 << (32-i-1)) : 0);

        std::cout << "Recovered message: 0x"
                  << std::hex
                  << std::setw(8)
                  << (recovered_message & 0x00000000FFFFFFFF)
                  << std::dec;

        if (insn == recovered_message)
            std::cout << " is correct!" << std::endl;
        else
            std::cout << " is CORRUPT!" << std::endl;

        insn = recovered_message;
    }
    //MWG END

    insn_fetch_t fetch = {proc->decode_insn(insn), insn};
    entry->tag = addr;
    entry->data = fetch;

    reg_t paddr = (const char*)iaddr - mem;
    if (tracer.interested_in_range(paddr, paddr + 1, FETCH)) {
      entry->tag = -1;
      tracer.trace(paddr, length, FETCH, false); //MWG
    }
    return entry;
  }

  inline icache_entry_t* access_icache(reg_t addr)
  {
    icache_entry_t* entry = &icache[icache_index(addr)];
    if (likely(entry->tag == addr) && likely(!inject_error_now)) //MWG: if we are injecting a fault this access, don't use the fast path. use slow refill_icache() path.
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
    size_t err_inj_step_start,
    size_t err_inj_step_stop,
    std::string err_inj_target,
    std::string data_sdecc_script_filename,
    std::string inst_sdecc_script_filename,
    std::string candidates_sdecc_script_filename,
    uint32_t words_per_block,
    uint32_t memwordsize
    );
  bool errInjMode() { return err_inj_mode; } //MWG
  
  bool err_inj_mode; //MWG
  bool err_inj_enable; //MWG
  size_t err_inj_step_start; //MWG
  size_t err_inj_step_stop; //MWG
  size_t err_inj_step; //MWG
  std::string err_inj_target; //MWG
  
  void load_slow_path(reg_t addr, reg_t len, uint8_t* bytes, bool fpunit); //MWG
  void store_slow_path(reg_t addr, reg_t len, const uint8_t* bytes, bool fpunit); //MWG
  std::string data_sdecc_script_filename; //MWG
  std::string inst_sdecc_script_filename; //MWG
  std::string candidates_sdecc_script_filename; //MWG
  uint32_t words_per_block; //MWG
  uint32_t memwordsize; //MWG

  reg_t translate(reg_t addr, access_type type); //MWG

private:
  char* mem;
  size_t memsz;
  processor_t* proc;
  memtracer_list_t tracer;

  bool inject_error_now; //MWG

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
  bool get_page_permissions(reg_t addr, bool& ur, bool& uw, bool& ux, bool& sr, bool& sw, bool& sx); //MWG

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
