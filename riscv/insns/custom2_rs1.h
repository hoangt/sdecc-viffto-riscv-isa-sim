reg_t msg = p->get_csr(CSR_PENALTY_BOX_MSG);
uint8_t victim_message[MMU.memwordsize];
memcpy(victim_message, &msg, MMU.memwordsize);
std::string cmd = construct_sdecc_candidate_messages_cmd(MMU.candidates_sdecc_script_filename, victim_message, MMU.memwordsize, "hsiao1970", 0);
std::string output = myexec(cmd);
std::cout << output << std::endl;
const char* output_cstr = output.c_str();
MMU.store_slow_path(RS1, output.length(), (const uint8_t*)output_cstr, 0);
