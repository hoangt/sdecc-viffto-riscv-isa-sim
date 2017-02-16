if (MMU.errInjEnabled()) { 
    MMU.err_inj_target = "inst";
    MMU.err_inj_enable = true;
    MMU.err_inj_step = total_steps+1;
    std::cout << "ERROR INJECTION ENABLED for INSTRUCTION MEMORY by application, effective on next step: " << total_steps+1 << "!" << std::endl;
} else {
    std::cout << "ERROR: Application tried to arm error injection for instruction memory, but error injection is disabled." << std::endl;
    exit(1);
}
