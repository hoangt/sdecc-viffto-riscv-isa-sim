//Author: Mark Gottscho
//Email: mgottscho@ucla.edu

//MWG
#ifndef _RISCV_SDECC_H
#define _RISCV_SDECC_H

#include <string>
#include "processor.h"

//MWG: based on http://stackoverflow.com/questions/478898/how-to-execute-a-command-and-get-output-of-command-within-c-using-posix
std::string myexec(std::string cmd);

std::string construct_sdecc_data_recovery_cmd(std::string script_filename, uint8_t* correct_word, char* candidates, uint8_t* cacheline, size_t memwordsize, size_t words_per_block, size_t position_in_cacheline);
std::string construct_sdecc_inst_recovery_cmd(std::string script_filename, uint8_t* correct_word, char* candidates, size_t memwordsize);

std::string construct_sdecc_candidate_messages_cmd(std::string script_filename, uint8_t* correct_word, size_t memwordsize, size_t n, std::string code_type);

void parse_sdecc_recovery_output(std::string script_stdout, uint8_t* recovered_word, const uint8_t* correct_word, const uint8_t* candidate_correct_messages, size_t memwordsize);
void setPenaltyBox(processor_t* p, uint8_t* victim_message, uint8_t* cacheline, size_t memwordsize, size_t words_per_block, size_t position_in_cacheline, bool inst_mem);

#endif
