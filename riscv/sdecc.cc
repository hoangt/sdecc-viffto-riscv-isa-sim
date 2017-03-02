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

std::string construct_sdecc_recovery_cmd(std::string script_filename, uint8_t* correct_word, char* candidates, uint8_t* cacheline, uint32_t memwordsize, uint32_t words_per_block, unsigned position_in_cacheline) {
    uint32_t k = memwordsize*8;
    std::string cmd = script_filename + " ";
    cmd += std::to_string(k);
    cmd += " ";
    for (size_t i = 0; i < memwordsize; i++) {
      cmd += std::bitset<8>(correct_word[i]).to_string();
    }
    cmd += " ";
   
    size_t i = 0;
    while (candidates[i] != '\0') //Unsafe
        cmd += candidates[i++];
    cmd += " ";

    for (size_t i = 0; i < words_per_block; i++) {
      for (size_t j = 0; j < memwordsize; j++) {
          cmd += std::bitset<8>(cacheline[i*words_per_block+j]).to_string();
      }
      if (i < words_per_block-1)
          cmd += ",";
    }
    cmd += " " + std::to_string(position_in_cacheline);
    return cmd;
}

std::string construct_sdecc_candidate_messages_cmd(std::string script_filename, uint8_t* correct_word, uint32_t memwordsize, uint32_t n, std::string code_type) {
    uint32_t k = memwordsize*8;

    std::string cmd = script_filename + " ";
    for (size_t i = 0; i < memwordsize; i++) {
      cmd += std::bitset<8>(correct_word[i]).to_string();
    }
    cmd += " ";
    cmd += std::to_string(n);
    cmd += " ";
    cmd += std::to_string(k);
    cmd += " ";
    cmd += code_type;
    return cmd;
}

void parse_sdecc_recovery_output(std::string script_stdout, uint8_t* recovered_word, const uint8_t* correct_word, uint32_t memwordsize) {
      // Output is expected to be simply a k-bit message in binary characters, e.g. '001010100101001...001010'
      for (size_t i = 0; i < memwordsize; i++) {
          recovered_word[i] = 0;
          for (size_t j = 0; j < 8; j++) {
              recovered_word[i] |= (script_stdout[i*8+j] == '1' ? (1 << (8-j-1)) : 0);
          }
      }
}

void setPenaltyBox(processor_t* p, uint8_t* victim_message, uint8_t* cacheline, uint32_t memwordsize, uint32_t words_per_block, unsigned position_in_cacheline) {
    //Message
    memcpy(p->pb.victim_msg, victim_message, memwordsize);

    //Sizes
    reg_t msg_size = static_cast<reg_t>(memwordsize);
    p->pb.msg_size = msg_size;
    reg_t cacheline_size = static_cast<reg_t>(words_per_block*memwordsize);
    p->pb.cacheline_size = cacheline_size;

    //Blockpos
    reg_t bp = static_cast<reg_t>(position_in_cacheline);
    p->pb.cacheline_blockpos = bp;

    p->pb.word_ptr = 0; //Extremely important for software csr reads to function correctly

    //Cacheline
    memcpy(p->pb.cacheline_words, cacheline, words_per_block*memwordsize); //Copy cacheline into penalty box
}

