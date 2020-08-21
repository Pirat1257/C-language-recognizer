%{
#include <stdio.h>
#include <stdlib.h>
#define YYDEBUG 1
FILE* yyin;
int find_error = 0;

struct array_info 
{
	int flexible_array;
	int storage_class;
};

struct member_declaration_info
{
	int flexible_array_used; // Если уже стоит 1, то ошибку выдать, потому что так не должно быть
	int storage_class;
};




struct expr_info
{
	char *s; // Для вывода названий, строк и т.д.
	_Bool func_call; // Вызов функции
};

struct declaration_specifiers_info
{
	_Bool type_specifier;
	_Bool storage_class;
	_Bool type_qualifier;
};

struct info
{
	_Bool what[2]; // Наличие информации:
	struct expr_info *ei; // 0 - ei
	struct declaration_specifiers_info *dsi; // 1 - dsi
	// Дополнительная информация для обработки ошибок
	_Bool storage_class_func; // Использование storage_class при обьявлении функции внутри функции
	_Bool not_using_of_brackets; // Использование скобок {} необходимо при обьявлении array
	_Bool array; // Это array
	_Bool end_empty_brackets; // В array не может быть пустых скобок в конце
	_Bool assignment; // Присваивание значения
	_Bool flexible_array; // В struct flexible array может быть только в конце
	_Bool only_flexible_array; // Для случая, когда только flexible array
	_Bool not_last_flexible_array; // Для случая, когда flexible array не последняя
};

struct info *create_point(int what)
{
	struct info *new_one = (struct info*)malloc(sizeof(struct info));
	for(int i = 0; i < 2; i++)
		new_one->what[i] = 0;
	if(what == 0) // Создание expr_info
	{
		new_one->ei = (struct expr_info*)malloc(sizeof(struct expr_info));
		new_one->what[0] = 1; // Отмечаем ei
		new_one->ei->func_call = 0;
	}
	else if (what == 1) // declaration_specifiers_info
	{
		new_one->dsi = (struct declaration_specifiers_info*)malloc(sizeof(struct declaration_specifiers_info));
		new_one->what[1] = 1; // Отмечаем dsi
		new_one->dsi->type_specifier = 0;
		new_one->dsi->storage_class = 0;
		new_one->dsi->type_qualifier = 0;
	}
	// Обнуляем доп. информацию для обработки ошибок
	new_one->storage_class_func = 0;
	new_one->not_using_of_brackets = 0;
	new_one->array = 0;
	new_one->end_empty_brackets = 0;
	new_one->assignment = 0;
	new_one->flexible_array = 0;
	new_one->only_flexible_array = 0;
	new_one->not_last_flexible_array = 0;
	return new_one;
}

%}

%start start
%token STRING DIGIT IDENTIFIER CHARACTER // "string" 123 some_name 'char'
%token P_DEFINE P_UNDEF P_ERROR P_WARNING P_INCLUDE P_IF P_IFDEF P_IFNDEF P_ELSE P_ELIF P_ENDIF P_LINE P_PRAGMA P_NULL_DIRECTIVE // #define #undef #error #include #if #ifdef #ifndef #else #elif #endif #line #pragma #
%token AUTO CHAR DOUBLE FLOAT INT LONG SHORT SIGNED SIZEOF TYPEDEF UNSIGNED VOID _BOOL SIZE_T // auto char double float int long short signed sizeof typedef unsigned void _Bool size_t
%token CASE DEFAULT IF ELSE FOR SWITCH DO WHILE // case default if else for whitch do while
%token ENUM STRUCT UNION // enum struct union
%token RESTRICT VOLATILE CONST // restrict volatile const
%token REGISTER EXTERN STATIC // register extern static
%token BREAK CONTINUE // break continue
%token RETURN GOTO // return goto
%token AND AND_EQ NOT NOT_EQ OR OR_EQ XOR_EQ EQ // && &= != || |= ^= ==
%token BITAND BITOR COMPL XOR // & | ~ ^
%token INC DEC // ++ --
%token GREATER_OR_EQ LOWER_OR_EQ // >= <=
%token SHIFTL SHIFTR SHIFTL_EQ SHIFTR_EQ  // << >> <<= >>=
%token ADD SUB MUL DIV MOD // += -= *= /= %=


%right '?' '=' ADD SUB MUL MOD DIV AND_EQ OR_EQ XOR_EQ SHIFTL_EQ SHIFTR_EQ
%right NOT COMPL SIZEOF
%left OR AND
%left BITOR XOR BITAND
%left EQ NOT_EQ
%left '<' '>'
%left GREATER_OR_EQ LOWER_OR_EQ
%left SHIFTL SHIFTR
%left INC DEC
%left '.' ARROW
%left '(' '[' '{'
%right ')' ']' '}'
%right IDENTIFIER 
%right '+' '-' '*' '/' '%'
%right ','
%left ';'


%union {
	char c;
	char *str;
	struct info *inf;
}

%type <char*> STRING IDENTIFIER CHARACTER
%type <inf> empty_func_call paremetrs var_declaration expr bin_expr unar_expr postfix_expr
%type <inf> declaration_specifiers func_declaration program square_brackets member_declaration
 
// На данный момент нельзя определить в стркутуре структуру 
// как параметр нельзя передавать storage_class
// заменить дигит на експр
// Размер массива только число или чар
// одно значение на [ эти скобки ]
// struct и union поддержиавют только storage_class и type_qualifer
// enum воспринимает только storage_class
// в expr добавить условия для lvalue, там строго что то
// В параметрах функции проверять на 
// в goto проверять является ли указателем то куда переходим
// expr в while должен быть арифметическим или указательным типом, ананал в do

%%
start: program
	{
		printf("---------------------------OOOOOOOKKKKKKK---------------------------\n");
	}
	| start program
	{
		printf("---------------------------OOOOOOOKKKKKKK---------------------------\n");
	}
	;

program: func_declaration
	| statements
	{
		$<inf>$ = create_point(-1);
	}
	| var_declaration ';'
	| structure_declaration ';'
	| enum_definition ';'
	| enum_declaration ';'
	| preprocessor
	{
		$<inf>$ = create_point(-1);
	}
	;

func_body: program
	{
		if ($<inf->storage_class_func>1 == 1)
			printf("Not C because of declared function: %s with storage class specifier in function\n", $<inf->ei->s>1);
	}
	| func_body program
	{
		if ($<inf->storage_class_func>2 == 1)
			printf("Not C because of declared function: %s with storage class specifier in function\n", $<inf->ei->s>1);
	}
	| expr ';'
	| func_body expr ';'
	;

func_declaration: declaration_specifiers expr '(' paremetrs ')' ';'
	{
		// Если при обьявлении функции использовался storage_class
		if ($<inf->dsi->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1; // Сохраняем информацию о declaration_specifiers
		$<inf->ei>$ = $<inf->ei>2; // Сохраняем информацию о названии функции
	}
	| declaration_specifiers empty_func_call ';'
	{
		if ($<inf->dsi->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf->ei>$ = $<inf->ei>2;
	}
	| declaration_specifiers expr '(' paremetrs ')' '{' '}'
	{
		if ($<inf->dsi->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf->ei>$ = $<inf->ei>2;
	}
	| declaration_specifiers empty_func_call '{' '}'
	{
		if ($<inf->dsi->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf->ei>$ = $<inf->ei>2;
	}
	| declaration_specifiers expr '(' paremetrs ')' '{' func_body '}'
	{
		if ($<inf->dsi->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf->ei>$ = $<inf->ei>2;
	}
	| declaration_specifiers empty_func_call '{' func_body '}'
	{
		if ($<inf->dsi->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf->ei>$ = $<inf->ei>2;
	}
	;

empty_func_call: expr '(' ')' // func()
	{
		// func()() - Это не С
		if($<inf->ei->func_call>1 == 1)
		{
			printf("Not C because of incorrect function: %s\n", $<inf->ei->s>1);
		}
		else
		{
			$<inf>$ = $<inf>1;
			$<inf->ei->func_call>$ = 1;
		}
	}
	;

paremetrs: var_declaration
	| var_declaration ',' var_declaration
	| paremetrs ',' var_declaration
	;

var_declaration: declaration_specifiers expr // здесь будет много условий для обработки всякий всячен
	{
		if ($<inf->array>2 == 1 && $<inf->not_using_of_brackets>2 == 1)
			printf("Not C because of invalid initializer in declaration of array: %s\n", $<inf->ei->s>2);
		$<inf->assignment>1 = $<inf->assignment>2;
		$<inf->flexible_array>1 = $<inf->flexible_array>2;
	}
	| var_declaration ',' expr               // смотрим что за тип, делаем проверку
	{
		if ($<inf->assignment>1 == 0)
			$<inf->assignment>1 = $<inf->assignment>3;
		if ($<inf->flexible_array>1 == 0)
			$<inf->flexible_array>1 = $<inf->flexible_array>3;
	}
	;

square_brackets: '[' ']'
	{
		$<inf>$ = create_point(-1);
		$<inf->flexible_array>$ = 1;
	}
	| '[' expr ']'
	{
		$<inf>$ = create_point(-1);
	}
	| square_brackets '[' expr ']'
	| square_brackets '[' ']' // Это ошибка, пустая скобка в массиве может быть только первая
	{
		$<inf->end_empty_brackets>1 = 1;
	}
	;

structure_declaration: STRUCT IDENTIFIER '{' member_declaration '}'
	{
		if ($<inf->assignment>4 == 1)
			printf("Not C because of invalid declaration in structure: %s\n", $<str>2);
		if ($<inf->only_flexible_array>4 == 1)
			printf("Not C because of flexible array member in otherwise empty structure: %s\n", $<str>2);
		if ($<inf->not_last_flexible_array>4 == 1)
			printf("Not C because of flexible array member not at end of structure: %s\n", $<str>2);
	}
	| STRUCT '{' member_declaration '}'
	{
		if ($<inf->assignment>3 == 1)
			printf("Not C because of invalid declaration in structure\n");
		if ($<inf->only_flexible_array>3 == 1)
			printf("Not C because of flexible array member in otherwise empty structure\n");
		if ($<inf->not_last_flexible_array>3 == 1)
			printf("Not C because of flexible array member not at end of structure\n");
	}
	| UNION IDENTIFIER '{' member_declaration '}'
	{
		if ($<inf->assignment>4 == 1)
			printf("Not C because of invalid declaration in union: %s\n", $<str>2);
		if ($<inf->only_flexible_array>4 == 1)
			printf("Not C because of flexible array member in otherwise empty union: %s\n", $<str>2);
		if ($<inf->not_last_flexible_array>4 == 1)
			printf("Not C because of flexible array member not at end of union: %s\n", $<str>2);
	}
	| UNION '{' member_declaration '}'
	{
		if ($<inf->assignment>3 == 1)
			printf("Not C because of invalid declaration in union\n");
		if ($<inf->only_flexible_array>3 == 1)
			printf("Not C because of flexible array member in otherwise empty union\n");
		if ($<inf->not_last_flexible_array>3 == 1)
			printf("Not C because of flexible array member not at end of union\n");
	}
	| STRUCT IDENTIFIER '{' '}'
	| STRUCT '{' '}'
	| UNION IDENTIFIER '{' '}'
	| UNION '{' '}'
	;

member_declaration: var_declaration ';'
	{
		if ($<inf->flexible_array>1 == 1) // Случай, когда только flexible_array
			$<inf->only_flexible_array>1 = 1;
	}
	| var_declaration ':' expr ';'
	{
		if ($<inf->flexible_array>1 == 1)
			$<inf->only_flexible_array>1 = 1;
	}
	| member_declaration var_declaration ';'
	{
		$<inf->only_flexible_array>1 = 0; // Так как это уже не случай, когда только flexible_array
		if ($<inf->assignment>1 == 0)
			$<inf->assignment>1 = $<inf->assignment>2;
		if ($<inf->flexible_array>1 == 1) // Когда flexible_array не является последним элементом
			$<inf->not_last_flexible_array>1 = 1;
		$<inf->flexible_array>1 = $<inf->flexible_array>2;
	}
	| member_declaration var_declaration ':' expr ';'
	{
		$<inf->only_flexible_array>1 = 0;
		if ($<inf->assignment>1 == 0)
			$<inf->assignment>1 = $<inf->assignment>2;
		if ($<inf->flexible_array>1 == 1)
			$<inf->not_last_flexible_array>1 = 1;
		$<inf->flexible_array>1 = $<inf->flexible_array>2;
	}
	;

enum_declaration: ENUM IDENTIFIER '{' enumerator '}' // enum enum_name {...}
	| ENUM '{' enumerator '}'                        // enum {...}
	;

enum_definition: declaration_specifiers ENUM IDENTIFIER IDENTIFIER // storage_class enum enum_name a
	| ENUM IDENTIFIER IDENTIFIER 								   // enum enum_name a
	| declaration_specifiers enum_declaration IDENTIFIER           // storage_class enum [enum_name] {...} a
	| enum_declaration IDENTIFIER                                  // enum [enum_name] {...} a
	| enum_definition ',' IDENTIFIER                               // [storage_class] enum enum_name a, b, c
	| enum_definition '=' IDENTIFIER                               // [storage_class] enum [enum_name] {...} a = smth_from {...}
	;

enumerator: IDENTIFIER                   // { name }
	| enumerator ',' IDENTIFIER          // { name_1, name_2 }
	| IDENTIFIER '=' expr                // { name = 12 } - может быть равен числу
	| enumerator ',' IDENTIFIER '=' expr // { name_1, name_2 = 12}
	;

declaration_specifiers: type_specifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_specifier>$ = 1;
	}
	| storage_class
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->storage_class>$ = 1;
	}
	| type_qualifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_qualifier>$ = 1;
	}
	| type_specifier storage_class
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_specifier>$ = 1;
		$<inf->dsi->storage_class>$ = 1;
	}
	| storage_class type_specifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->storage_class>$ = 1;
		$<inf->dsi->type_specifier>$ = 1;
	}
	| type_specifier type_qualifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_specifier>$ = 1;
		$<inf->dsi->type_qualifier>$ = 1;
	}
	| type_qualifier type_specifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_qualifier>$ = 1;
		$<inf->dsi->type_specifier>$ = 1;
	}
	| type_specifier storage_class type_qualifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_specifier>$ = 1;
		$<inf->dsi->storage_class>$ = 1;
		$<inf->dsi->type_qualifier>$ = 1;
	}
	| storage_class type_specifier type_qualifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->storage_class>$ = 1;
		$<inf->dsi->type_specifier>$ = 1;
		$<inf->dsi->type_qualifier>$ = 1;
	}
	| storage_class type_qualifier type_specifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->storage_class>$ = 1;
		$<inf->dsi->type_qualifier>$ = 1;
		$<inf->dsi->type_specifier>$ = 1;
	}
	| type_qualifier storage_class type_specifier
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_qualifier>$ = 1;
		$<inf->dsi->storage_class>$ = 1;
		$<inf->dsi->type_specifier>$ = 1;
	}
	| type_specifier type_qualifier storage_class
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_specifier>$ = 1;
		$<inf->dsi->type_qualifier>$ = 1;
		$<inf->dsi->storage_class>$ = 1;
	}
	| type_qualifier type_specifier storage_class
	{
		$<inf>$ = create_point(1);
		$<inf->dsi->type_qualifier>$ = 1;
		$<inf->dsi->type_specifier>$ = 1;
		$<inf->dsi->storage_class>$ = 1;
	}
	;

expr: bin_expr
	| unar_expr
	| postfix_expr
	| '(' expr ')'
	{
		$<inf>$ = $<inf>2;
	}
	| DIGIT
	| STRING
	| CHARACTER
	| IDENTIFIER
	{
		$<inf>$ = create_point(0);
		$<inf->ei->s>$ = $<str>1;
	}
	;

bin_expr: expr '*' expr           // multiplication
	| expr '/' expr               // division
	// | expr '%' expr               // modulo
	| expr '+' expr               // binary addition
	| expr '-' expr               // binary subtraction
	| expr SHIFTL expr            // bitwise shift left
	| expr SHIFTR expr            // bitwise shift right
	| expr '<' expr               // less than
	| expr LOWER_OR_EQ expr       // less than or equal to
	| expr '>' expr               // more than
	| expr GREATER_OR_EQ expr     // more than or equal to
	| expr EQ expr                // equal
	| expr NOT_EQ expr            // not equal
	| expr BITAND expr        	  // bitwise AND
	| expr XOR expr               // bitwise exclusive OR
	| expr BITOR expr             // bitwise inclusive OR
	| expr AND expr               // logical AND
	| expr OR expr            	  // logical inclusive OR
	| expr '?' expr ':' expr      // conitional expression
	| expr '=' expr               // simple assignment
	{
		$<inf->not_using_of_brackets>1 = 1;
		$<inf->assignment>1 = 1;
	}
	| expr '=' '{' expr '}'       // simple assignment
	{
		$<inf->assignment>1 = 1;
	}
	| expr MUL expr               // multiply and assign
	| expr DIV expr               // divide and assign
	| expr MOD expr               // modulo and assign
	| expr ADD expr               // add and assign
	| expr SUB expr               // subtract and assign
	| expr SHIFTL_EQ expr         // shift left and assign
	| expr SHIFTR_EQ expr         // shift right and assign
	| expr AND_EQ expr            // bitwise AND and assign
	| expr XOR_EQ expr            // bitwise exclusive OR and assign
	| expr OR_EQ expr             // bitwise inclusive OR and assign
	;

unar_expr: SIZEOF expr              // size of object in bytes
	{
		$<inf>$ = $<inf>2;
	}
	| SIZEOF '(' type_specifier ')' // size of type in bytes
	{
		$<inf>$ = $<inf>3;
	}
	| INC expr                      // prefix increment
	{
		$<inf>$ = $<inf>2;
	}
	| DEC expr                      // prefix decrement
	{
		$<inf>$ = $<inf>2;
	}
	| COMPL expr                    // bitwise negation
	{
		$<inf>$ = $<inf>2;
	}
	| NOT expr                      // not
	{
		$<inf>$ = $<inf>2;
	}
	| '-' expr                      // unary minus
	{
		$<inf>$ = $<inf>2;
	}
	| '+' expr                      // unary plus
	{
		$<inf>$ = $<inf>2;
	}
	| BITAND expr                   // address of
	{
		$<inf>$ = $<inf>2;
	}
	| '*' expr                      // indirection or dereference
	{
		$<inf>$ = $<inf>2;
	}
	| '*' RESTRICT expr             // using of restrict
	{
		$<inf>$ = $<inf>3;
	}
	| '(' type_specifier ')' expr   // type conversion
	{
		$<inf>$ = $<inf>4;
	}
	;

postfix_expr: expr '.' expr       // member selection
	| expr ARROW expr             // member selection
	| expr square_brackets        // subscripting
	{
		$<inf->array>1 = 1;
		$<inf->flexible_array>1 = $<inf->flexible_array>2;
		if($<inf->end_empty_brackets>2 == 1) // Пустая скобка не идет первой
			printf("Not C because of incorrect usage of array: %s\n", $<inf->ei->s>1);
	}
	| expr '(' func_arg ')'       // function call
	| empty_func_call             // function call
	| type_specifier '(' expr ')' // value construction
	| expr INC                    // postfix increment
	| expr DEC                    // postfix decrement
	;

func_arg: expr ',' expr
	| func_arg ',' expr
	;

storage_class: REGISTER
	| EXTERN
	| STATIC
	;

type_qualifier: VOLATILE
	| CONST
	;

statements: labels
	| if
	| switch
	| while
	| do
	| for
	| BREAK ';'
	| CONTINUE ';'
	| RETURN expr ';'
	| RETURN ';' 
	| RETURN '(' ')' ';'
	| GOTO expr ';'
	;

labels: IDENTIFIER ':' ';'
	| IDENTIFIER ':' statements
	| CASE expr ':' statements // expr должен быть константным
	| DEFAULT ':' statements
	;

if: IF '(' expr ')' expr ';'
	| IF '(' expr ')' '{' func_body '}'
	| if ELSE if
	| if ELSE expr ';'
	| if ELSE '{' func_body '}'
	;

switch: SWITCH '(' expr ')'  '{' switch_body '}'
	;

switch_body: CASE expr ':'
	| CASE expr ':' case_body
	| switch_body CASE expr ':' case_body
	| DEFAULT ':' case_body
	| switch_body DEFAULT ':' case_body
	;

case_body: expr ';'
	| case_body expr ';'
	| case_body BREAK ';'
	;

while: WHILE '(' expr ')' expr ';'
	| WHILE '(' expr ')' '{' func_body '}'
	;

do: DO expr	';' WHILE '(' expr ')' ';'
	| DO '{' func_body '}' WHILE '(' expr ')' ';'
	;

for: FOR '(' for_expr_1 ';' for_expr_2 ';' for_expr_3 ')' expr ';'
	| FOR '(' for_expr_1 ';' for_expr_2 ';' for_expr_3 ')' '{' func_body '}'
	;

for_expr_1: 
	| var_declaration // initialization expression
	;

for_expr_2: 
	| expr // conditional expression
	;

for_expr_3: 
	| expr // optional expression
	;

preprocessor: define
	| undef
	| _error
	| warning
	| include
	| line
	| pragma
	;

define: P_DEFINE IDENTIFIER expr
	| P_DEFINE IDENTIFIER '(' for_define ')' expr
	;

for_define: 
	| IDENTIFIER
	| for_define ',' IDENTIFIER
	;

undef: P_UNDEF IDENTIFIER
	;

_error: P_ERROR STRING
	;

warning: P_WARNING STRING
	;

include: P_INCLUDE STRING         // "file_name"
	| P_INCLUDE '<' file_name '>' // <file_name> <header_name>
	| include IDENTIFIER          // identifiers
	;

file_name: IDENTIFIER
	| file_name IDENTIFIER
	| file_name '\\'
	| file_name '/'
	| file_name '.'
	;

line: P_LINE DIGIT
	| P_LINE STRING
	;

pragma: P_PRAGMA IDENTIFIER
	| pragma IDENTIFIER
	;
 
type_specifier: CHAR
	| SIGNED CHAR
	| UNSIGNED CHAR
	| SHORT
	| SHORT INT
	| SIGNED SHORT
	| SIGNED SHORT INT
	| UNSIGNED SHORT
	| UNSIGNED SHORT INT
	| INT
	| SIGNED
	| SIGNED INT
	| UNSIGNED
	| UNSIGNED INT
	| LONG
	| LONG INT
	| SIGNED LONG
	| SIGNED LONG INT
	| UNSIGNED LONG
	| UNSIGNED LONG INT
	| LONG LONG
	| LONG LONG INT
	| SIGNED LONG LONG
	| SIGNED LONG LONG INT
	| UNSIGNED LONG LONG
	| UNSIGNED LONG LONG INT
	| FLOAT
	| DOUBLE
	| LONG DOUBLE
	| _BOOL
	| VOID
	| SIZE_T
	| STRUCT IDENTIFIER
	| ENUM IDENTIFIER
	| UNION IDENTIFIER
	;

%%

main()
{
	#if YYDEBUG
	// yydebug = 1;
	#endif
	yyin = fopen("input.txt", "r");
	yyparse();
}

yyerror(char *s)
{
	fprintf(stderr, "%s. Not C.\n", s);
}

yywrap()
{
	fclose(yyin);
	return(1);
}