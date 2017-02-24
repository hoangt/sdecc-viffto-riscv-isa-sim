//RS1: address of output cstring buffer for recovered message, e.g. '010010101'
//RS2: address of input cstring buffer for candidate messages, e.g. '010010101,00000000,....,01010101,...'

reg_t msg_size = p->pb.msg_size;
reg_t cacheline_size = p->pb.cacheline_size;
reg_t blockpos = p->pb.cacheline_blockpos;

//Convert values to lumps of bytes
uint8_t victim_message[msg_size];
memcpy(victim_message, p->pb.victim_msg, msg_size);
char* candidates = (char*)(malloc(2048)); //FIXME
MMU.load_slow_path(RS2, 2048, (uint8_t*)(candidates), 0);
uint8_t cacheline[cacheline_size];
memcpy(cacheline, p->pb.cacheline_words, cacheline_size);

//Run external command
std::string cmd = construct_sdecc_recovery_cmd(MMU.data_sdecc_script_filename, victim_message, candidates, cacheline, msg_size, cacheline_size/msg_size, (unsigned)(blockpos));
std::string output = myexec(cmd);
const char* output_cstr = output.c_str();

MMU.store_slow_path(RS1, output.length()+1, (const uint8_t*)output_cstr, 0);

std::cout << " Original message: ";
for (size_t i = 0; i < MMU.memwordsize; i++)
  std::cout << std::bitset<8>(victim_message[i]);
std::cout << std::endl;
std::cout << "Recovered message: " << output; //output has newline built in
