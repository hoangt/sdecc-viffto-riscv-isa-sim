//Author: Mark Gottscho
//Email: mgottscho@ucla.edu

#ifndef SWD_ECC_H
#define SWD_ECC_H

typedef enum {
    HSIAO_CODE,
    PI_CODE,
    NUM_ECC_CODES 
} ecc_codes_t;


typedef enum {
    ERR_INJ_INST_MEM,
    ERR_INJ_DATA_MEM,
    NUM_ERR_INJ_TARGETS 
} err_inj_targets_t;

typedef class SwdEcc {
    public:
        SwdEcc();
        ~SwdEcc();

        char* heuristicRecovery(char* message, const char* cacheline, const uint32_t blockpos);

    private:
        size_t n_;
        size_t k_;
        ecc_codes_t code_;
        uint32_t words_per_block_;
        err_inj_targets_t target_;

    friend class mmu_t;
} SwdEcc_t;

#endif
