//RS1: address of output cstring buffer for recovered message, e.g. '010010101'
//RS2: address of input cstring buffer for candidate messages, e.g. '010010101,00000000,....,01010101,...'

//FIXME: remove CSR dependency here
reg_t original_msg;
reg_t cl[MMU.words_per_block];
reg_t blockpos;
original_msg = p->get_csr(CSR_PENALTY_BOX_MSG);
cl[0] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK0);
cl[1] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK1);
cl[2] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK2);
cl[3] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK3);
cl[4] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK4);
cl[5] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK5);
cl[6] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK6);
cl[7] = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLK7);
blockpos = p->get_csr(CSR_PENALTY_BOX_CACHELINE_BLKPOS);

//Convert values to lumps of bytes
uint8_t* victim_message = reinterpret_cast<uint8_t*>(&original_msg);
char* candidates = (char*)(malloc(2048)); //FIXME
MMU.load_slow_path(RS2, 2048, (uint8_t*)(candidates), 0);
uint8_t cacheline[MMU.words_per_block*MMU.memwordsize];
memcpy(cacheline, cl, MMU.words_per_block*MMU.memwordsize); //FIXME

//Run external command
std::string cmd = construct_sdecc_recovery_cmd(MMU.data_sdecc_script_filename, victim_message, candidates, cacheline, MMU.memwordsize, MMU.words_per_block, (unsigned)(blockpos));
std::string output = myexec(cmd);
const char* output_cstr = output.c_str();

MMU.store_slow_path(RS1, output.length(), (const uint8_t*)output_cstr, 0);

std::cout << " Original message: ";
for (size_t i = 0; i < MMU.memwordsize; i++)
  std::cout << std::bitset<8>(victim_message[i]);
std::cout << std::endl;
std::cout << "Recovered message: " << output; //output has newline built in
