package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:math"

import "../instructions"

MAX_STACK_CAP :: 25
MAX_CALL_STACK_CAP :: 25

VM :: struct{
    program: []instructions.Instruction,

    stack: [MAX_STACK_CAP]i32,
    sp: i32,

    ip: i32,

    call_stack: [MAX_CALL_STACK_CAP]i32,
    csp: i32,
}

load_program :: proc(vm: ^VM, file:string){
    using vm
    data, ok := os.read_entire_file_from_filename(file)
    if !ok{
        fmt.eprintf("ERROR: Could Not Open File %s", file)
        os.exit(1)
    }
    vm.program = mem.slice_data_cast([]instructions.Instruction, data)
}

execute :: proc(vm: ^VM) -> i32{
    using vm

    for true{
        operation := program[ip].operation
        operand := program[ip].operand
        #partial switch operation{
            case .PUSH:
                stack[sp] = operand
                sp += 1
            case .HALT:
                return operand
            case .ADD:
                stack[sp-2] += stack[sp-1] * operand
                sp -= 1
            case .MUL:
                stack[sp-2] = i32(f32(stack[sp-2]) * math.pow(f32(stack[sp-1]), f32(operand)))
                sp -= 1
            case .EQ:
                if stack[sp-2] == stack[sp-1]{
                    stack[sp-2] = operand
                }else{
                    stack[sp-2] = operand*(-1)
                }
                sp -= 1
            case .LT:
                if stack[sp-2] < stack[sp-1]{
                    stack[sp-2] = operand
                }else{
                    stack[sp-2] = operand*(-1)
                }
                sp -= 1
            case .JMP:
                ip = operand-1
            case .JNE:
                if stack[sp-1] != 1{
                    ip = operand-1
                }
                sp -= 1
            case .CALL:
                call_stack[csp] = ip
                csp += 1
            case .RET:
                ip = call_stack[csp-1]
                csp -= 1
            case .SYSCALL:
                switch operand{
                    case 10:
                        fmt.printf("%d", stack[sp-1])
                        sp -= 1
                    case 11:
                        fmt.printf("%c", stack[sp-1])
                        sp -= 1
                }
        }
        ip += 1
        fmt.println("\n--------")
        for i: i32 = 0; i < sp; i += 1{
            fmt.printf("%d ", stack[i])
        }
    }

    return 0;
}