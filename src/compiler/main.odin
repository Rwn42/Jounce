package main

import "core:fmt"
import "core:mem"
import "core:os"

main_2 :: proc(){
    if len(os.args) < 2{
        fmt.println("ERROR: No file specified. Run `junk help` for usage/instructions")
        os.exit(1)
    }
    file_or_command := os.args[1]
    
    if file_or_command := os.args[1]; file_or_command == "help"{
        fmt.println("-----USAGE-----")
        fmt.println("   junk <filename> <options> -> outputs a .jnci file that the interpreter can run")
        fmt.println("Currently no options are supported.")
    }else{
        compile_program(file_or_command)
    }
}   

main :: proc(){
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    main_2()

    for _, leak in track.allocation_map {
	    fmt.printf("%v leaked %v bytes\n", leak.location, leak.size)
    }
    for bad_free in track.bad_free_array {
	    fmt.printf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
    }
}