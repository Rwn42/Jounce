package instructions

Instruction :: struct{
    operation: Op,
    operand: i32,
}

Op :: enum {
    PUSH, HALT, RET, CALL, ADD, MUL, EQ, LT, JNE, JMP,
}