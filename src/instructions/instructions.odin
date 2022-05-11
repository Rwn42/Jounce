package instructions

Instruction :: struct{
    operation: Op,
    operand: i32,
}

Op :: enum {
    PUSH, HALT, RET, CALL,
}