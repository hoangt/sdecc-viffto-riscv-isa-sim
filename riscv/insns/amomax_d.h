require_extension('A');
require_rv64;
sreg_t v = MMU.load_int64(RS1, false); //MWG
MMU.store_uint64(RS1, std::max(sreg_t(RS2),v), false); //MWG
WRITE_RD(v);
