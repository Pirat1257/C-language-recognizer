%{
#include <stdio.h>
#include <string.h>
#include "y.tab.h"
int lex_line = 1;
int count = 0;

char *_STRING_buf = 0;
char *_CHARACTER_buf = 0;
_Bool _CODE_active = 1;

/*----------------Добавление_символа_в__STRING_buf----------------*/
char *add_sym(char *s, char c)
{
    if (strlen(s) == 0)
    {
        s[0] = c;
        return(s);
    }
    else
    {
        s = realloc(s, (strlen(s) + 1) * sizeof(char));
        s[strlen(s)] = c;
        return(s);
    }
}
%}

%START _STRING _CHARACTER _DIRECTIVES _CODE _COMMENTS_1 _COMMENTS_2

%%
    if(_CODE_active == 1)
    {
        _CODE_active = 0;
        BEGIN _CODE;
    }

<_CODE>[\"\'] {
    _STRING_buf = (char*)malloc(sizeof(char));
    _STRING_buf = add_sym(_STRING_buf, *yytext);
    BEGIN _STRING;
}

<_STRING>\\n {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}
<_STRING>\\r {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}
<_STRING>\\t {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}
<_STRING>\\ {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}
<_STRING>\\\" {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}
<_STRING>\\\' {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}
<_STRING>\n {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}
<_STRING>[\"\'] {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
    BEGIN _CODE;
    char *dummy = (char*)realloc('\0', sizeof(char) * strlen(_STRING_buf));
    for (int i = 0; i < strlen(_STRING_buf); i++)
        dummy[i] = _STRING_buf[i];
    free(_STRING_buf);
    yylval.str = dummy;
    if (!strcmp("\"", yytext))
        return(STRING);
    else return(CHARACTER);
}
<_STRING>. {
    _STRING_buf = add_sym(_STRING_buf, *yytext);
}

<_CODE>\/\/ {
    BEGIN _COMMENTS_1;
}

<_COMMENTS_1>\\\r*\n* ;

<_COMMENTS_1>. ;

<_COMMENTS_1>\r*\n* {
    BEGIN _CODE;
}

<_CODE>\/\* {
    BEGIN _COMMENTS_2;
}

<_COMMENTS_2>\r*\n* ;

<_COMMENTS_2>. ;

<_COMMENTS_2>\*\/ {
    BEGIN _CODE;
}

<_CODE>\#|\%\: {
    BEGIN _DIRECTIVES;
}

<_DIRECTIVES>"define"/" " {
    BEGIN _CODE;
    return (P_DEFINE);
}
<_DIRECTIVES>"undef"/" " {
    BEGIN _CODE;
    return (P_UNDEF);
}
<_DIRECTIVES>"error"/" " {
    BEGIN _CODE;
    return (P_ERROR);
}
<_DIRECTIVES>"warning"/" " {
    BEGIN _CODE;
    return (P_WARNING);
}
<_DIRECTIVES>"include"/[\"\<" "] {
    BEGIN _CODE;
    return (P_INCLUDE);
}
<_DIRECTIVES>"if"/" " {
    BEGIN _CODE;
    return (P_IF);
}
<_DIRECTIVES>"ifdef"/" " {
    BEGIN _CODE;
    return (P_IFDEF);
}
<_DIRECTIVES>"ifndef"/" " {
    BEGIN _CODE;
    return (P_IFNDEF);
}
<_DIRECTIVES>"else"/[" "\\r\\n] {
    BEGIN _CODE;
    return (P_ELSE);
}
<_DIRECTIVES>"elif"/" " {
    BEGIN _CODE;
    return (P_ELIF);
}
<_DIRECTIVES>"endif"/[\\r\\n] {
    BEGIN _CODE;
    return (P_ENDIF);
}
<_DIRECTIVES>"line"/" " {
    BEGIN _CODE;
    return (P_LINE);
}
<_DIRECTIVES>"pragma"/" " {
    BEGIN _CODE;
    return (P_PRAGMA);
}
<_DIRECTIVES>[" "\\n\\r] {
    BEGIN _CODE;
    return (P_NULL_DIRECTIVE);
}
<_DIRECTIVES>. {
    BEGIN _CODE;
    printf("ERROR _DIRECTIVES\n");
}

<_CODE>\.|\-\>|\+\+|\-\-|\<\<|\>\>|\!\=|\<\=|\>\=|\=\=|\&\&|\|\||\*\=|\/\=|\%\=|\+\=|\-\=|\<\<\=|\>\>\=|\&\=|\^\=|\|\=|\<\:|\:\>|\<\%|\%\> {
    if (!strcmp("&&", yytext))
        return(AND);
    else if (!strcmp("||", yytext))
        return(OR);
    else if (!strcmp("&=", yytext))
        return(AND_EQ);
    else if (!strcmp("|=", yytext))
        return(OR_EQ);
    else if (!strcmp("^=", yytext))
        return(XOR_EQ);
    else if (!strcmp("!=", yytext))
        return(NOT_EQ);
    else if (!strcmp("++", yytext))
        return(INC);
    else if (!strcmp("--", yytext))
        return(DEC);
    else if (!strcmp(">=", yytext))
        return(GREATER_OR_EQ);
    else if (!strcmp("<=", yytext))
        return(LOWER_OR_EQ);
    else if (!strcmp("==", yytext))
        return(EQ);
    else if (!strcmp("<<", yytext))
        return(SHIFTL);
    else if (!strcmp(">>", yytext))
        return(SHIFTR);
    else if (!strcmp("<<=", yytext))
        return(SHIFTL_EQ);
    else if (!strcmp(">>=", yytext))
        return(SHIFTR_EQ);
    else if (!strcmp("+=", yytext))
        return(ADD);
    else if (!strcmp("-=", yytext))
        return(SUB);
    else if (!strcmp("*=", yytext))
        return(MUL);
    else if (!strcmp("/=", yytext))
        return(DIV);
    else if (!strcmp("%=", yytext))
        return(MOD);
    else if (!strcmp("->", yytext))
        return(ARROW);
    
    return(*yytext);
}

<_CODE>[\&\+\-\~\!\/\%\<\>\^\|\?] {
    if (!strcmp("|", yytext))
        return(BITOR);
    else if (!strcmp("^", yytext))
        return(XOR);
    else if (!strcmp("~", yytext))
        return(COMPL);
    else if (!strcmp("&", yytext))
        return(BITAND);
    else if (!strcmp("!", yytext))
        return(NOT);

    return(*yytext);
}

<_CODE>[\[\]\(\)\{\}\,\:\;\*\=] {
    return(*yytext);
}

<_CODE>[\_a-zA-Z][\_a-zA-Z0-9]* {
    /*----------------Keywords----------------*/
    if (!strcmp("auto", yytext))
        return(AUTO);
    else if (!strcmp("break", yytext))
        return(BREAK);
    else if (!strcmp("case", yytext))
        return(CASE);
    else if (!strcmp("char", yytext))
        return(CHAR);
    else if (!strcmp("const", yytext))
        return(CONST);
    else if (!strcmp("continue", yytext))
        return(CONTINUE);
    else if (!strcmp("default", yytext))
        return(DEFAULT);
    else if (!strcmp("do", yytext))
        return(DO);
    else if (!strcmp("double", yytext))
        return(DOUBLE);
    else if (!strcmp("else", yytext))
        return(ELSE);
    else if (!strcmp("enum", yytext))
        return(ENUM);
    else if (!strcmp("extern", yytext))
        return(EXTERN);
    else if (!strcmp("float", yytext))
        return(FLOAT);
    else if (!strcmp("for", yytext))
        return(FOR);
    else if (!strcmp("goto", yytext))
        return(GOTO);
    else if (!strcmp("if", yytext))
        return(IF);
    else if (!strcmp("int", yytext))
        return(INT);
    else if (!strcmp("long", yytext))
        return(LONG);
    else if (!strcmp("register", yytext))
        return(REGISTER);
    else if (!strcmp("return", yytext))
        return(RETURN);
    else if (!strcmp("restrict", yytext))
        return(RESTRICT);
    else if (!strcmp("short", yytext))
        return(SHORT);
    else if (!strcmp("signed", yytext))
        return(SIGNED);
    else if (!strcmp("sizeof", yytext))
        return(SIZEOF);
    else if (!strcmp("static", yytext))
        return(STATIC);
    else if (!strcmp("struct", yytext))
        return(STRUCT);
    else if (!strcmp("switch", yytext))
        return(SWITCH);
    else if (!strcmp("typedef", yytext))
        return(TYPEDEF);
    else if (!strcmp("union", yytext))
        return(UNION);
    else if (!strcmp("unsigned", yytext))
        return(UNSIGNED);
    else if (!strcmp("void", yytext))
        return(VOID);
    else if (!strcmp("volatile", yytext))
        return(VOLATILE);
    else if (!strcmp("while", yytext))
        return(WHILE);
    else if (!strcmp("_Bool", yytext))
        return(_BOOL);
    /*----------------Operator_or_punctuator----------------*/
    else if (!strcmp("and", yytext))
        return(AND);
    else if (!strcmp("and_eq", yytext))
        return(AND_EQ);
    else if (!strcmp("bitand", yytext))
        return(BITAND);
    else if (!strcmp("bitor", yytext))
        return(BITOR);
    else if (!strcmp("compl", yytext))
        return(COMPL);
    else if (!strcmp("not", yytext))
        return(NOT);
    else if (!strcmp("not_eq", yytext))
        return(NOT_EQ);
    else if (!strcmp("or", yytext))
        return(OR);
    else if (!strcmp("or_eq", yytext))
        return(OR_EQ);
    else if (!strcmp("xor", yytext))
        return(XOR);
    else if (!strcmp("xor_eq", yytext))
        return(XOR_EQ);
    /*----------------Identifier----------------*/
    char *c = (char*)malloc(sizeof(char) * strlen(yytext));
    for (int i = 0; i < strlen(yytext); i++)
        c[i] = yytext[i];
    yylval.str = c;
    return(IDENTIFIER);
}

<_CODE>[0-9]+ {
    return(DIGIT);
}

<_CODE>[\n\r" "] {
    
}
%%