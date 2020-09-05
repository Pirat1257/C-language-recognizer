%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define YYDEBUG 1
FILE* yyin;
int find_error = 0;
int this_is_define = 0;
int increased_lvl = 0; // Если ноль, то при свертке в func_body увеличивается уровень, если больше 0, то он уже увеличен

// Так, в варианте int s = 12 выдаст ошибку мол s не существует. Необходимо создать структуру, хранящую строку с текстом ошибки. Вывод ошибок из этой структуры
// производить при свертке этого expr куда либо. Либо не делать проверку при присваивании и указать это в работе.

struct identifier
{
	char *s;
	struct identifier *pnext;
};

void print_identifier(struct identifier *dummy)
{
	while (1)
	{
		printf("%s ", dummy->s);
		if (dummy->pnext != NULL)
			dummy = dummy->pnext;
		else break;
	}
	printf("\n");
}

// Информация об обьявлениях
struct declaration_info
{
	int lvl_id; // Индификатор-уровень, для глобальных функций и переменных это 0, дальше 1 и тд
	        	// Удалять информацию при покидании уровня, где были обьявления, ориентируясь на lvl_id хранящийся в info
	struct identifier *vars;    // Лист переменных уровня id
	struct identifier *funcs;   // Лист функций уровня id
	struct identifier *structs; // Лист структур уровня id
	struct identifier *pnext;   // Следующий уровень
};
struct declaration_info *id = NULL; // Глобальная переменная для хранения информаци об объявлениях
int global_lvl_id = 0; // Глобальный уровень обьявлений, при отсутствующем уровне в func_body, увеличиваем на 1 и присваиваем новому
					   // Когда же сворачиваем, т.е. покидаем уровень, сначала удаляем информацию псоледнего уровня, затем уменьшаем счетчик
					   // Самый высокий уровень равен 0, это уровень глобальных переменных

/*----------------------Добавление названия в identifier----------------------*/
struct identifier *add_name(struct identifier *head, char *new_name)
{
	if (head == NULL) // Если имени еще не было
	{
		head = (struct identifier*)malloc(sizeof(struct identifier));
		head->s = new_name;
		head->pnext = NULL;
	}
	else // Если имя уже есть и надо добавить еще (пример: int x, y;), то идем до конца и добавляем
	{
		struct identifier *dummy = head;
		while (dummy->pnext != NULL)
		{
			dummy = dummy->pnext;
		}
		dummy->pnext = (struct identifier*)malloc(sizeof(struct identifier));
		dummy = dummy->pnext;
		dummy->s = new_name;
		dummy->pnext = NULL;
	}
	return head;
}

/*----------------------Добавление информации об обьявлениях----------------------*/
void add_lvl_info(int what,  // 0 - vars, 1 - funcs, 2 - structs
	struct identifier *name) // Название
{
	// Не забыть сделать удаление из временного хранилища при добавлении информации !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
	// Если еще не была создана глобальная id, то создаем ее
	if (id == NULL)
	{		
		id = (struct declaration_info*)malloc(sizeof(struct declaration_info));
		id->lvl_id = 0;
		id->vars = NULL;
		id->funcs = NULL;
		id->structs = NULL;
		id->pnext = NULL;
	}
	struct declaration_info *dummy = id; // Будем работать с пустышкой
	// Поиск необходимого уровня
	while(dummy->pnext != NULL)
	{
		if (dummy->lvl_id == global_lvl_id)
			break;
		else if (dummy->pnext != NULL)
			dummy = dummy->pnext;
		else break;
	}
	// Если не нашли, создаем
	if (dummy->lvl_id != global_lvl_id)
	{
		dummy->pnext = (struct declaration_info*)malloc(sizeof(struct declaration_info));
		dummy = dummy->pnext;
		dummy->lvl_id = global_lvl_id;
		dummy->vars = NULL;
		dummy->funcs = NULL;
		dummy->structs = NULL;
		dummy->pnext = NULL;
	}

	if (what == 0) // Для переменных
	{
		while(1) // Проходим по всем названиям переменыых
		{
			
			dummy->vars = add_name(dummy->vars, name->s); // Добавляем название переменной
			if (name->pnext != NULL)
				name = name->pnext;
			else break;
		}
	}
	else if (what == 1) // Для функций
	{
		// dummy->funcs = add_name(dummy->funcs, s);
	}
	else // Для структур
	{
		// dummy->structs = add_name(dummy->structs, s);
	}
}

/*----------------------Удаление информации об обьявлениях----------------------*/
void del_lvl_info()
{
	struct declaration_info *dummy = id, *dummy2 = NULL;
	if (id == NULL) // Если не было еще обьявлений, но зпросили удаление
		return;
	while(dummy->lvl_id != global_lvl_id)
	{
		if (dummy->pnext != NULL)
		{
			dummy2 = dummy;
			dummy = dummy->pnext;
		}
		else 
			return; // Если дошли до конца, значит объявлений на последнем уровне просто не было
	}
	if (dummy == id) // Если удаляется главный элемент
	{
		free(dummy);
		id = NULL;
	}
	else
	{
		free(dummy);
		dummy2->pnext = NULL;
	}
}

/*----------------------Поиск имени в глобальной переменной----------------------*/
_Bool find_name(int what, char *s)
{
	struct declaration_info *dummy = id; // Будем работать с пустышкой
	if (dummy != NULL) // Если id существует, то выполняем поиск
	{
		while (1) // Проходим по всем уровням 
		{
			if (what == 0 && dummy->vars != NULL) // Если работаем с переменными и они вообще есть на этом уровне
			{
				struct identifier *dummy2 = dummy->vars;
				while (1) // Проходим по всем названиям переменных рассматриваемого уровня
				{
					if (!strcmp(dummy2->s, s)) // Нашли совпадение, возвращаем true
						return 1;
					if (dummy2->pnext != NULL)
						dummy2 = dummy2->pnext; // Смотрим есть ли еще названия
					else break; // В противном случае выходим из данного уровня
				}
			}
			if (dummy->pnext != NULL) // Не нашли совпадения на данном уровне
				dummy = dummy->pnext; // Если есть еще уровни, идем дальше
			else // В противном случае ошибка, так как уровни закончились, а совпадения не было
				return 0;
		}
	}
	else // В противном случае ошибка, так как сравнивать вообще не с чем
	{
		return 0;
	}
}

struct info
{
	struct identifier *name; // Для вывода названий, строк и т.д.
	int what_decl;           // Если это объявление, то какое: 0 - var_declaration, 1 - func_declaration, 2 - structure_declaration
	_Bool func_call;         // Это выражение является вызовом функции
	int what_expr;           // Если это выражение, то какое: 0 - IDENTIFIER, 1 - func_call, -1 - пока никакое, уже проверили,
	// Информация об использовании declaration specifiers при обьявлениях
	_Bool type_specifier;
	_Bool storage_class;
	_Bool type_qualifier;
	// Дополнительная информация для обработки ошибок
	_Bool storage_class_func;      // Использование storage_class при обьявлении функции внутри функции
	_Bool not_using_of_brackets;   // Использование скобок {} необходимо при обьявлении array
	_Bool array;                   // Это array
	_Bool end_empty_brackets;      // В array не может быть пустых скобок в конце
	_Bool assignment;              // Присваивание значения
	_Bool flexible_array;          // В struct flexible array может быть только в конце
	_Bool only_flexible_array; 	   // Для случая, когда только flexible array
	_Bool not_last_flexible_array; // Для случая, когда flexible array не последняя
	_Bool using_float;             // Для случая, когда в битовом поле задан float
	int lvl_id;                    // Индификатор уровня обьявлений
};

void check_declaration(struct info *inf)
{
	if (this_is_define == 1)
		return;
	if (inf->what_expr == 0) // Если рассматриваемое выражение переменная
	{
		if (find_name(0, inf->name->s) == 0) // Не нашли ее обьявления
			printf("Not C because used undeclared variable: %s\n", inf->name->s);
	}
}

/*----------------------Создание узла для хранения информации о выражении----------------------*/
struct info *create_point()
{
	struct info *new_one = (struct info*)malloc(sizeof(struct info));
	new_one->name = NULL;
	new_one->what_decl = -1;
	new_one->what_expr = -1;
	new_one->func_call = 0;
	new_one->type_specifier = 0;
	new_one->storage_class = 0;
	new_one->type_qualifier = 0;
	// Обнуляем доп. информацию для обработки ошибок
	new_one->storage_class_func = 0;
	new_one->not_using_of_brackets = 0;
	new_one->array = 0;
	new_one->end_empty_brackets = 0;
	new_one->assignment = 0;
	new_one->flexible_array = 0;
	new_one->only_flexible_array = 0;
	new_one->not_last_flexible_array = 0;
	new_one->using_float = 0;
	new_one->lvl_id = -1;
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
%left '(' '[' '{'
%right ')' ']' '}'
%right IDENTIFIER 
%right '+' '-' '*' '/' '%'
%left '.' ARROW
%right ','
%left ';'

%union {
	char c;
	char *str;
	struct info *inf;
}

%type <char*> STRING IDENTIFIER CHARACTER defien_with_identefier
%type <inf> empty_func_call paremetrs var_declaration expr bin_expr unar_expr postfix_expr type_specifier
%type <inf> declaration_specifiers func_declaration program square_brackets member_declaration
 
// На данный момент нельзя определить в стркутуре структуру 
// как параметр нельзя передавать storage_class
// заменить дигит на експр
// Размер массива только число или чар
// одно значение на [ эти скобки ]
// enum воспринимает только storage_class
// в expr добавить условия для lvalue, там строго что то
// В параметрах функции проверять на 
// в goto проверять является ли указателем то куда переходим
// expr в while должен быть арифметическим или указательным типом, ананал в do
// Добавлять новую инфу о переменных и функциях постоянно 
// Добавлять блочно, хранить в func_body, вышли из for, удалили то что было связано с func_body этого for

// Общий для всех, но хранить отдельно в func_body
// Отдельная привязка к program, которая уже если будет сворачиваться в start, то значит глобальная херня, если же в func_body, то внутренняя
// Глобально, то что свернулось в start глобальное, под номером 0 наверное
// Если сворачивается в func_body, то добавляется в уже существующий его список переменных функций и тп
// Если такого нет, то создается новыйи добавляется
// Вообще можно хранить id
// Создать отдельный список, в который будут записываться названия функций. При обработке записываем название, и при обработке тела функции обращаемся к этому списку, для обработки рекурсии
// Касатлеьно проверки в структуре, можно дотащить названия до свертки структуры чтобы сравнить с названием, если конечно не было совпадения при первой обработке.
// Иметь ввиду параметры, они уже могут увеличить lvl_id, хотя лучше хранить их во временном листе
// Проверку вызова функции на корректность с параметрами или без, можно количество параметров чекать
// Ошибку отсутствия ;
// ГОТОВО

%%
start: program
	{
		add_lvl_info($<inf->what_decl>1, $<inf->name>1);
	}
	| start program
	;

program: func_declaration
	| statements
	{
		$<inf>$ = create_point();
	}
	| var_declaration ';'
	{
		$<inf->what_decl>1 = 0;
	}
	| structure_declaration ';'
	| enum_definition ';'
	| enum_declaration ';'
	| preprocessor
	{
		$<inf>$ = create_point();
	}
	;

func_body: program
	{
		if (increased_lvl == 0) // Если параметров не было, то увеличиваем уровень
			global_lvl_id++;
		if ($<inf->what_decl>1 == 0)
		{
			add_lvl_info(0, $<inf->name>1);
		}
		if ($<inf->storage_class_func>1 == 1)
			printf("Not C because of declared function: %s with storage class specifier in function\n", $<inf->name->s>1);
	}
	| func_body program
	{
		if ($<inf->what_decl>2 == 0)
		{
			add_lvl_info(0, $<inf->name>1);
		}
		if ($<inf->storage_class_func>2 == 1)
			printf("Not C because of declared function: %s with storage class specifier in function\n", $<inf->name->s>1);
	}
	| expr ';'
	{
		if (increased_lvl == 0)
			global_lvl_id++;
	}
	| func_body expr ';'
	;

func_declaration: declaration_specifiers expr '(' paremetrs ')' ';'
	{
		// Если при обьявлении функции использовался storage_class
		if ($<inf->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1; // Сохраняем информацию о declaration_specifiers
		$<inf>$ = $<inf>2; // Сохраняем информацию о названии функции
		increased_lvl--; // Отмечаем, что одно из досрочных увеличений уровня отменяется
		del_lvl_info();    // Из-за параметров повышен уровень, удаляем последний уровень
		global_lvl_id--;   // Уменьшаем уровень, т.к. обработали функцию
	}
	| declaration_specifiers empty_func_call ';'
	{
		// Не делаем уменьшение уровня, т.к. он не повышался ни в параметрах ни в теле функции
		if ($<inf->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf>$ = $<inf>2;
	}
	| declaration_specifiers expr '(' paremetrs ')' '{' '}'
	{
		if ($<inf->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf>$ = $<inf>2;
		increased_lvl--;
		del_lvl_info();
		global_lvl_id--;
	}
	| declaration_specifiers empty_func_call '{' '}'
	{
		if ($<inf->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf>$ = $<inf>2;
	}
	| declaration_specifiers expr '(' paremetrs ')' '{' func_body '}'
	{
		if ($<inf->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf>$ = $<inf>2;
		increased_lvl--;
		del_lvl_info();
		global_lvl_id--;
	}
	| declaration_specifiers empty_func_call '{' func_body '}'
	{
		if ($<inf->storage_class>1 == 1)
			$<inf->storage_class_func>1 = 1;
		$<inf>$ = $<inf>1;
		$<inf>$ = $<inf>2;
		del_lvl_info();
		global_lvl_id--;
	}
	;

empty_func_call: expr '(' ')' // func()
	{
		// func()() - Это не С
		if($<inf->func_call>1 == 1)
		{
			printf("Not C because of incorrect function: %s\n", $<inf->name->s>1);
		}
		else
		{
			$<inf>$ = $<inf>1;
			$<inf->func_call>$ = 1;
			$<inf->what_expr>$ = 1;
		}
	}
	;

paremetrs: var_declaration
	{
		global_lvl_id++; // Заносим обьявление переменных на следующий уровень
		add_lvl_info(0, $<inf->name>1); // Необходимо для корректной обработки переменных внутри функции
		increased_lvl++; // Отмечаем что увеличили уровень в параметрах
	}
	| var_declaration ',' var_declaration
	{
		global_lvl_id++;
		add_lvl_info(0, $<inf->name>1);
		add_lvl_info(0, $<inf->name>3);
		increased_lvl++;
	}
	| paremetrs ',' var_declaration
	{
		add_lvl_info(0, $<inf->name>3); // Уровень уже увеличен
	}
	;

var_declaration: declaration_specifiers expr
	{
		if ($<inf->array>2 == 1 && $<inf->not_using_of_brackets>2 == 1)
			printf("Not C because of invalid initializer in declaration of array: %s\n", $<inf->name->s>2);
		$<inf->assignment>1 = $<inf->assignment>2;
		$<inf->flexible_array>1 = $<inf->flexible_array>2;
		$<inf->name>1 = add_name($<inf->name>1, $<inf->name->s>2); // Добавляем название переменной
	}
	| var_declaration ',' expr
	{
		if ($<inf->assignment>1 == 0)
			$<inf->assignment>1 = $<inf->assignment>3;
		if ($<inf->flexible_array>1 == 0)
			$<inf->flexible_array>1 = $<inf->flexible_array>3;
		$<inf->name>1 = add_name($<inf->name>1, $<inf->name->s>3); // Если переменных несколько, то добавляем еще
	}
	;

square_brackets: '[' ']'
	{
		$<inf>$ = create_point();
		$<inf->flexible_array>$ = 1;
	}
	| '[' expr ']'
	{
		$<inf>$ = create_point();
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
		if ($<inf->storage_class>4 == 1)
			printf("Not C because of storage class member in structure: %s\n", $<str>2);
	}
	| STRUCT '{' member_declaration '}'
	{
		if ($<inf->assignment>3 == 1)
			printf("Not C because of invalid declaration in structure\n");
		if ($<inf->only_flexible_array>3 == 1)
			printf("Not C because of flexible array member in otherwise empty structure\n");
		if ($<inf->not_last_flexible_array>3 == 1)
			printf("Not C because of flexible array member not at end of structure\n");
		if ($<inf->storage_class>3 == 1)
			printf("Not C because of storage class member in structure\n");
	}
	| UNION IDENTIFIER '{' member_declaration '}'
	{
		if ($<inf->assignment>4 == 1)
			printf("Not C because of invalid declaration in union: %s\n", $<str>2);
		if ($<inf->only_flexible_array>4 == 1)
			printf("Not C because of flexible array member in otherwise empty union: %s\n", $<str>2);
		if ($<inf->not_last_flexible_array>4 == 1)
			printf("Not C because of flexible array member not at end of union: %s\n", $<str>2);
		if ($<inf->storage_class>4 == 1)
			printf("Not C because of storage class member in union: %s\n", $<str>2);
	}
	| UNION '{' member_declaration '}'
	{
		if ($<inf->assignment>3 == 1)
			printf("Not C because of invalid declaration in union\n");
		if ($<inf->only_flexible_array>3 == 1)
			printf("Not C because of flexible array member in otherwise empty union\n");
		if ($<inf->not_last_flexible_array>3 == 1)
			printf("Not C because of flexible array member not at end of union\n");
			if ($<inf->storage_class>3 == 1)
			printf("Not C because of storage class member in union\n");
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
		if ($<inf->storage_class>1 == 0) // Когда storage_class в struct
			$<inf->storage_class>1 = $<inf->storage_class>2;
	}
	| member_declaration var_declaration ':' expr ';'
	{
		$<inf->only_flexible_array>1 = 0;
		if ($<inf->assignment>1 == 0)
			$<inf->assignment>1 = $<inf->assignment>2;
		if ($<inf->flexible_array>1 == 1)
			$<inf->not_last_flexible_array>1 = 1;
		$<inf->flexible_array>1 = $<inf->flexible_array>2;
		if ($<inf->storage_class>1 == 0)
			$<inf->storage_class>1 = $<inf->storage_class>2;
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
		$<inf>$ = create_point();
		$<inf->type_specifier>$ = 1;
	}
	| storage_class
	{
		$<inf>$ = create_point();
		$<inf->storage_class>$ = 1;
	}
	| type_qualifier
	{
		$<inf>$ = create_point();
		$<inf->type_qualifier>$ = 1;
	}
	| type_specifier storage_class
	{
		$<inf>$ = create_point();
		$<inf->type_specifier>$ = 1;
		$<inf->storage_class>$ = 1;
	}
	| storage_class type_specifier
	{
		$<inf>$ = create_point();
		$<inf->storage_class>$ = 1;
		$<inf->type_specifier>$ = 1;
	}
	| type_specifier type_qualifier
	{
		$<inf>$ = create_point();
		$<inf->type_specifier>$ = 1;
		$<inf->type_qualifier>$ = 1;
	}
	| type_qualifier type_specifier
	{
		$<inf>$ = create_point();
		$<inf->type_qualifier>$ = 1;
		$<inf->type_specifier>$ = 1;
	}
	| type_specifier storage_class type_qualifier
	{
		$<inf>$ = create_point();
		$<inf->type_specifier>$ = 1;
		$<inf->storage_class>$ = 1;
		$<inf->type_qualifier>$ = 1;
	}
	| storage_class type_specifier type_qualifier
	{
		$<inf>$ = create_point();
		$<inf->storage_class>$ = 1;
		$<inf->type_specifier>$ = 1;
		$<inf->type_qualifier>$ = 1;
	}
	| storage_class type_qualifier type_specifier
	{
		$<inf>$ = create_point();
		$<inf->storage_class>$ = 1;
		$<inf->type_qualifier>$ = 1;
		$<inf->type_specifier>$ = 1;
	}
	| type_qualifier storage_class type_specifier
	{
		$<inf>$ = create_point();
		$<inf->type_qualifier>$ = 1;
		$<inf->storage_class>$ = 1;
		$<inf->type_specifier>$ = 1;
	}
	| type_specifier type_qualifier storage_class
	{
		$<inf>$ = create_point();
		$<inf->type_specifier>$ = 1;
		$<inf->type_qualifier>$ = 1;
		$<inf->storage_class>$ = 1;
	}
	| type_qualifier type_specifier storage_class
	{
		$<inf>$ = create_point();
		$<inf->type_qualifier>$ = 1;
		$<inf->type_specifier>$ = 1;
		$<inf->storage_class>$ = 1;
	}
	;

expr: bin_expr
	{
		$<inf->what_expr>1 = -1;
	}
	| unar_expr
	{
		$<inf->what_expr>1 = -1;
	}
	| postfix_expr
	{
		$<inf->what_expr>1 = -1;
	}
	| '(' expr ')'
	{
		$<inf>$ = $<inf>2;
	}
	| DIGIT
	{
		$<inf>$ = create_point();
		$<inf->name>$ = add_name($<inf->name>$, $<str>1);
		$<inf->what_expr>$ = -1;
	}
	| STRING
	{
		$<inf>$ = create_point();
		$<inf->name>$ = add_name($<inf->name>$, $<str>1);
		$<inf->what_expr>$ = -1;
	}
	| CHARACTER
	{
		$<inf>$ = create_point();
		$<inf->name>$ = add_name($<inf->name>$, $<str>1);
		$<inf->what_expr>$ = -1;
	}
	| IDENTIFIER
	{
		$<inf>$ = create_point();
		$<inf->name>$ = add_name($<inf->name>$, $<str>1);
		$<inf->what_expr>$ = 0;
	}
	;

bin_expr: expr '*' expr           // multiplication
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr '/' expr               // division
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	// | expr '%' expr               // modulo
	| expr '+' expr               // binary addition
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr '-' expr               // binary subtraction
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr SHIFTL expr            // bitwise shift left
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr SHIFTR expr            // bitwise shift right
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr '<' expr               // less than
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr LOWER_OR_EQ expr       // less than or equal to
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr '>' expr               // more than
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr GREATER_OR_EQ expr     // more than or equal to
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr EQ expr                // equal
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr NOT_EQ expr            // not equal
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr BITAND expr        	  // bitwise AND
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr XOR expr               // bitwise exclusive OR
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr BITOR expr             // bitwise inclusive OR
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr AND expr               // logical AND
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr OR expr            	  // logical inclusive OR
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr '?' expr ':' expr      // conitional expression
	{
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr '=' expr               // simple assignment
	{
		// check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->not_using_of_brackets>1 = 1;
		$<inf->assignment>1 = 1;
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr '=' '{' expr '}'       // simple assignment
	{
		check_declaration($<inf>1);
		check_declaration($<inf>4);
		$<inf->assignment>1 = 1;
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr MUL expr               // multiply and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr DIV expr               // divide and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr MOD expr               // modulo and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr ADD expr               // add and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr SUB expr               // subtract and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr SHIFTL_EQ expr         // shift left and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr SHIFTR_EQ expr         // shift right and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr AND_EQ expr            // bitwise AND and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr XOR_EQ expr            // bitwise exclusive OR and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	| expr OR_EQ expr             // bitwise inclusive OR and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		$<inf->what_expr>1 = -1; // Отмечаем как проверенное
	}
	;

unar_expr: SIZEOF expr              // size of object in bytes
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| SIZEOF '(' type_specifier ')' // size of type in bytes
	{
		$<inf>$ = $<inf>3;
		$<inf->what_expr>$ = -1; // ТУТ ТОЖЕ ПРОВЕРКИ
	}
	| INC expr                      // prefix increment
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| DEC expr                      // prefix decrement
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| COMPL expr                    // bitwise negation
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| NOT expr                      // not
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| '-' expr                      // unary minus
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| '+' expr                      // unary plus
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| BITAND expr                   // address of
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| '*' expr                      // indirection or dereference
	{
		$<inf>$ = $<inf>2;
		$<inf->what_expr>$ = -1;
	}
	| '*' RESTRICT expr             // using of restrict
	{
		$<inf>$ = $<inf>3;
		$<inf->what_expr>$ = -1;
	}
	| '(' type_specifier ')' expr   // type conversion
	{
		$<inf>$ = $<inf>4;
		$<inf->what_expr>$ = -1;
	}
	;

postfix_expr: expr '.' expr       // member selection
	{
		$<inf->what_expr>1 = -1;
	}
	| expr ARROW expr             // member selection
	{
		check_declaration($<inf>1);
		$<inf->what_expr>1 = -1;
	}
	| expr square_brackets        // subscripting
	{
		$<inf->array>1 = 1;
		$<inf->flexible_array>1 = $<inf->flexible_array>2;
		if($<inf->end_empty_brackets>2 == 1) // Пустая скобка не идет первой
			printf("Not C because of incorrect usage of array: %s\n", $<inf->name->s>1);
		$<inf->what_expr>1 = -1;
	}
	| expr '(' func_arg ')'       // function call
	{
		$<inf->func_call>1 = 1;
		$<inf->what_expr>1 = 1;
	}
	| expr '(' expr ')'           // function call
	{
		$<inf->func_call>1 = 1;
		$<inf->what_expr>1 = 1;
	}
	| empty_func_call             // function call
	| type_specifier '(' expr ')' // value construction
	{
		$<inf->what_expr>1 = -1;
	}
	| expr INC                    // postfix increment
	{
		check_declaration($<inf>1);
		$<inf->what_expr>1 = -1;
	}
	| expr DEC                    // postfix decrement
	{
		$<inf->what_expr>1 = -1;
	}
	;

func_arg: expr ',' expr
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
	}
	| func_arg ',' expr
	{
		check_declaration($<inf>3);
	}
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
	{
		del_lvl_info();  // Удаляем информацию уровня func_budy
		global_lvl_id--; // Уменьшаем уровень
	}
	;

do: DO expr	';' WHILE '(' expr ')' ';'
	| DO '{' func_body '}' WHILE '(' expr ')' ';'
	{
		del_lvl_info();  // Удаляем информацию уровня func_budy
		global_lvl_id--; // Уменьшаем уровень
	}
	;

for: FOR '(' for_expr_1 ';' for_expr_2 ';' for_expr_3 ')' expr ';'
	{
		increased_lvl--; // Уменьшаем уровень
		del_lvl_info();  // Удаляем последний уровень
		global_lvl_id--; // Избавляемся от последнего уровня
	}
	| FOR '(' for_expr_1 ';' for_expr_2 ';' for_expr_3 ')' '{' func_body '}'
	{
		increased_lvl--;
		del_lvl_info();
		global_lvl_id--;
	}
	| FOR '(' for_expr_1 ';' for_expr_2 ';' for_expr_3 ')' '{' '}'
	{
		increased_lvl--;
		del_lvl_info();
		global_lvl_id--;
	}
	| FOR '(' for_expr_1 ';' for_expr_2 ';' for_expr_3 ')' ';'
	{
		increased_lvl--;
		del_lvl_info();
		global_lvl_id--;
	}
	;

for_expr_1: 
	{
		global_lvl_id++; // Даже если нет обьявлений, увеличим заранее
		increased_lvl++; // Увеличиваем уровень для for
	}
	| var_declaration // initialization expression
	{
		global_lvl_id++;                // Заранее заносим обьявление переменной на уровень вперед
		add_lvl_info(0, $<inf->name>1); // Это необходимо чтобы func_body не ругалось на отсутствие переменной
		increased_lvl++;
	}
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

define: defien_with_identefier expr
	{
		add_lvl_info(0, add_name(NULL, $<str>1));
		this_is_define = 0;
	}
	| defien_with_identefier '(' for_define ')' expr
	{
		this_is_define = 0;
	}
	;

for_define: 
	| IDENTIFIER
	| for_define ',' IDENTIFIER
	;

defien_with_identefier: P_DEFINE IDENTIFIER
	{
		this_is_define = 1;
		$<str>$ = $<str>2;
	}
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