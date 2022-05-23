# Jounce
Stack-Based, concatenative, programming language. Built for school science fair not intended for real use in any capacity. Inspired from the Porth language written by Tsoding.

## On The Docket
- [x] refactor (readability, errors and structure)
- [] general heap allocations
- [x] move the ("putc", "puti", "puts", ...) commands into a standard library
- [x] add some syntax sugar for function parameters
- [x] improve CLI (file output name / directory location)
- [x] compile negative numbers (seems to work off rip)
- [x] simple macro system
- [] maybe some syntax sugar for multiple variable assignments (some_func -> a,b)
- [] better program error checker compile side
- [] speed optimize compiler
- [] web based visualization tool / debugger


## Installation
First you need a working Odin compiler follow the instructions on the [Odin Website.](https://odin-lang.org/)
Then clone the repository and run the build script to obtain the Junk compiler and the Jounce interpreter.
The language tools currently support Linux however it should work on Windows & Mac as well.

## Usage
Run `junk <mode> <filename> <output path>` to compile a source file. <br>
Run `jounce <filename>` to run a compiled source file. <br>

## Hello, World
```
@import stdlib/std @end

fn main is
    "Hello, World!" @puts
end
```

## Overview

### Arithmetic
The Jounce language uses reverse polish notation meaning the operator comes after the operands ex: <br>
`2 3 +` -> adds 2 and 3

### Comparison
Comparison works the same as arithmetic <br>
`a b ==` -> checks if a is equal to b

### Data Types
In Jounce everything on the stack is a number. <br>
- `true` or `false` -> pushes a 1 for true and 0 for false onto the stack
- `'a'`-> pushes ascii value of character onto the stack
- `123` -> pushes the number literal onto the stack
- `"string"` -> pushes the pointer to the start of the string and the length onto the stack

### If Statement
- `if a b == do ... end`
- `if a b == do ... else b c == do ... else ... end`

### While Loop
`while a b > do ... end` <br>
loops support `break` but do not currently support `continue`.

### Macros
`@macro my_macro ... @end`<br>
To use the macro simply put @my_macro wherever you would like.
macros happen at the token level so if statements, variables and all the like is supported.<br>
macros also support the `@macro my_macro of a b is ... @end` syntax in this context the `is` keyword is required.

### Functions
`fn my_func is ... end` <br>
In Jounce to return before the end of a function use the `ret` keyword. <br>
because the language is stack based whatever the stack contains after the function execution is available from the calling location ex: <br>
```
fn a is
    b puti
end

fn b is
    3
end
```
the 3 is available because its left on the stack after function b is complete so this would print 3 if a was called.<br>
function parameters are as follows `fn a of some_param1 some_param2 is ... end`

### Variables
`10 -> x` -> makes a new variable called x and 10 is stored <br>
`x 3 + -> x` -> adds 3 to x and stores it back in x <br>
**Note:** variables are block scoped

### Imports
`@import some_file @end` -> allows access to all the functions and macros in the other file <br>
**Note:** the imports are not namespaced so if two files both have function `f` then they will conflict.