reg_t msg = p->get_csr(CSR_PENALTY_BOX_MSG);
reg_t msg_size = p->get_csr(CSR_PENALTY_BOX_MSG_SIZE);
uint8_t victim_message[msg_size];
memcpy(victim_message, &msg, msg_size);
std::string cmd = construct_sdecc_candidate_messages_cmd(MMU.candidates_sdecc_script_filename, victim_message, msg_size, MMU.ncodewordbits, MMU.code_type);
std::string output = myexec(cmd);
std::cout << output << std::endl;
const char* output_cstr = output.c_str();
MMU.store_slow_path(RS1, output.length(), (const uint8_t*)output_cstr, 0);
