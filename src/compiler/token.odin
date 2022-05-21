package main

import "core:strconv"

Token :: struct{
    value: string,
    typ: Token_Type,
    row: int,
    col: int,
    file: string,
}

Token_Type :: enum {
    ID, STR, CHAR, INT, BOOL, KEYWORD,
}

//returns the token type (does not return string or character that type is determined while lexing)
determine_token_type :: proc(value: string) -> Token_Type{
    //check for bool
    if value == "true" || value == "false" do return .BOOL

    //checks for int
    _, ok := strconv.parse_int(value)
    if ok do return .INT

    //checks for keyword
    for keyword in Keywords do if value == keyword do return .KEYWORD 
    
    return .ID
}

i32_from_token :: proc(token: Token) -> i32{
    if token.typ == .INT{
        val,_ := strconv.parse_int(token.value)
        return i32(val)
    }else if token.typ == .BOOL{
        if token.value == "true" do return 1
        return 0
    }else if token.typ == .CHAR{
        return i32(rune(token.value[0]))
    }else{
        return 404
    }
}

Keywords :: [?]string{"if", "do", "elif", "else", "end", "is", "+", "-", "*", "/", "fn", "==", 
"<", ">", "!=", "const", "ret", "while", "->", "import", "syscall", "of"}