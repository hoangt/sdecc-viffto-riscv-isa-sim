//Author: Mark Gottscho
//Email: mgottscho@ucla.edu

#include "sdecc.h"
#include <iostream> //MWG
#include <bitset> //MWG
#include <sstream> //MWG
#include <string> //MWG
#include <iomanip> //MWG
#include <stdexcept> //MWG
#include <memory> //MWG

std::string myexec(std::string cmd) {
    char buffer[128];
    std::string result = "";
    std::shared_ptr<FILE> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) throw std::runtime_error("popen() failed!");
    while (!feof(pipe.get())) {
        if (fgets(buffer, 128, pipe.get()) != NULL)
            result += buffer;
    }
    return result;
}

std::string construct_sdecc_recovery_cmd(std::string script_filename, uint8_t correct_quadword[8], size_t words_per_block, uint8_t cacheline[64], unsigned position_in_cacheline) {
    std::string cmd = script_filename + " ";
    for (size_t i = 0; i < sizeof(uint64_t); i++) {
      cmd += std::bitset<8>(correct_quadword[i]).to_string();
    }
    cmd += " ";
    for (size_t i = 0; i < words_per_block; i++) {
      for (size_t j = 0; j < sizeof(uint64_t); j++) {
          cmd += std::bitset<8>(cacheline[i*sizeof(uint64_t)+j]).to_string();
      }
      if (i < words_per_block-1)
          cmd += ",";
    }
    cmd += " " + std::to_string(position_in_cacheline);
    std::cout << "Cmd: " << cmd << std::endl;
    return cmd;
}
