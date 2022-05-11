package main

import "core:os"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:strconv"

lex_file :: proc(filename: string, token_buffer: ^[dynamic]Token){
    filedata, ok := os.read_entire_file_from_filename(filename)
    if !ok{
        fmt.printf("ERROR: Could Not Read File %s \n", filename)
    }
    defer delete(filedata)

    source_code := string(filedata)

    lines := strings.split_lines(source_code)
    defer delete(lines)

    for line, row in lines{
        col := 0
        for true{
            token_start, value, typ := next_token(col, line)

            //len(value) does not account for quotes so this is a nessecary check
            if typ == .STR || typ == .CHAR{
                col += (token_start - col) + len(value)+2
            }else{
                col += (token_start - col) + len(value)
            }

            //a value of "" is returned if a comment was encountered
            //system was built this way if we want comments to be tokens at some point
            if value != "" do append(token_buffer, Token{row=row, col=token_start, file=filename, typ=typ, value=value})

            //checks to see if we are at the end of the line
            if col >= len(line)-1 do break
        }
    }
}

//starts at a given location of a string and returns the start of a token, its value, and type.
next_token :: proc(start: int, str: string) -> (int, string, Token_Type){
    token_start:int
    typ: Token_Type

    //skip whitespace
    for col := start; col < len(str); col += 1{
        if !strings.is_space(rune(str[col])){
            token_start = col
            break;
        }
    }
    
    //main parsing loop
    characters := make([dynamic]rune)
    defer delete(characters)

    for col := token_start; col < len(str); col += 1{
        ch := rune(str[col])
        if typ != .STR && typ != .CHAR{
            //non string or character literal tokens are space seperated
            //break in this context basically says the token is over
            if strings.is_space(ch){
                break
            }else if ch == '#'{
               //if a comment is encountered just skip the rest of the line
               return len(str), "", .ID
            }
        }

        if ch == '"'{
            if typ == .STR{
               break
            }else{
                typ = .STR
            }
        }else if ch == '\''{
            if typ == .CHAR{
                break
            }else{
                typ = .CHAR
            }
        }else{append(&characters, ch)}
    }
    value := utf8.runes_to_string(characters[:])

    //determine type if it hasn't been already
    if typ != .STR && typ != .CHAR{
        typ = determine_token_type(value)
    }
    return token_start, value, typ
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