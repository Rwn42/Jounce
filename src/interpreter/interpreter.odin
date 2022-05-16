package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:math"

import "../instructions"

MAX_STACK_CAP :: 10
MAX_CALL_STACK_CAP :: 25
MAX_LOCAL_VARS :: 30

VM :: struct{
    program: []instructions.Instruction,
    ip: i32,

    stack: [MAX_STACK_CAP]i32,
    sp: i32,

    call_stack: [MAX_CALL_STACK_CAP]i32,
    csp: i32,

    lv_stack: [MAX_LOCAL_VARS]i32,
    lvsp: i32,

    strings: []u8,
}

load_program :: proc(vm: ^VM, file:string){
    using vm
    data, ok := os.read_entire_file_from_filename(file)
    if !ok{
        fmt.eprintf("ERROR: Could Not Open File %s", file)
        os.exit(1)
    }
    p_len := transmute(u32le)[4]u8{data[0], data[1], data[2], data[3]}
    p_size := p_len * size_of(instructions.Instruction)
    vm.program = mem.slice_data_cast([]instructions.Instruction, data[4:(4 + p_size)])
    vm.strings = data[4+p_size:]
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
            case .MOD:
                stack[sp-2] = i32(math.remainder(f32(stack[sp-2]), f32(stack[sp-1])))
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
                ip = operand-1
            case .RET:
                if csp < 1{
                    return 1
                }
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
                    case 12:
                        start := stack[sp-2]
                        len := stack[sp-1]
                        sp -= 2
                        fmt.print(transmute(string)vm.strings[start:start+len])
                }
            case .MVLV:
                lv_stack[operand] = stack[sp-1]
                sp -= 1
            case .PUSHLV:
                stack[sp] = lv_stack[operand]
                sp += 1
        }
        ip += 1
    }

    return 0;
}