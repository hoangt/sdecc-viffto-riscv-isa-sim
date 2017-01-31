/**
 * Author: Mark Gottscho
 * Email: mgottscho@ucla.edu
 * 
 * Hello World example for RISC-V. This is a playground for implementing application-defined memory DUE handlers.
 */ 

#include <stdio.h>
#include <stdint.h>

//Originally defined in riscv-pk/include/pk.h
typedef struct {
    long gpr[32];
    long status;
    long epc;
    long badvaddr;
    long cause;
    long insn;
} trapframe_t;

typedef void (*trap_handler)(trapframe_t* tf); //Originally defined in riscv-pk/include/pk.h

trapframe_t my_trapframe;
int error_in_stack = 0;
int error_in_x = 0;
int error_in_y = 0;
volatile float x[10000000];
volatile float y[10000000];

void my_due_handler(trapframe_t* tf) {
    for (int i = 0; i < 32; i++)
        my_trapframe.gpr[i] = tf->gpr[i];
    my_trapframe.status = tf->status;
    my_trapframe.epc = tf->epc;
    my_trapframe.badvaddr = tf->badvaddr;
    my_trapframe.cause = tf->cause;
    my_trapframe.insn = tf->insn;

    if (my_trapframe.badvaddr >= my_trapframe.gpr[2]-1024 && my_trapframe.badvaddr < my_trapframe.gpr[2]+1024)
        error_in_stack = 1;
    if (my_trapframe.badvaddr >= (long)(x) && my_trapframe.badvaddr < (long)(x+10000000))
        error_in_x = 1;
    if (my_trapframe.badvaddr >= (long)(y) && my_trapframe.badvaddr < (long)(y+10000000))
        error_in_y = 1;
}

//Originally defined in riscv-pk/pk/console.c
void dump_tf(trapframe_t* tf)
{
  static const char* regnames[] = {
    "z ", "ra", "sp", "gp", "tp", "t0",  "t1",  "t2",
    "s0", "s1", "a0", "a1", "a2", "a3",  "a4",  "a5",
    "a6", "a7", "s2", "s3", "s4", "s5",  "s6",  "s7",
    "s8", "s9", "sA", "sB", "t3", "t4",  "t5",  "t6"
  };

  tf->gpr[0] = 0;

  for(int i = 0; i < 32; i+=4)
  {
    for(int j = 0; j < 4; j++)
      printf("%s %lx%c",regnames[i+j],tf->gpr[i+j],j < 3 ? ' ' : '\n');
  }
  printf("pc %lx va %lx insn       %x sr %lx\n", tf->epc, tf->badvaddr,
         (uint32_t)tf->insn, tf->status);
}

void register_user_memory_due_trap_handler(trap_handler fptr) {
    asm volatile("or a0, zero, %0;" //Load user trap handler fptr into register a0
                 "li a7, 447;" //Load syscall number 447 (SYS_register_user_memory_due_trap_handler) into register a7
                 "ecall;" //Make RISC-V environment call to register our user-defined trap handler
                 :
                 : "r" (fptr));
}

int main(int argc, char** argv) {
    dump_tf(&my_trapframe);
    printf("&x: %0x\n", x);
    printf("&y: %0x\n", y);
    float m = 2;
    float b = 0;
    register_user_memory_due_trap_handler(&my_due_handler);
    //for (volatile unsigned long i = 0; i < 10000000; i++);
    for (long i = 0; i < 10000000; i++) {
        x[i] = i;
    }
    for (long i = 0; i < 10000000; i++) {
        y[i] = m*x[i]+b;
    }
    printf("Hello World!\n");
    printf("error_in_stack = %d\n", error_in_stack);
    printf("error_in_x = %d\n", error_in_x);
    printf("error_in_y = %d\n", error_in_y);
    dump_tf(&my_trapframe);
    return 0;
}
