package main 

import "core:fmt"

Compiler :: struct{
    tokens: [dynamic]Token,
}

//main application entry point
compile_program :: proc(entry_file: string){
    compiler := Compiler{}
    defer compiler_delete(&compiler)

    compiler.tokens = make([dynamic]Token)

    //get entry point tokens to parse imports
    lex_file(entry_file, &compiler.tokens)
    fmt.println(compiler.tokens)
    
}

compiler_delete :: proc(compiler: ^Compiler){
    using compiler
    for tk in tokens{
        delete(tk.value)
    }
    delete(tokens)
}