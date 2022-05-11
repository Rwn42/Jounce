package main 

import "core:fmt"

Compiler :: struct{
    tokens: [dynamic]Token,
}

//main application entry point
compile_program :: proc(entry_file: string){
    compiler := Compiler{}
    compiler.tokens = make([dynamic]Token)
    defer compiler_delete(&compiler)

    lex_file(entry_file, &compiler.tokens)
    //TODO imports
}

compiler_delete :: proc(compiler: ^Compiler){
    using compiler
    for tk in tokens{
        delete(tk.value)
    }
    delete(tokens)
}