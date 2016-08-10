//Author: Mark Gottscho
//Email: mgottscho@ucla.edu
//MWG

#include <cstdio>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <stringstream>

#include "swd_ecc.h"

std::string exec(const char* cmd) {
    char buffer[128];
    std::string result = "";
    std::shared_ptr<FILE> pipe(popen(cmd, "r"), pclose);
    if (!pipe) throw std::runtime_error("popen() failed!");
    while (!feof(pipe.get())) {
        if (fgets(buffer, 128, pipe.get()) != NULL)
            result += buffer;
    }
    return result;
}

insn_bits_t heuristic_recovery(std::string script_filename, insn_bits_t message, std::vector<insn_bits_t> cacheline, uint32_t blockpos) {
    std::string cmd;
    std::stringstream ss;

    //Construct command line
    ss << script_filename + " ";
    ss << std::hex << std::setw(16) << message << " ";
    for (auto i = 0; i < cacheline.len(); i++)
        ss << std::hex << std::setw(16) << cacheline(i) << " ";
    ss >> cmd;
    std::string script_stdout = exec(cmd);    
    std::cout << cmd << std::endl; //debug

    insn_bits_t recovered_message = 0x0000000000000000; //64-bits of 0
    
    //Output is expected to be simply a k-bit message in binary characters, e.g. '001010100101001...001010'
    for (int i = 0; i < script_stdout.len(); i++) {
        recovered_message |= (script_stdout[i] == '1' ? (1 << (sizeof(insn_bits_t)-i-1)) : 0);
    }

    return recovered_message;
}
