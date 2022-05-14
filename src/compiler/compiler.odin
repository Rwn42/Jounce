package main 

import "core:fmt"
import "core:os"
import "core:mem"
import "../instructions"

Identifier :: struct{
    token: Token,
    ip: i32,
}

Block :: struct{
    start: i32,
    typ: Block_Type,
    ips_to_reference_end: [dynamic]i32,
}

Block_Type :: enum {FUNCTION, IF, WHILE,}

Compiler :: struct{
    tokens: [dynamic]Token,
    program: [dynamic]instructions.Instruction,
    encountered_identifiers: [dynamic]Identifier,
    blocks: [dynamic]Block,
    declared_constants: map[string]i32,
    declared_functions: map[string]i32,
    skip_count: int,
}

/*
-------------------------
|Main Compiler Functions|
-------------------------
*/

//main application entry point
compile_program :: proc(entry_file: string, save_as_ir: bool){
    compiler := Compiler{}
    compiler.tokens = make([dynamic]Token)
    defer compiler_delete(&compiler)

    lex_file(entry_file, &compiler.tokens)
    //TODO imports
    compile_tokens(&compiler)

    ok := link(&compiler)
    if !ok{
        os.exit(1)
    }
    if save_as_ir{
        compiler_save_as_ir(&compiler)
    }else{
        compiler_save_as_text(&compiler)
    }
}

compile_tokens :: proc(compiler: ^Compiler){
    using compiler
    using instructions
    for token, idx in tokens{
        using token
        if skip_count > 0{
            skip_count -= 1
            continue
        }
        if typ != .KEYWORD && typ != .ID && typ != .STR{
            append(&program, Instruction{.PUSH, i32_from_token(token)})
        }else if typ == .KEYWORD{
            compile_keyword_token(compiler, token, idx)
        }else if typ == .STR{
            fmt.println("ERROR: strings not yet supported")
        }else if typ == .ID{
            append(&program, Instruction{.HALT, 1})
            append(&encountered_identifiers, Identifier{token, current_ip(&program)})
        }else{
            fmt.eprintf("ERROR: Malformed Token: %s @ Row: %d, Col: %d, filename: %s, type: %s \n", value, row, col, file, typ)
            os.exit(1)
        }
    }
    append(&program, Instruction{.HALT, 0})
}

//spit up from compile_tokens function mainly for readability sake
compile_keyword_token :: proc(compiler: ^Compiler, token: Token, idx:int){
    using compiler
    using instructions
    using token
    switch value {
        case "const":
            declared_constants[tokens[idx+1].value] = i32_from_token(tokens[idx+3])
            skip_count = 3
        case "fn":
            append(&blocks, Block{start=current_ip(&program)+1, typ=.FUNCTION})
            declared_functions[tokens[idx+1].value] = current_ip(&program)+1
            skip_count = 2
        case "if":
            append(&blocks, Block{start=current_ip(&program)+1, typ=.IF})
        case "while":
            append(&blocks, Block{start=current_ip(&program)+1, typ=.WHILE})
        case "do":
            append(&program, Instruction{.JNE, 69})
            append(&blocks[len(blocks)-1].ips_to_reference_end, current_ip(&program))
        case "else":
            append(&program, Instruction{.JMP, 69})
            do_loc := pop(&blocks[len(blocks)-1].ips_to_reference_end)
            program[do_loc].operand = current_ip(&program)+1
            append(&blocks[len(blocks)-1].ips_to_reference_end, current_ip(&program))
        case "end":
            block := pop(&blocks)
            if block.typ == .FUNCTION {
                append(&program, Instruction{.RET, 0})
            }else if block.typ == .IF{
                for ip in block.ips_to_reference_end{
                    program[ip].operand = current_ip(&program)+1
                }
            }else if block.typ == .WHILE{
                ip := pop(&block.ips_to_reference_end)
                append(&program, Instruction{.JMP, block.start})
                program[ip].operand = current_ip(&program)+1
            }    
            delete(block.ips_to_reference_end)
        case "ret":
            append(&program, Instruction{.RET, 0})
        case "+":
            append(&program, Instruction{.ADD, 1})
        case "-":
            append(&program, Instruction{.ADD, -1})
        case "*":
            append(&program, Instruction{.MUL, 1})
        case "/":
            append(&program, Instruction{.MUL, -1})
        case "==":
            append(&program, Instruction{.EQ, 1})
        case "!=":
            append(&program, Instruction{.EQ, -1})
        case "<":
            append(&program, Instruction{.LT, 1})
        case ">":
            append(&program, Instruction{.LT, -1})
        case "puti":
            append(&program, Instruction{.SYSCALL, 10})
        case "putc":
            append(&program, Instruction{.SYSCALL, 11})
        case:
            fmt.eprintf("Keyword %s is not implemented \n", value)
    }

}

  

link :: proc(compiler: ^Compiler) -> bool{
    using compiler
    using instructions
    for identifier in encountered_identifiers{
        using identifier
        if token.value in declared_constants{
            program[ip] = Instruction{.PUSH, declared_constants[token.value]}
        }else if token.value in declared_functions{
            program[ip] = Instruction{.CALL, declared_functions[token.value]}
        }else{
            fmt.eprintf("ERROR: Undeclared Identifier %s @ ", token.value)
            fmt.eprintf("row: %d, col: %d, filename: %s \n", token.row, token.col, token.file)
            return false
        }
    }
    return true
}

/*
-------------------
|Utility Functions|
-------------------
*/

current_ip :: proc(program: ^[dynamic]instructions.Instruction) -> i32{
    return i32(len(program)-1)
} 

compiler_delete :: proc(compiler: ^Compiler){
    using compiler
    for tk in tokens{
        delete(tk.value)
    }
    delete(tokens)
    delete(program)
    delete(encountered_identifiers)
    delete(declared_constants)
    delete(declared_functions)
    delete(blocks)
}

compiler_save_as_text :: proc(compiler: ^Compiler){
    if !os.is_file("output.jnca"){
        fd, err := os.open("output.jnca", os.O_CREATE, 0o777)
        if err != os.ERROR_NONE{
            fmt.eprintln("ERROR: Cannot open output file. Compilation Failed")
            os.exit(1)
        }
    }

    fd, err := os.open("output.jnca", os.O_WRONLY, 0o777)
    if err != os.ERROR_NONE{
        fmt.eprintln("ERROR: Cannot open output file. Compilation Failed")
        os.exit(1)
    }
    defer os.close(fd)
    
    fmt.fprintf(fd, "-------------------\n")
    fmt.fprintf(fd, "|Jounce IR as Text|\n")
    fmt.fprintf(fd, "-------------------\n")
    for inst, ip in compiler.program{
        fmt.fprintf(fd, "%d", ip)

        ip_as_string := fmt.aprintf("%d", ip)
        if ls := len(ip_as_string); ls <= 1{
            fmt.fprint(fd, "  ")
        }else if ls <= 2{
            fmt.fprint(fd, " ")
        }
        delete(ip_as_string)

        fmt.fprintf(fd, " %s %d \n", inst.operation, inst.operand)
    }
}

compiler_save_as_ir :: proc(compiler: ^Compiler){
    if !os.is_file("output.jnci"){
        fd, err := os.open("output.jnci", os.O_CREATE, 0o777)
        if err != os.ERROR_NONE{
            fmt.eprintln("ERROR: Cannot open output file. Compilation Failed")
            os.exit(1)
        }
    }
    fd, err := os.open("output.jnci", os.O_WRONLY, 0o777)
    if err != os.ERROR_NONE{
        fmt.eprintln("ERROR: Cannot open output file. Compilation Failed")
        os.exit(1)
    }
    defer os.close(fd)

    os.write(fd, mem.slice_to_bytes(compiler.program[:]))
}