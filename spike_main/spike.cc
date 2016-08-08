// See LICENSE for license details.

#include "sim.h"
#include "htif.h"
#include "cachesim.h"
#include "extension.h"
#include <dlfcn.h>
#include <fesvr/option_parser.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <vector>
#include <string>
#include <memory>
#include <cstdlib> //MWG for srand(), rand()
#include <time.h> //MWG for time()
#include "cachesim.h" //MWG
#include "swd_ecc.h" //MWG

static void help()
{
  fprintf(stderr, "usage: spike [host options] <target program> [target options]\n");
  fprintf(stderr, "Host Options:\n");
  fprintf(stderr, "  -p<n>              Simulate <n> processors [default 1]\n");
  fprintf(stderr, "  -m<n>              Provide <n> MiB of target memory [default 4096]\n");
  fprintf(stderr, "  -d                 Interactive debug mode\n");
  fprintf(stderr, "  -g                 Track histogram of PCs\n");
  fprintf(stderr, "  -l                 Generate a log of execution\n");
  fprintf(stderr, "  -h                 Print this help message\n");
  fprintf(stderr, "  --isa=<name>       RISC-V ISA string [default RV64IMAFDC]\n");
  fprintf(stderr, "  --ic=<S>:<W>:<B>   Instantiate a cache model with S sets,\n");
  fprintf(stderr, "  --dc=<S>:<W>:<B>     W ways, and B-byte blocks (with S and\n");
  fprintf(stderr, "  --l2=<S>:<W>:<B>     B both powers of 2).\n");
  fprintf(stderr, "  --extension=<name> Specify RoCC Extension\n");
  fprintf(stderr, "  --extlib=<name>    Shared library to load\n");
  fprintf(stderr, "  --periodicmemdatatrace=<begin>:<end>:<interval>:<output_file>    MWG: Enable periodic tracing of raw memory traffic data payloads starting from step begin, until step end, with interval accesses between trace points. Dump to output_file.\n"); //MWG
  fprintf(stderr, "  --randmemdatatrace=<recip_sampl_prob_per_step>:<output_file>    MWG: Enable random tracing of raw memory traffic data payloads. Each simulation step has a probability of a trace sample being taken that is the reciprocal of the input value. The expected number of steps between samples is governed by the geometric distribution. Dump to output_file.\n"); //MWG
  fprintf(stderr, "  --memwordsize=<value>     MWG: Specify the bit width of the memory bus that carries information bits. This can either be 4 or 8 bytes.");
  fprintf(stderr, "  --faultinj=<step>:<target>:<n>:<k>:<bitpos0>:<bitpos1>     MWG: Enable fault injection and SWD-ECC testing. Inject at specified step, if the execution has not already completed. Target is either inst or data memory. If data memory, the first memory load after the step has been reached will be used. bitpos0 is the first bitflip in the codeword, bitpos1 is the second bitflip in the codeword. ecc code can be hsiao1970 or davydov1991. n, k correspond to ecc parameters."); //MWG
  exit(1);
}

int main(int argc, char** argv)
{
  bool debug = false;
  bool histogram = false;
  bool log = false;
  size_t nprocs = 1;
  size_t mem_mb = 0;
  std::unique_ptr<icache_sim_t> ic;
  std::unique_ptr<dcache_sim_t> dc;
  std::unique_ptr<cache_sim_t> l2;
  std::function<extension_t*()> extension;
  const char* isa = "RV64";

  //MWG: init stuff to default values
  bool memdatatrace_en = false; //MWG
  bool rand_memdatatrace = false; //MWG
  size_t memdatatrace_step_begin = 0; //MWG
  size_t memdatatrace_step_end = static_cast<size_t>(-1); //MWG
  size_t memdatatrace_sample_interval = 1; //MWG
  size_t memdatatrace_rand_prob_recip = 1; //MWG 
  uint32_t memwordsize = 8; //MWG
  std::string memdatatrace_output_filename = "spike_mem_data_trace.txt"; //MWG
  bool err_inj_enable = false; //MWG
  size_t err_inj_step = 0; //MWG
  err_inj_targets_t err_inj_target = ERR_INJ_INST_MEM; //MWG
  uint32_t n = 72; //MWG
  uint32_t k = 64; //MWG
  ecc_codes_t ecc_code = HSIAO_CODE; //MWG
  uint32_t err_inj_bitpos0 = 0; //MWG
  uint32_t err_inj_bitpos1 = 1; //MWG
  uint32_t words_per_block = 1; //MWG

  option_parser_t parser;
  parser.help(&help);
  parser.option('h', 0, 0, [&](const char* s){help();});
  parser.option('d', 0, 0, [&](const char* s){debug = true;});
  parser.option('g', 0, 0, [&](const char* s){histogram = true;});
  parser.option('l', 0, 0, [&](const char* s){log = true;});
  parser.option('p', 0, 1, [&](const char* s){nprocs = atoi(s);});
  parser.option('m', 0, 1, [&](const char* s){mem_mb = atoi(s);});
  parser.option(0, "ic", 1, [&](const char* s){ic.reset(new icache_sim_t(s));});
  parser.option(0, "dc", 1, [&](const char* s){dc.reset(new dcache_sim_t(s));});
  parser.option(0, "l2", 1, [&](const char* s){l2.reset(cache_sim_t::construct(s, "L2$"));});
  parser.option(0, "isa", 1, [&](const char* s){isa = s;});
  parser.option(0, "extension", 1, [&](const char* s){extension = find_extension(s);});
  parser.option(0, "extlib", 1, [&](const char *s){
    void *lib = dlopen(s, RTLD_NOW | RTLD_GLOBAL);
    if (lib == NULL) {
      fprintf(stderr, "Unable to load extlib '%s': %s\n", s, dlerror());
      exit(-1);
    }
  });
  //MWG
  parser.option(0, "periodicmemdatatrace", 1, [&](const char* s){
      memdatatrace_en = true;
      rand_memdatatrace = false;
      const char* tmp = strchr(s, ':');
      memdatatrace_step_begin = atoi(std::string(s, tmp).c_str()); //FIXME: potential overflow issue
      if (!tmp++) help();
      
      const char* tmp2 = strchr(tmp, ':');
      memdatatrace_step_end = atoi(std::string(tmp, tmp2).c_str()); //FIXME: potential overflow issue
      if (!tmp2++) help();
     
      const char* tmp3 = strchr(tmp2, ':');
      memdatatrace_sample_interval = atoi(std::string(tmp2, tmp3).c_str()); //FIXME: potential overflow issue
      if (!tmp3++) help();

      memdatatrace_output_filename = std::string(tmp3);
  });
  
  //MWG
  parser.option(0, "randmemdatatrace", 1, [&](const char* s){
      memdatatrace_en = true;
      rand_memdatatrace = true;
      const char* tmp = strchr(s, ':');
      memdatatrace_rand_prob_recip = atoi(std::string(s, tmp).c_str()); //FIXME: potential overflow issue
      if (!tmp++) help();

      memdatatrace_output_filename = std::string(tmp);
  });

  //MWG
  parser.option(0, "memwordsize", 1, [&](const char* s) { 
      memwordsize = atoi(s);
      if (memwordsize != 4 && memwordsize != 8) //error
          help();
  });
  
  //MWG BEGIN
  parser.option(0, "faultinj", 1, [&](const char* s){
      err_inj_enable = true;
      const char* tmp = strchr(s, ':');
      err_inj_step = atoi(std::string(s, tmp).c_str()); //FIXME: potential overflow issue
      if (!tmp++) help();
      
      const char* tmp2 = strchr(tmp, ':');
      std::string err_inj_target_str = std::string(tmp, tmp2).c_str(); 
      if (!err_inj_target_str.compare("inst"))
            err_inj_target = ERR_INJ_INST_MEM;
      else if (!err_inj_target_str.compare("data"))
            err_inj_target = ERR_INJ_DATA_MEM;
      else //error
            help();
      if (!tmp2++) help();
     
      const char* tmp3 = strchr(tmp2, ':');
      n = atoi(std::string(tmp2, tmp3).c_str()); //FIXME: potential overflow issue
      if (!tmp3++) help();
     
      const char* tmp4 = strchr(tmp3, ':');
      k = atoi(std::string(tmp3, tmp4).c_str()); //FIXME: potential overflow issue
      if (!tmp4++) help();
     
      const char* tmp5 = strchr(tmp4, ':');
      err_inj_bitpos0 = atoi(std::string(tmp4, tmp5).c_str()); //FIXME: potential overflow issue
      if (!tmp5++) help();

      err_inj_bitpos1 = atoi(std::string(tmp5).c_str()); //FIXME: potential overflow issue

      if (err_inj_bitpos0 == err_inj_bitpos1) //error
          help();
  });
  //MWG END
  
  auto argv1 = parser.parse(argv);
  if (!*argv1)
    help();
  std::vector<std::string> htif_args(argv1, (const char*const*)argv + argc);
  sim_t s(isa, nprocs, mem_mb, htif_args);
  the_sim = &s; //MWG THIS IS DANGEROUS HACK
  
  //MWG BEGIN
  output_file.open(memdatatrace_output_filename, std::fstream::out);
  if (!output_file.is_open()) {
     std::cerr << "FAILED to open " << memdatatrace_output_filename << ". Exiting." << std::endl;
     exit(-1);
  } else {
     std::cout << "memdatatrace output file is " << memdatatrace_output_filename << std::endl;
  }
  //MWG END
  
  if (ic && l2) ic->set_miss_handler(&*l2);
  if (dc && l2) dc->set_miss_handler(&*l2);
  for (size_t i = 0; i < nprocs; i++)
  {
    if (ic) s.get_core(i)->get_mmu()->register_memtracer(&*ic);
    if (dc) s.get_core(i)->get_mmu()->register_memtracer(&*dc);
    if (extension) s.get_core(i)->register_extension(extension());
  }
  the_mmu = s.get_core(0)->get_mmu(); //MWG THIS IS DANGEROUS HACK

  //MWG BEGIN
  if (err_inj_enable) {
      words_per_block = static_cast<uint32_t>(general_linesz / memwordsize);

      the_mmu->enableErrInj(
         err_inj_step,
         err_inj_target,
         n,
         k,
         ecc_code,
         err_inj_bitpos0,
         err_inj_bitpos1,
         words_per_block);

      std::cout << "Error injection/SWD-ECC enabled!" << std::endl;
      std::cout << "...Step: " << err_inj_step << std::endl;
      std::cout << "...Target: " << err_inj_target << std::endl;
      std::cout << "...n: " << n << std::endl;
      std::cout << "...k: " << k << std::endl;
      std::cout << "...ecc code: " << ecc_code << std::endl;
      std::cout << "...bitpos 0: " << err_inj_bitpos0 << std::endl;
      std::cout << "...bitpos 1: " << err_inj_bitpos1 << std::endl;
      std::cout << "...words per block: " << words_per_block << std::endl;
  }
  //END MWG

  s.set_debug(debug);
  s.set_log(log);
  s.set_histogram(histogram);

  //MWG
  if (memdatatrace_en) {
      s.enable_memdatatrace();
      if (!rand_memdatatrace) {
          s.set_memdatatrace_rand(false);
          s.set_memdatatrace_step_begin(memdatatrace_step_begin);
          s.set_memdatatrace_step_end(memdatatrace_step_end);
          s.set_memdatatrace_sample_interval(memdatatrace_sample_interval);
      } else {
          srand(time(NULL)); //MWG
          s.set_memdatatrace_rand(true);
          s.set_memdatatrace_rand_prob_recip(memdatatrace_rand_prob_recip);
      }
  }
  s.set_memwordsize(memwordsize); //MWG

  bool retval = s.run(); //MWG
  if (output_file.is_open()) //MWG
      output_file.close(); //MWG
  return retval; //MWG
}
