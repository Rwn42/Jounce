package main

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

Keywords :: [?]string{"if", "do", "elif", "else", "end", "+", "-", "*", "/",}