//Author: Mark Gottscho
//Email: mgottscho@ucla.edu

//MWG
#ifndef _RISCV_SDECC_H
#define _RISCV_SDECC_H

#include <string>
#include "processor.h"

//MWG: based on http://stackoverflow.com/questions/478898/how-to-execute-a-command-and-get-output-of-command-within-c-using-posix
std::string myexec(std::string cmd);

std::string construct_sdecc_recovery_cmd(std::string script_filename, uint8_t* correct_word, uint8_t* cacheline, uint32_t memwordsize, uint32_t words_per_block, unsigned position_in_cacheline);

std::string construct_sdecc_candidate_messages_cmd(std::string script_filename, uint8_t* correct_word, uint32_t memwordsize, std::string code_type, int verbose);

void parse_sdecc_recovery_output(std::string script_stdout, uint8_t* recovered_word, const uint8_t* correct_word, uint32_t memwordsize);
void setPenaltyBox(processor_t* p, uint8_t* victim_message, uint8_t* cacheline, uint32_t memwordsize, uint32_t words_per_block, unsigned position_in_cacheline);

#endif
