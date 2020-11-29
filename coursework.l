%{
#include <stdio.h>
#include <string.h>
#include "y.tab.h"

char *_STRING_buf = 0;
char *_CHARACTER_buf = 0;
_Bool _CODE_active = 1;
_Bool td = 0;

int line = 1;
int saved_line = 0;

/*----------------------Для передачи идентификатора и номера его строки----------------------*/
struct line_and_str
{
	int line;
    char *str;
};

%}

%START _STRING _CHARACTER _DIRECTIVES _CODE _COMMENTS_1 _COMMENTS_2 _DIGIT

%%
    if(_CODE_active == 1)
    {
        _CODE_active = 0;
        BEGIN _CODE;
    }

<_CODE>\" {
    saved_line = line;
    BEGIN _STRING;
}

<_CODE>\L\" {
    saved_line = line;
    BEGIN _STRING;
}

<_STRING>\\n ;
<_STRING>\\r ;
<_STRING>\\t ;
<_STRING>\\ ;
<_STRING>\\\" ;
<_STRING>\\\' ;
<_STRING>\\\\ ;
<_STRING>\n {
    line++;
}
<_STRING>\" {
    BEGIN _CODE;
    yylval.line = saved_line;
    return(STRING);
}
<_STRING>. ;

<_CODE>\' {
    saved_line = line;
    BEGIN _CHARACTER;
}

<_CODE>\L\' {
    saved_line = line;
    BEGIN _CHARACTER;
}

<_CHARACTER>\\n ;
<_CHARACTER>\\r ;
<_CHARACTER>\\t ;
<_CHARACTER>\\ ;
<_CHARACTER>\\\" ;
<_CHARACTER>\\\' ;
<_CHARACTER>\\\\ ;
<_CHARACTER>\n {
    line++;
}
<_CHARACTER>\' {
    BEGIN _CODE;
    yylval.line = saved_line;
    return(CHARACTER);
}
<_CHARACTER>. ;

<_CODE>\/\/ {
    BEGIN _COMMENTS_1;
}

<_COMMENTS_1>\\\r*\n* {
    for(int i = 0; i < strlen(yytext); i++)
        if(yytext[i] == 10)
            line++;
}

<_COMMENTS_1>. ;

<_COMMENTS_1>\r*\n* {
    for(int i = 0; i < strlen(yytext); i++)
        if(yytext[i] == 10)
            line++;
    BEGIN _CODE;
}

<_CODE>\/\* {
    BEGIN _COMMENTS_2;
}

<_COMMENTS_2>\r*\n* {
    for(int i = 0; i < strlen(yytext); i++)
        if(yytext[i] == 10)
            line++;
}

<_COMMENTS_2>. ;

<_COMMENTS_2>\*\/ {
    BEGIN _CODE;
}

<_CODE>\#|\%\: {
    BEGIN _DIRECTIVES;
}

<_DIRECTIVES>"define"/" " {
    BEGIN _CODE;
    yylval.line = line;
    return (P_DEFINE);
}
<_DIRECTIVES>"undef"/" " {
    BEGIN _CODE;
    yylval.line = line;
    return (P_UNDEF);
}
<_DIRECTIVES>"error"/" " {
    BEGIN _CODE;
    yylval.line = line;
    return (P_ERROR);
}
<_DIRECTIVES>"warning"/" " {
    BEGIN _CODE;
    yylval.line = line;
    return (P_WARNING);
}
<_DIRECTIVES>"include"/[\"\<" "] {
    BEGIN _CODE;
    yylval.line = line;
    return (P_INCLUDE);
}
<_DIRECTIVES>"if"/" " {
    //BEGIN _CODE;
    BEGIN _COMMENTS_1;
    yylval.line = line;
    //return (P_IF);
}
<_DIRECTIVES>"ifdef"/" " {
    //BEGIN _CODE;
    BEGIN _COMMENTS_1;
    yylval.line = line;
    //return (P_IFDEF);
}
<_DIRECTIVES>"ifndef"/" " {
    //BEGIN _CODE;
    BEGIN _COMMENTS_1;
    yylval.line = line;
    //return (P_IFNDEF);
}
<_DIRECTIVES>"else"/[" "\r\n] {
    //BEGIN _CODE;
    BEGIN _COMMENTS_1;
    //yylval.line = line;
    //return (P_ELSE);
}
<_DIRECTIVES>"elif"/" " {
    //BEGIN _CODE;
    BEGIN _COMMENTS_1;
    //yylval.line = line;
    //return (P_ELIF);
}
<_DIRECTIVES>"endif"/[\r\n" "] {
    //BEGIN _CODE;
    BEGIN _COMMENTS_1;
    //yylval.line = line;
    //return (P_ENDIF);
}
<_DIRECTIVES>"line"/" " {
    BEGIN _CODE;
    yylval.line = line;
    return (P_LINE);
}
<_DIRECTIVES>"pragma"/" " {
    BEGIN _CODE;
    yylval.line = line;
    return (P_PRAGMA);
}
<_DIRECTIVES>[" "\n\r] {
    BEGIN _CODE;
    //yylval.line = line;
    //return (P_NULL_DIRECTIVE);
}
<_DIRECTIVES>. {
    BEGIN _CODE;
    printf("Line: %d. ERROR _DIRECTIVES\n", line);
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
    {
        yylval.line = line;
        return(INC);
    }
    else if (!strcmp("--", yytext))
    {
        yylval.line = line;
        return(DEC);
    }
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
    {
        yylval.line = line;
        return(ARROW);
    }
    
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

<_CODE>[0-9][a-zA-Z][0-9a-fA-F]* {
    yylval.line = line;
    return(DIGIT); 
}

<_CODE>[\_a-zA-Z][\_a-zA-Z0-9]* {
    /*----------------Keywords----------------*/
    if (!strcmp("auto", yytext))
        return(AUTO);
    else if (!strcmp("break", yytext))
    {
        yylval.line = line;
        return(BREAK);
    }
    else if (!strcmp("case", yytext))
    {
        yylval.line = line;
        return(CASE);
    }
    else if (!strcmp("char", yytext))
    {
        yylval.line = line;
        return(CHAR);
    }
    else if (!strcmp("const", yytext))
    {
        yylval.line = line;
        return(CONST);
    }
    else if (!strcmp("continue", yytext))
    {
        yylval.line = line;
        return(CONTINUE);
    }
    else if (!strcmp("default", yytext))
    {
        yylval.line = line;
        return(DEFAULT);
    }
    else if (!strcmp("do", yytext))
    {
        yylval.line = line;
        return(DO);
    }
    else if (!strcmp("double", yytext))
    {
        yylval.line = line;
        return(DOUBLE);
    }
    else if (!strcmp("else", yytext))
    {
        yylval.line = line;
        return(ELSE);
    }
    else if (!strcmp("enum", yytext))
    {
        yylval.line = line;
        return(ENUM);
    }
    else if (!strcmp("extern", yytext))
    {
        yylval.line = line;
        return(EXTERN);
    }
    else if (!strcmp("float", yytext))
    {
        yylval.line = line;
        return(FLOAT);
    }
    else if (!strcmp("for", yytext))
    {
        yylval.line = line;
        return(FOR);
    }
    else if (!strcmp("goto", yytext))
    {
        yylval.line = line;
        return(GOTO);
    }
    else if (!strcmp("if", yytext))
    {
        yylval.line = line;
        return(IF);
    }
    else if (!strcmp("int", yytext))
    {
        yylval.line = line;
        return(INT);
    }
    else if (!strcmp("long", yytext))
    {
        yylval.line = line;
        return(LONG);
    }
    else if (!strcmp("register", yytext))
    {
        yylval.line = line;
        return(REGISTER);
    }
    else if (!strcmp("return", yytext))
    {
        yylval.line = line;
        return(RETURN);
    }
    else if (!strcmp("restrict", yytext))
        return(RESTRICT);
    else if (!strcmp("short", yytext))
    {
        yylval.line = line;
        return(SHORT);
    }
    else if (!strcmp("signed", yytext))
    {
        yylval.line = line;
        return(SIGNED);
    }
    else if (!strcmp("sizeof", yytext))
    {
        yylval.line = line;
        return(SIZEOF);
    }
    else if (!strcmp("size_t", yytext))
    {
        yylval.line = line;
        return(SIZE_T);
    }
    else if (!strcmp("static", yytext))
    {
        yylval.line = line;
        return(STATIC);
    }
    else if (!strcmp("struct", yytext))
    {
        yylval.line = line;
        return(STRUCT);
    }
    else if (!strcmp("switch", yytext))
    {
        yylval.line = line;
        return(SWITCH);
    }
    else if (!strcmp("typedef", yytext))
    {
        yylval.line = line;
        td = 1;
        //return(TYPEDEF);
    }
    else if (!strcmp("union", yytext))
    {
        yylval.line = line;
        return(UNION);
    }
    else if (!strcmp("unsigned", yytext))
    {
        yylval.line = line;
        return(UNSIGNED);
    }
    else if (!strcmp("void", yytext))
    {
        yylval.line = line;
        return(VOID);
    }
    else if (!strcmp("volatile", yytext))
    {
        yylval.line = line;
        return(VOLATILE);
    }
    else if (!strcmp("while", yytext))
    {
        yylval.line = line;
        return(WHILE);
    }
    else if (!strcmp("bool", yytext))
    {
        yylval.line = line;
        return(_BOOL);
    }
    else if (!strcmp("_Bool", yytext))
    {
        yylval.line = line;
        return(_BOOL);
    }
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
    if (td == 0) {
        yylval.las = (struct line_and_str*)malloc(sizeof(struct line_and_str));
        yylval.las->str = (char*)malloc(sizeof(char) * strlen(yytext) + 1);
        int i;
        for (i = 0; i < strlen(yytext); i++) 
            yylval.las->str[i] = yytext[i];
        yylval.las->str[i] = '\0';
        yylval.las->line = line;
        return(IDENTIFIER);
    }
    else td = 0;
}

<_CODE>[0-9][a-fA-F0-9]* {
    yylval.line = line;
    return(DIGIT);
}

<_CODE>[\n\r" "\t] {
    if (yytext[0] == 10)
        line++;
}
%%