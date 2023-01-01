package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:unicode/utf8"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "../instructions"

Compiler :: struct{
    special_directives: [dynamic]Directive,
    tokens: [dynamic]Token,
    program: [dynamic]instructions.Instruction,
    declared_macros: map[string][]Token,

    open_blocks: [dynamic]Block,

    string_bytes: [dynamic]u8,
    imported_files: [dynamic]string,
    
    skip_token_count: int,

    declared_locals: map[string]int,
    declared_constants: map[string]int,
    iota: int,

    linker: Linker,

    err_msg:string,
    err_token:Token,
}

Block_Type :: enum{
    FUNCTION, IF, WHILE, MAIN_FUNCTION,
}

Block :: struct{
    start: i32,
    declared_local_names: [dynamic]string,
    end_references: [dynamic]i32,
    typ: Block_Type,
}

compile_program :: proc(input_filepath: string, output_filepath: string, save_as_ir: bool) -> bool{

    //make our compiler object
    compiler := Compiler{}
    compiler.linker = Linker{}
    defer compiler_delete(&compiler)

    using compiler

    //adds main function to be scanned for
    compiler_add_inst_i32(&compiler, .CALL, 69)
    append(&linker.encountered_identifiers, Identifier{Token{value="main"}, current_ip(&compiler.program)})

    lex_file(input_filepath, &tokens, &special_directives) or_return
    if ok := compile_special_directives(&compiler); !ok do compiler_print_error(&compiler)
    if ok := compile_tokens(&compiler); !ok do compiler_print_error(&compiler)
    if ok := link(&compiler); !ok do compiler_print_error(&compiler)

    if save_as_ir{
        compiler_save_as_ir(&compiler, output_filepath) or_return
    }else{
        compiler_save_as_text(&compiler, output_filepath) or_return
    }
    return true
}

compile_special_directives :: proc(using compiler: ^Compiler) -> bool{
    //imports must come first
    for directive in special_directives{
        using directive
        if typ == .IMPORT{
            absolute, new_alloc := filepath.abs(directive.tokens[0].value)
            for i in 0..<len(imported_files){
                if imported_files[i] == absolute{
                    err_msg = "ERROR: Cyclic Import"
                    err_token = directive.tokens[0]
                    return false
                }
            }
            compiler_import_file(compiler, directive.tokens[0])
            append(&imported_files, absolute)
        }
    }
    for directive in special_directives{
        using directive
        if typ == .MACRO_DEF{
            declared_macros[directive.tokens[0].value] = directive.tokens[1:]
        }
    }
    return true
}

compile_tokens :: proc(using compiler: ^Compiler) -> bool{
    for token, idx in tokens{
        if skip_token_count > 0 {skip_token_count -=1; continue}
        
        using token

        if typ == .BOOL || typ == .CHAR || typ == .INT {compiler_add_inst(compiler, .PUSH, token); continue}
        if typ == .KEYWORD {compile_keyword_token(compiler, token, idx) or_return; continue}
        if typ == .STR {compiler_add_inst(compiler, .PUSH, value); continue}
        if typ == .ID{
            if value in declared_locals{
                compiler_add_inst(compiler, .PUSHLV, declared_locals[value])
            }else if value[0] == '@'{
                macro_name := strings.trim_left(token.value, "@")
                 if macro_name in declared_macros{
                    for macro_token, i in declared_macros[macro_name]{
                        insertable_token := macro_token
                        insertable_token.value = strings.clone(macro_token.value)
                        inject_at(&compiler.tokens, idx+i+1, insertable_token)  
                    }
                }else{
                    err_msg = "ERROR: Undefined Macro"
                    err_token = token
                    return false
                }   
            }else if value in declared_constants{
                compiler_add_inst(compiler, .PUSH, declared_constants[value])
            }
            else{
                compiler_add_inst_i32(compiler, .HALT, 69)
                append(&linker.encountered_identifiers, Identifier{token, current_ip(&program)})
            }
        }
    }
    return true    
}

compile_keyword_token :: proc(using compiler: ^Compiler, using token: Token, idx: int) -> bool{
    using instructions
    switch value {
        case "+":
            compiler_add_inst_i32(compiler, .ADD, 1)
        case "-":
            compiler_add_inst_i32(compiler, .ADD, -1)
        case "*":
            compiler_add_inst_i32(compiler, .MUL, 1)
        case "/":
            compiler_add_inst_i32(compiler, .MUL, -1)
        case "==":
            compiler_add_inst_i32(compiler, .EQ, 1)
        case "!=":
            compiler_add_inst_i32(compiler, .EQ, -1)
        case "<":
            compiler_add_inst_i32(compiler, .LT, 1)
        case ">":
            compiler_add_inst_i32(compiler, .LT, -1)
        case "fn":
            if tokens[idx+1].value == "main"{
                compiler_open_block(compiler, .MAIN_FUNCTION)
            }else{
                compiler_open_block(compiler, .FUNCTION)
            }
            linker.declared_functions[tokens[idx+1].value] = current_ip(&program)+1
            skip_token_count = 1
        case "if":
            compiler_open_block(compiler, .IF)
        case "while":
             compiler_open_block(compiler, .WHILE)
        case "break":
            found_while := false
            for block, i in open_blocks{
                if block.typ == .WHILE{
                    compiler_add_inst_i32(compiler, .JMP, 69)
                    append(&open_blocks[i].end_references, current_ip(&program))
                    found_while = true
                }
            }
            if !found_while{
                err_msg = "ERROR: Break Statement Not In A While Loop"
                err_token = token
                return false
            }
        case "do":
            compiler_add_inst_i32(compiler, .JNE, 69)
            block_add_end_reference(compiler)
        case "else":
            compiler_add_inst_i32(compiler, .JMP, 2)
            do_location := pop(&open_blocks[len(open_blocks)-1].end_references)
            program[do_location].operand = (current_ip(&program)+1 - do_location)
            block_add_end_reference(compiler)
        case "end":
            compiler_close_block(compiler)
        case "->":
            compiler_local_variable_assignment(compiler, idx) or_return
        case "syscall":
            call_number_token := tokens[idx+1]
            skip_token_count = 1
            call_number, ok := strconv.parse_int(call_number_token.value)
            if !ok{
                err_msg = "ERROR: A number literal must follow a syscall."
                err_token = call_number_token
                return false
            }else{
                compiler_add_inst(compiler, .SYSCALL, call_number)
            }
        case "of":
            i := 1
            for true{
                if tokens[idx+i].value == "is" do break
                compiler_local_variable_assignment(compiler, idx+i-1)
                i += 1
            }
            skip_token_count = i
        case "is":
            break
        case "const":
            num, ok := strconv.parse_int(tokens[idx+2].value) 
            if !ok{
                err_msg = "ERROR: number only inside constant literal"
                err_token = tokens[idx+2]
                return false
            }
            if tokens[idx+3].value == "offset"{
                declared_constants[tokens[idx+1].value] = iota
                iota += num
                skip_token_count = 1
                
            }else if tokens[idx+2].value == "reset"{
                declared_constants[tokens[idx+1].value] = iota
                iota = 0
            }else{
                declared_constants[tokens[idx+1].value] = num
            }
            skip_token_count += 3
        case "enum":
            i := 1
            iota = 0
            for true{
                if tokens[idx+i].value == "end" do break
                declared_constants[tokens[idx+i].value] = iota
                iota += 1
                i += 1
            }
            iota = 0
            skip_token_count = i
        case:
            err_msg = "ERROR: Keyword May Not Be Implemented"
            err_token = token
            return false
    }
    return true
}

/*
-------------------
|Utility Functions|
-------------------
*/

compiler_add_inst_i32 :: proc(using compiler: ^Compiler, operation: instructions.Op, operand: i32){
    append(&program, instructions.Instruction{operation, operand})
}
compiler_add_inst_int :: proc(using compiler: ^Compiler, operation: instructions.Op, operand: int){
    append(&program, instructions.Instruction{operation, i32(operand)})
}
compiler_add_inst_tk :: proc(using compiler: ^Compiler, operation: instructions.Op, token: Token){
    append(&program, instructions.Instruction{operation, i32_from_token(token)})
}
compiler_add_inst_str :: proc(using compiler: ^Compiler, operation: instructions.Op, str: string){
    using instructions
    append(&program, Instruction{operation, i32(len(string_bytes))})
    runes := utf8.string_to_runes(str)
    rune_data := mem.slice_to_bytes(runes)
    for b in rune_data{
        append(&string_bytes, b)
    }    
    append(&program, Instruction{operation, i32(len(rune_data))})
    delete(runes)
}

compiler_open_block :: #force_inline proc(using compiler: ^Compiler, typ: Block_Type){
    append(&open_blocks, Block{start=current_ip(&program)+1, typ=typ})
}

compiler_close_block :: proc(using compiler: ^Compiler){
    block := pop(&open_blocks)
    defer delete(block.end_references)
    defer delete(block.declared_local_names)

    for name in block.declared_local_names{
        delete_key(&declared_locals, name)
    }

    if block.typ == .WHILE{
        compiler_add_inst(compiler, .JMP, -(current_ip(&program)+1 - block.start))
        do_location := block.end_references[0]
        program[do_location].operand = (current_ip(&program)+1 - do_location)
        for i := 1; i < len(block.end_references); i += 1{
            ip := block.end_references[i]
            program[ip].operand = (current_ip(&program)+1 - ip)
        }
    }else if block.typ == .IF{
        for ip in block.end_references{
            program[ip].operand = (current_ip(&program)+1 - ip)
        }     
    }else if block.typ == .FUNCTION{
        compiler_add_inst_i32(compiler, .RET, 0)
    }else if block.typ == .MAIN_FUNCTION{
        compiler_add_inst_i32(compiler, .HALT, 0)
    }
}

block_add_end_reference :: #force_inline proc(using compiler: ^Compiler){
    append(&open_blocks[len(open_blocks)-1].end_references, current_ip(&program))
}

compiler_local_variable_assignment :: proc(using compiler: ^Compiler, idx: int) ->  bool{
    variable_token := tokens[idx+1]
    variable_name := variable_token.value
    if variable_token.typ != .ID{
        err_msg = fmt.aprintf("ERROR: Cannot assign value to a non-identifier variable name may be keyword.")
        err_token = variable_token
        return false
    }
    if variable_name in declared_locals{
        compiler_add_inst(compiler, .MVLV, declared_locals[variable_name])
    }else{
        declared_locals[variable_name] = len(declared_locals)
        append(&open_blocks[len(open_blocks)-1].declared_local_names, variable_name)
        compiler_add_inst(compiler, .MVLV, declared_locals[variable_name])
    }
    skip_token_count = 1
    return true
}

compiler_print_error :: proc(using compiler: ^Compiler){
    fmt.println(err_msg)
    fmt.printf("token: %s row: %d col: %d file: %s \n", err_token.value, err_token.row, err_token.col, err_token.file)
    os.exit(1)
}

compiler_import_file :: proc(using compiler: ^Compiler, name_token:Token){
    using name_token
    dir_root := filepath.dir(file)
    import_path := fmt.aprintf("./%s/%s.jnc", dir_root, value)
    ok := lex_file(import_path, &tokens, &special_directives)
    if !ok{
        os.exit(1)
    }
    delete(import_path)
    delete(dir_root)
}

compiler_add_inst :: proc{
    compiler_add_inst_i32,
    compiler_add_inst_int, 
    compiler_add_inst_tk, 
    compiler_add_inst_str,
}

current_ip :: #force_inline proc(program: ^[dynamic]instructions.Instruction) -> i32{
    return i32(len(program)-1)
}

compiler_delete :: proc(using compiler: ^Compiler){
    for token in tokens{
        delete(token.value)
    }
    for directive in special_directives{
        for token in directive.tokens{
            delete(token.value)
        }
        delete(directive.tokens)
    }
    delete(tokens)
    delete(special_directives)
    delete(declared_macros)
    delete(program)
    delete(open_blocks)
    delete(imported_files)
    delete(declared_locals)
    delete(declared_constants)
    delete(string_bytes)
    linker_delete(&linker)
}

compiler_save_as_text :: proc(compiler: ^Compiler, output_filepath: string) -> bool{
    fd, err := os.open(output_filepath, os.O_CREATE | os.O_TRUNC | os.O_WRONLY, 0o777)

    if err != os.ERROR_NONE{
        fmt.eprintf("ERROR: Cannot open output file %s", output_filepath)
        return false
    }
    defer os.close(fd)
    
    for inst, ip in compiler.program{
        fmt.fprintf(fd, "%d", ip)
        fmt.fprintf(fd, " %s %d \n", inst.operation, inst.operand)
    }

    return true
}


compiler_save_as_ir :: proc(compiler: ^Compiler, output_filepath: string) -> bool{
    fd, err := os.open(output_filepath, os.O_CREATE | os.O_TRUNC | os.O_WRONLY, 0o777)

    if err != os.ERROR_NONE{
        fmt.eprintf("ERROR: Cannot open output file %s", output_filepath)
        return false
    }
    defer os.close(fd)

    program_length_as_bytes := transmute([4]u8)u32le(len(compiler.program))

    os.write(fd, program_length_as_bytes[:])
    os.write(fd, mem.slice_to_bytes(compiler.program[:]))
    os.write(fd, compiler.string_bytes[:])

    return true
}