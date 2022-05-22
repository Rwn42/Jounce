package main 

import "core:os"
import "core:fmt"

import "../instructions"

main :: proc(){
    using instructions
    
    if len(os.args) < 2{
        fmt.eprintln("ERROR: No Input File Specified.")
        os.exit(1)
    }

    vm := VM{}
    load_program(&vm, os.args[1])
    execute(&vm)
}