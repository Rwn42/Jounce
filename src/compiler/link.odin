package main

import "../instructions"

Linker :: struct{
    encountered_identifiers: [dynamic]Identifier,
    declared_functions: map[string]i32,
}


Identifier :: struct{
    token: Token,
    ip: i32,
}

link :: proc(using compiler: ^Compiler) -> bool{
    using instructions
    using linker
    for identifier in encountered_identifiers{
        using identifier
        if token.value in declared_functions{
            program[ip] = Instruction{.CALL, declared_functions[token.value]}
        }else{
            err_msg = "ERROR: Undeclared Identifier"
            err_token = token
            return false
        }
    }
    return true
}

linker_delete :: proc(using linker: ^Linker){
    delete(encountered_identifiers)
    delete(declared_functions)
}

