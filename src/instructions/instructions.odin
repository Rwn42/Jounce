package instructions

Instruction :: struct #packed{
    operation: Op,
    operand: i32,
}

Op :: enum {
    PUSH, HALT, RET, CALL, ADD, MUL, EQ, LT, JNE, JMP, SYSCALL, MVLV, PUSHLV,
}