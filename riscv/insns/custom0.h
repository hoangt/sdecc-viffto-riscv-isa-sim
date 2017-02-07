if (MMU.errInjEnabled()) { 
    MMU.err_inj_target_ = "inst";
    MMU.err_inj_enable_ = true;
    MMU.err_inj_step_ = total_steps+1;
    std::cout << "ERROR INJECTION ENABLED for INSTRUCTION MEMORY by application, effective on next step: " << total_steps+1 << "!" << std::endl;
} else {
    std::cout << "ERROR: Application tried to arm error injection for instruction memory, but Spike was not started with the error injection mode." << std::endl;
    exit(1);
}
