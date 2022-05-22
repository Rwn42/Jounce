package main

import "core:fmt"
import "core:mem"
import "core:os"

main_2 :: proc(){
    //make sure enough arguments were provided
    if len(os.args) < 4 do print_usage("ERROR: Not Enough Arguments")

    mode, input_filepath, output_filepath := os.args[1], os.args[2], os.args[3]

    //see what mode we rocking with
    if mode != "com" && mode != "asm" do print_usage()

    //since mode must be com or asm we can just check for the asm case and assume it will be true
    save_as_ir := true
    if mode == "asm" do save_as_ir = false

    compile_program(input_filepath, output_filepath, save_as_ir)
    fmt.println("Compilation Sucesfull!")
}

//prints usage and takes in an optional error message to be printed first
print_usage :: proc(err_msg: string = ""){
    fmt.eprintln(err_msg)
    fmt.println("USAGE")
    fmt.println("   junk <mode> <filename> <output_directory>")
    fmt.println("   Modes:")
    fmt.println("       com -> compiles it to IR for interpreter to run")
    fmt.println("       asm -> compiles to human readable text format")
    fmt.println("       help -> prints the usage")
    os.exit(1)
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