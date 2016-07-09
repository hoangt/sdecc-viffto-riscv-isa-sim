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
#include "cachesim.h" //MWG

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
  fprintf(stderr, "  --memdatatrace=<begin>:<end>:<interval>:<output_file>    MWG: Enable tracing of raw memory traffic data payloads starting from step begin, until step end, with interval accesses between trace points. Dump to output_file.\n"); //MWG
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
  bool memdatatrace_en = false; //MWG
  size_t memdatatrace_step_begin = 0; //MWG
  size_t memdatatrace_step_end = static_cast<size_t>(-1); //MWG
  size_t memdatatrace_sample_interval = 1; //MWG
  std::string memdatatrace_output_filename = "spike_mem_data_trace.txt"; //MWG

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
  parser.option(0, "memdatatrace", 1, [&](const char* s){
      memdatatrace_en = true;
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

  s.set_debug(debug);
  s.set_log(log);
  s.set_histogram(histogram);

  //MWG
  if (memdatatrace_en) {
      s.enable_memdatatrace();
      s.set_memdatatrace_step_begin(memdatatrace_step_begin);
      s.set_memdatatrace_step_end(memdatatrace_step_end);
      s.set_memdatatrace_sample_interval(memdatatrace_sample_interval);
  }

  bool retval = s.run(); //MWG
  if (output_file.is_open()) //MWG
      output_file.close(); //MWG
  return retval; //MWG
}
