/**
 * Author: Mark Gottscho
 * Email: mgottscho@ucla.edu
 * 
 * Hello World example for RISC-V. This is a playground for implementing application-defined memory DUE handlers.
 */ 

#include <stdio.h>

// Originally defined in riscv-pk/include/pk.h
typedef struct {
    long gpr[32];
    long status;
    long epc;
    long badvaddr;
    long cause;
    long insn;
} trapframe_t;

typedef void (*user_trap_handler)(trapframe_t* tf); //MWG added to riscv-pk/include/pk.h

void my_due_handler(trapframe_t* tf) {
    asm volatile("lui a0, 0xdead;"); //Write a canary value to register a0 that we can breakpoint on to make sure this actually gets executed
}

void register_user_memory_due_trap_handler(user_trap_handler fptr) {
    asm volatile("or a0, zero, %0;" //Load user trap handler fptr into register a0
                 "li a7, 447;" //Load syscall number 447 (SYS_register_user_memory_due_trap_handler) into register a7
                 "ecall;" //Make RISC-V environment call to register our user-defined trap handler
                 :
                 : "r" (fptr));
}

int main(int argc, char** argv) {
    register_user_memory_due_trap_handler(&my_due_handler);
    for (volatile unsigned long i = 0; i < 100000000; i++);
    printf("Hello World!\n");
    return 0;
}
