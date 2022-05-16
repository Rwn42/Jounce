# Jounce
Stack-Based, concatenative, programming language. Built for school science fair not intended for real use in any capacity. Inspired from the Porth language written by Tsoding.


## Installation
First you need a working Odin compiler follow the instructions on the [Odin Website.](https://odin-lang.org/)
Then clone the repository and run the build script to obtain the Junk compiler and the Jounce interpreter.
The language tools currently support Linux however it should work on Windows & Mac as well.

## Usage
Run `junk <filename> <options>` to compile a source file. <br>
Run `jounce <filename>` to run a compiled source file. <br>
Currently no options are supported by the compiler.

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
`while a b > do ... end`

### Constants
`const my_const is 123`

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
the 3 is available because its left on the stack after function b is complete so this would print 3 if a was called.

### Variables
`10 -> x` -> makes a new variable called x and 10 is stored <br>
`x 3 + -> x` -> adds 3 to x and stores it back in x <br>
**Note:** variables are block scoped

### Imports
`import some_file` -> allows access to all the functions and constants in the other file <br>
**Note:** the imports are not namespaced so if two files both have function `f` then they will conflict.