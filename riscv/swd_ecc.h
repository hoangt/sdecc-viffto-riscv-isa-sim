//Author: Mark Gottscho
//Email: mgottscho@ucla.edu

#ifndef SWD_ECC_H
#define SWD_ECC_H

typedef enum {
    HSIAO_CODE,
    PI_CODE,
    NUM_ECC_CODES 
} ecc_codes_t;

typedef class SwdEcc {
    public:
        SwdEcc(size_t n, size_t k, ecc_codes_t selected_ecc, uint32_t words_per_block, bool instruction);
        ~SwdEcc();

        char* heuristicRecovery(char* message, const char* cacheline, const uint32_t blockpos);
    private:
        size_t n_;
        size_t k_;
        ecc_codes_t code_;
        uint32_t words_per_block_;
        bool instruction_;
} SwdEcc_t;

#endif
