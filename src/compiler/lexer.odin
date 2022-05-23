package main

import "core:os"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import "core:strconv"

Directive :: struct{
    typ: Directive_Type,
    tokens: [dynamic]Token,
}

Directive_Type :: enum {END, IMPORT, MACRO_DEF, MACRO_INVOKE}

lex_file :: proc(filename: string, token_buffer: ^[dynamic]Token, special_directives:^[dynamic]Directive) -> bool{
    filedata, ok := os.read_entire_file_from_filename(filename)
    if !ok{
        fmt.printf("ERROR: Could Not Read File %s \n", filename)
        return false
    }
    defer delete(filedata)

    source_code := string(filedata)

    lines := strings.split_lines(source_code)
    defer delete(lines)

    save_destination := token_buffer
    line_loop: for line, row in lines{
        col := 0
        for true{
            if row >= len(lines) do break line_loop
            
            token_start, value, typ := next_token(col, line)
            //len(value) does not account for quotes so this is a nessecary check
            if typ == .STR || typ == .CHAR{
                col += (token_start - col) + len(value)+2
            }else{
                col += (token_start - col) + len(value)
            }
            if len(value) > 0{
                if value[0] == '@'{
                    if value == "@end"{
                        save_destination = token_buffer
                        delete(value)
                    }else if value == "@import"{
                        directive := Directive{typ=.IMPORT}
                        append(special_directives, directive)
                        save_destination = &special_directives[len(special_directives)-1].tokens
                        delete(value)
                    }else if value == "@macro"{
                        directive := Directive{typ=.MACRO_DEF}
                        append(special_directives, directive)
                        save_destination = &special_directives[len(special_directives)-1].tokens
                        delete(value)
                    }else{
                        save_destination = token_buffer
                        append(save_destination, Token{row=row, col=token_start, file=filename, typ=typ, value=value})
                    }

                    if col >= len(line)-1 do break
                    continue
                }
            }

            //a value of "" is returned if a comment was encountered
            //system was built this way if we want comments to be tokens at some point
            if len(value) > 0 do append(save_destination, Token{row=row, col=token_start, file=filename, typ=typ, value=value})
            
            //checks to see if we are at the end of the line
            if col >= len(line)-1 do break
        }
    }
    return true
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

