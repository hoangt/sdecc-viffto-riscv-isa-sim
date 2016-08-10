//Author: Mark Gottscho
//Email: mgottscho@ucla.edu

#ifndef SWD_ECC_H
#define SWD_ECC_H

#include <string>

std::string exec(const char* cmd); //From http://stackoverflow.com/questions/478898/how-to-execute-a-command-and-get-output-of-command-within-c-using-posix 

insn_bits_t heuristic_recovery(std::string script_filename, insn_bits_t message, std::vector<insn_bits_t> cacheline, uint32_t blockpos);

#endif
