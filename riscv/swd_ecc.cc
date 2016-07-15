//Author: Mark Gottscho
//Email: mgottscho@ucla.edu
//MWG

#include <iostream>
#include "swd_ecc.h"

SwdEcc::SwdEcc() {
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
