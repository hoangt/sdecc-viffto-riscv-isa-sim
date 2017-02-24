require_rv64;
p->pb.mem_due_dest_reg = insn.rd(); //MWG
p->pb.mem_due_dest_reg_type = true; //MWG
p->pb.mem_due_load_type = "int64";
WRITE_RD(MMU.load_int64(RS1 + insn.i_imm(), false)); //MWG
