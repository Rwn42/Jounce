package main 

import "core:fmt"
import "core:os"
import "core:mem"
import "core:unicode/utf8"
import "core:path/filepath"
import "core:strconv"
import "../instructions"

Identifier :: struct{
    token: Token,
    ip: i32,
}

Block :: struct{
    start: i32,
    typ: Block_Type,
    ips_to_reference_end: [dynamic]i32,
    lv_count: int,
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
    lv_loc: int,
    lvs: map[string]int,
    strings: [dynamic]u8,
}

/*
-------------------------
|Main Compiler Functions|
-------------------------
*/

//main application entry point
compile_program :: proc(input_filepath: string, output_filepath: string, save_as_ir: bool) -> bool{

    //make our compiler object
    compiler := Compiler{}
    defer compiler_delete(&compiler)

    //adds main function to be scanned for
    append(&compiler.program, instructions.Instruction{.CALL, 69})
    append(&compiler.encountered_identifiers, Identifier{Token{value="main"}, current_ip(&compiler.program)})

    lex_file(input_filepath, &compiler.tokens) or_return
    compile_tokens(&compiler) or_return
    link(&compiler) or_return

    if save_as_ir{
        compiler_save_as_ir(&compiler, output_filepath) or_return
    }else{
        compiler_save_as_text(&compiler, output_filepath) or_return
    }

    return true
}

compile_tokens :: proc(using compiler: ^Compiler) -> bool{
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
            append(&program, Instruction{.PUSH, i32(len(strings))})
            runes := utf8.string_to_runes(value)
            rune_data := mem.slice_to_bytes(runes)
            for b in rune_data{
                append(&strings, b)
            }
            
            append(&program, Instruction{.PUSH, i32(len(rune_data))})
            delete(runes)
        }else if typ == .ID{
            if value in lvs{
                append(&program, Instruction{.PUSHLV, i32(lvs[value])})
            }else{
                append(&program, Instruction{.HALT, 1})
                append(&encountered_identifiers, Identifier{token, current_ip(&program)})
            }
        }else{
            fmt.eprintf("ERROR: Malformed Token: %s @ Row: %d, Col: %d, filename: %s, type: %s \n", value, row, col, file, typ)
            return false
        }
    }
    append(&program, Instruction{.HALT, 0})
    return true
}

//spit up from compile_tokens function mainly for readability sake
compile_keyword_token :: proc(using compiler: ^Compiler, using token: Token, idx:int){
    using instructions
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
            lv_loc -= block.lv_count    
            delete(block.ips_to_reference_end)
        case "ret":
            append(&program, Instruction{.RET, 0})
        case "->":
            name := tokens[idx+1].value
            if name in lvs{
                append(&program, Instruction{.MVLV, i32(lvs[name])})
            }else{
                lvs[name] = lv_loc
                append(&program, Instruction{.MVLV, i32(lv_loc)})
                lv_loc += 1
                blocks[len(blocks)-1].lv_count += 1
            }
            skip_count = 1
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
        case "syscall":
            call_number_token := tokens[idx+1]
            skip_count = 1
            call_number, ok := strconv.parse_int(call_number_token.value)
            if !ok{
                fmt.eprintf("ERROR: A number must follow a syscall")
                fmt.eprintf("token: %s row: %d, col: %d, filename: %s \n", call_number_token.value, call_number_token.row, call_number_token.col, call_number_token.file)
            }else{
                append(&program, Instruction{.SYSCALL, i32(call_number)})
            }
        case "import":
            skip_count = 1
            dir_root := filepath.dir(file)
            import_path := fmt.aprintf("./%s/%s.jnc", dir_root, tokens[idx+1].value)
            ok := lex_file(import_path, &tokens)
            delete(import_path)
            delete(dir_root)
            if !ok{
                os.exit(1)
            }
        case:
            fmt.eprintf("Keyword %s is not implemented \n", value)
    }

}

  

link :: proc(using compiler: ^Compiler) -> bool{
    using instructions
    for identifier in encountered_identifiers{
        using identifier
        if token.value in declared_constants{
            program[ip] = Instruction{.PUSH, declared_constants[token.value]}
        }else if token.value in declared_functions{
            if token.value == "main"{
                program[ip] = Instruction{.JMP, declared_functions[token.value]}
            }else{
                program[ip] = Instruction{.CALL, declared_functions[token.value]}
            }
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
    delete(lvs)
    delete(strings)
}

compiler_save_as_text :: proc(compiler: ^Compiler, output_filepath: string) -> bool{
    fd, err := os.open(output_filepath, os.O_CREATE | os.O_WRONLY, 0o777)

    if err != os.ERROR_NONE{
        fmt.eprintf("ERROR: Cannot open output file %s", output_filepath)
        return false
    }
    defer os.close(fd)
    
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

    return true
}


compiler_save_as_ir :: proc(compiler: ^Compiler, output_filepath: string) -> bool{
    fd, err := os.open(output_filepath, os.O_CREATE | os.O_WRONLY, 0o777)

    if err != os.ERROR_NONE{
        fmt.eprintf("ERROR: Cannot open output file %s", output_filepath)
        return false
    }
    defer os.close(fd)

    program_length_as_bytes := transmute([4]u8)u32le(len(compiler.program))

    os.write(fd, program_length_as_bytes[:])
    os.write(fd, mem.slice_to_bytes(compiler.program[:]))
    os.write(fd, compiler.strings[:])

    return true
}