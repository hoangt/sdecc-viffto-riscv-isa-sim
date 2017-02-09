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
    for (size_t i = 0; i < 8; i++) {
      cmd += std::bitset<8>(correct_quadword[i]).to_string();
    }
    cmd += " ";
    for (size_t i = 0; i < words_per_block; i++) {
      for (size_t j = 0; j < 8; j++) {
          cmd += std::bitset<8>(cacheline[i*8+j]).to_string();
      }
      if (i < words_per_block-1)
          cmd += ",";
    }
    cmd += " " + std::to_string(position_in_cacheline);
    std::cout << "Cmd: " << cmd << std::endl;
    return cmd;
}

std::string construct_sdecc_candidate_messages_cmd(std::string script_filename, uint8_t correct_quadword[8], int n, int k, std::string code_type, int verbose) {
    std::string cmd = script_filename + " ";
    for (size_t i = 0; i < 8; i++) {
      cmd += std::bitset<8>(correct_quadword[i]).to_string();
    }
    cmd += " ";
    cmd += std::to_string(n);
    cmd += " ";
    cmd += std::to_string(k);
    cmd += " ";
    cmd += code_type;
    cmd += std::to_string(verbose);
    std::cout << "Cmd: " << cmd << std::endl;
    return cmd;
}

void parse_sdecc_recovery_output(std::string script_stdout, uint8_t recovered_quadword[8], const uint8_t correct_quadword[8]) {
      // Output is expected to be simply a 64-bit message in binary characters, e.g. '001010100101001...001010'
      for (size_t i = 0; i < 8; i++) {
          recovered_quadword[i] = 0;
          for (size_t j = 0; j < 8; j++) {
              recovered_quadword[i] |= (script_stdout[i*8+j] == '1' ? (1 << (8-j-1)) : 0);
          }
      }
      std::cout << "Recovered 64-bit message: 0x";
      for (size_t i = 0; i < 8; i++) {
          std::cout << std::hex
                    << std::setw(2)
                    << static_cast<uint64_t>(recovered_quadword[i]);
      }
      bool correctly_recovered = true;
      for (size_t i = 0; i < 8; i++) {
          if (correct_quadword[i] != recovered_quadword[i]) {
              correctly_recovered = false;
              break;
          }
      }
      if (correctly_recovered)
          std::cout << ", which is correct";
      else
          std::cout << ", which is CORRUPT";
      std::cout << std::endl;
}

void setPenaltyBox(processor_t* p, uint8_t victim_message[8], uint8_t cacheline[64], unsigned position_in_cacheline) {
    //Message
    reg_t msg;
    memcpy(&msg, victim_message, 8);
    p->set_csr(CSR_PENALTY_BOX_MSG, msg);

    //Cacheline
    reg_t cl[8];
    memcpy(cl, cacheline, 64);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK0, cl[0]);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK1, cl[1]);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK2, cl[2]);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK3, cl[3]);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK4, cl[4]);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK5, cl[5]);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK6, cl[6]);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLK7, cl[7]);

    //Blockpos
    reg_t bp = static_cast<reg_t>(position_in_cacheline);
    p->set_csr(CSR_PENALTY_BOX_CACHELINE_BLKPOS, bp);
}

