// See LICENSE for license details.

#include "cachesim.h"
#include "common.h"
#include <cstdlib>
#include <iostream> //MWG
#include <fstream> //MWG
#include <iomanip> //MWG

#include "mmu.h" //MWG
#include "sim.h" //MWG

//MWG BEGIN
mmu_t* the_mmu;
sim_t* the_sim;
size_t general_linesz;
std::fstream output_file;
size_t total_steps = 0; //MWG
//MWG END

cache_sim_t::cache_sim_t(size_t _sets, size_t _ways, size_t _linesz, const char* _name)
 : sets(_sets), ways(_ways), linesz(_linesz), name(_name)
{
  init();
}

static void help()
{
  std::cerr << "Cache configurations must be of the form" << std::endl;
  std::cerr << "  sets:ways:blocksize" << std::endl;
  std::cerr << "where sets, ways, and blocksize are positive integers, with" << std::endl;
  std::cerr << "sets and blocksize both powers of two and blocksize at least 8." << std::endl;
  exit(1);
}

cache_sim_t* cache_sim_t::construct(const char* config, const char* name)
{
  const char* wp = strchr(config, ':');
  if (!wp++) help();
  const char* bp = strchr(wp, ':');
  if (!bp++) help();

  size_t sets = atoi(std::string(config, wp).c_str());
  size_t ways = atoi(std::string(wp, bp).c_str());
  size_t linesz = atoi(bp);

  general_linesz = linesz; //MWG HACK

  if (ways > 4 /* empirical */ && sets == 1)
    return new fa_cache_sim_t(ways, linesz, name);
  return new cache_sim_t(sets, ways, linesz, name);
}

void cache_sim_t::init()
{
  if(sets == 0 || (sets & (sets-1)))
    help();
  if(linesz < 8 || (linesz & (linesz-1)))
    help();

  idx_shift = 0;
  for (size_t x = linesz; x>1; x >>= 1)
    idx_shift++;

  tags = new uint64_t[sets*ways]();
  read_accesses = 0;
  read_misses = 0;
  bytes_read = 0;
  write_accesses = 0;
  write_misses = 0;
  bytes_written = 0;
  writebacks = 0;

  miss_handler = NULL;
}

cache_sim_t::cache_sim_t(const cache_sim_t& rhs)
 : sets(rhs.sets), ways(rhs.ways), linesz(rhs.linesz),
   idx_shift(rhs.idx_shift), name(rhs.name)
{
  tags = new uint64_t[sets*ways];
  memcpy(tags, rhs.tags, sets*ways*sizeof(uint64_t));
}

cache_sim_t::~cache_sim_t()
{
  print_stats();
  delete [] tags;
}

void cache_sim_t::print_stats()
{
  if(read_accesses + write_accesses == 0)
    return;

  float mr = 100.0f*(read_misses+write_misses)/(read_accesses+write_accesses);

  std::cout << std::setprecision(3) << std::fixed;
  std::cout << name << " ";
  std::cout << "Bytes Read:            " << bytes_read << std::endl;
  std::cout << name << " ";
  std::cout << "Bytes Written:         " << bytes_written << std::endl;
  std::cout << name << " ";
  std::cout << "Read Accesses:         " << read_accesses << std::endl;
  std::cout << name << " ";
  std::cout << "Write Accesses:        " << write_accesses << std::endl;
  std::cout << name << " ";
  std::cout << "Read Misses:           " << read_misses << std::endl;
  std::cout << name << " ";
  std::cout << "Write Misses:          " << write_misses << std::endl;
  std::cout << name << " ";
  std::cout << "Writebacks:            " << writebacks << std::endl;
  std::cout << name << " ";
  std::cout << "Miss Rate:             " << mr << '%' << std::endl;
}

uint64_t* cache_sim_t::check_tag(uint64_t addr)
{
  size_t idx = (addr >> idx_shift) & (sets-1);
  size_t tag = (addr >> idx_shift) | VALID;

  for (size_t i = 0; i < ways; i++)
    if (tag == (tags[idx*ways + i] & ~DIRTY))
      return &tags[idx*ways + i];

  return NULL;
}

uint64_t cache_sim_t::victimize(uint64_t addr)
{
  size_t idx = (addr >> idx_shift) & (sets-1);
  size_t way = lfsr.next() % ways;
  uint64_t victim = tags[idx*ways + way];
  tags[idx*ways + way] = (addr >> idx_shift) | VALID;
  return victim;
}

//MWG
void cache_sim_t::memdatatrace(uint64_t addr, size_t bytes, bool store, bool fpunit, size_t accesses_since_last_sample) { 
    //Only track cache misses
    reg_t paddr;
    //if (name.compare("L2$") != 0) //skip everything except L2
        //return;

    if (store)
        paddr = the_mmu->translate(addr, STORE);
    else
        paddr = the_mmu->translate(addr, LOAD);

    bool ur,uw,ux,sr,sw,sx = false;
    bool vm_enabled = false;
    vm_enabled = the_mmu->get_page_permissions(addr,ur,uw,ux,sr,sw,sx);

    uint8_t payload[bytes];
    uint8_t cacheline[linesz];
    uint32_t memwordsize = the_sim->get_memwordsize();
    unsigned position_in_cacheline = (paddr & (linesz-1)) / memwordsize;
    memcpy(payload, reinterpret_cast<char*>(the_mmu->mem+paddr), bytes);
    memcpy(cacheline, reinterpret_cast<char*>(reinterpret_cast<reg_t>(the_mmu->mem+(paddr & (~(linesz-1))))), linesz);

    output_file.fill('0');
    output_file 
        << std::dec
        //<< static_cast<uint64_t>(the_sim->total_steps)
        << static_cast<uint64_t>(total_steps)
        << ","
        << name
        << (store ? " WR " : " RD ")
        << (store ? "to " : "fr ")
        << "MEM"
        << ","
        << (fpunit ? "FLOAT" : "INT")
        << ","
        << accesses_since_last_sample
        << ",VADDR 0x"
        << std::hex
        << std::setw(16)
        << addr
        << ",PADDR 0x"
        << std::hex
        << std::setw(16)
        << paddr
        << ",u"
        << (vm_enabled ? (ur ? "R" : "-")  : "#")
        << (vm_enabled ? (uw ? "W" : "-")  : "#")
        << (vm_enabled ? (ux ? "X" : "-")  : "#")
        << ",s"
        << (vm_enabled ? (sr ? "R" : "-")  : "#")
        << (vm_enabled ? (sw ? "W" : "-")  : "#")
        << (vm_enabled ? (sx ? "X" : "-")  : "#")
        << ","
        << std::dec
        << bytes
        << "B,"
        << "PAYLOAD 0x";
    for (size_t i = 0; i < bytes; i++) {
        output_file
            << std::hex
            << std::setw(2)
            << static_cast<uint64_t>(payload[i]);
    }
    output_file << ",BLKPOS "
        << std::dec
        << position_in_cacheline
        << ",";
  
    //Print out words in cacheline in native byte order to the architecture
    for (size_t word = 0; word < linesz/memwordsize; word++) {
        output_file << "0x";
        for (size_t i = 0; i < memwordsize; i++) {
            output_file
                << std::hex
                << std::setw(2)
                << static_cast<uint64_t>(cacheline[word*memwordsize+i]);
        }
        output_file << ",";
    }
    output_file << std::endl;
}

void cache_sim_t::access(uint64_t addr, size_t bytes, bool store, bool fpunit) //MWG
{
  static size_t memdatatrace_accesses_since_last_sample = 0;

  //MWG
  if (the_sim->memdatatrace_enabled()) {
      if (!the_sim->get_memdatatrace_rand()) {
          //if (unlikely(the_sim->total_steps >= the_sim->get_memdatatrace_step_begin()
          if (unlikely(total_steps >= the_sim->get_memdatatrace_step_begin()
              //&& the_sim->total_steps < the_sim->get_memdatatrace_step_end()
              && total_steps < the_sim->get_memdatatrace_step_end()
              && memdatatrace_accesses_since_last_sample == the_sim->get_memdatatrace_sample_interval())
          ) { 
              memdatatrace(addr,bytes,store,fpunit,memdatatrace_accesses_since_last_sample);
              memdatatrace_accesses_since_last_sample = 0;
          }
      } else if (rand() % the_sim->memdatatrace_rand_prob_recip == 0) {
          memdatatrace(addr,bytes,store,fpunit,memdatatrace_accesses_since_last_sample);
          memdatatrace_accesses_since_last_sample = 0;
      }
  }
  memdatatrace_accesses_since_last_sample++;

  store ? write_accesses++ : read_accesses++;
  (store ? bytes_written : bytes_read) += bytes;

  uint64_t* hit_way = check_tag(addr);
  if (likely(hit_way != NULL))
  {
    if (store)
      *hit_way |= DIRTY;
    return;
  }

  store ? write_misses++ : read_misses++;

  uint64_t victim = victimize(addr);

  if ((victim & (VALID | DIRTY)) == (VALID | DIRTY))
  {
    uint64_t dirty_addr = (victim & ~(VALID | DIRTY)) << idx_shift;
    if (miss_handler)
      miss_handler->access(dirty_addr, linesz, true, fpunit); //MWG
    writebacks++;
  }

  if (miss_handler)
    miss_handler->access(addr & ~(linesz-1), linesz, false, fpunit); //MWG

  if (store)
    *check_tag(addr) |= DIRTY;
}

fa_cache_sim_t::fa_cache_sim_t(size_t ways, size_t linesz, const char* name)
  : cache_sim_t(1, ways, linesz, name)
{
}

uint64_t* fa_cache_sim_t::check_tag(uint64_t addr)
{
  auto it = tags.find(addr >> idx_shift);
  return it == tags.end() ? NULL : &it->second;
}

uint64_t fa_cache_sim_t::victimize(uint64_t addr)
{
  uint64_t old_tag = 0;
  if (tags.size() == ways)
  {
    auto it = tags.begin();
    std::advance(it, lfsr.next() % ways);
    old_tag = it->second;
    tags.erase(it);
  }
  tags[addr >> idx_shift] = (addr >> idx_shift) | VALID;
  return old_tag;
}
