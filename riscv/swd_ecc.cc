//Author: Mark Gottscho
//Email: mgottscho@ucla.edu

#include <iostream>
#include "swd_ecc.h"

SwdEcc::SwdEcc(
    size_t n,
    size_t k,
    ecc_codes_t selected_ecc,
    uint32_t words_per_block,
    bool instruction) : 
        n_(n),
        k_(k),
        code_(selected_ecc),
        words_per_block_(words_per_block),
        instruction_(instruction) {
    //Nothing else here to do
}

SwdEcc::~SwdEcc() {
    //Nothing to do
}

char* SwdEcc::heuristicRecovery(
        char*  message,
        const char* cacheline,
        const uint32_t blockpos) {
    std::cout << "SWD-ECC heuristic recovery" << std::endl;
    return message; //TODO: implement SWD-ECC, obviously
}
