if (MMU.errInjMode()) { 
    MMU.err_inj_target = "inst";
    MMU.err_inj_enable = true;
    MMU.err_inj_step_start = RS1+total_steps;
    MMU.err_inj_step_stop = RS2+total_steps;
    MMU.err_inj_step = MMU.err_inj_step_start + (rand() % (1 + MMU.err_inj_step_stop - MMU.err_inj_step_start)); 
    std::cout << "ERROR INJECTION ENABLED for INSTRUCTION MEMORY by application in the offset step range " << RS1 << " to " << RS2 << ". Actual step will be " << MMU.err_inj_step - total_steps << " in the future, which is actual step " << MMU.err_inj_step << "." << std::endl;
} else {
    std::cout << "ERROR: Application tried to arm error injection for instruction memory, but error injection is disabled." << std::endl;
    exit(1);
}
