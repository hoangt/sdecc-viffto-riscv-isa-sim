require_extension('A');
reg_t v = MMU.load_int32(RS1, false); //MWG
MMU.store_uint32(RS1, RS2 | v, false); //MWG
WRITE_RD(v);
