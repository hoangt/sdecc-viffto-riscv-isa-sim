/**
 * Author: Mark Gottscho
 * Email: mgottscho@ucla.edu
 * 
 * Hello World example for RISC-V. This is a playground for implementing application-defined memory DUE handlers.
 */ 

#include <stdio.h>

void handle_memory_due() {
    asm volatile("lui a0, 0xdead");
}

int main(int argc, char** argv) {
    for (volatile unsigned long i = 0; i < 100000000; i++);
    printf("Hello World!\n");
    return 0;
}
