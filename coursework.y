%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define YYDEBUG 1
FILE* yyin;
int this_is_define = 0; // В случае работы с define, не всегда надо делать проверки
int increased_lvl = 0; // Если ноль, то при свертке в func_body увеличивается уровень, если больше 0, то он уже увеличен
int work_with_do = 0; // Если 0, то в while увеличиваем уровень, в противном случае нет 
int global_line = 0; // Глобальный номер строки, получаемый из токенов, если произойдет синтаксическая ошибка, выведет его
_Bool check_on = 0; // Проверка объявлений
_Bool verdict = 1; // Является ли С, изначально true

/*----------------------Хранение идентификаторов----------------------*/
struct identifier
{
	char *s;
	int parametrs_count;      // Количество параметров для функии
	struct identifier *pnext;
};

/*----------------------Вывод идентификаторов(используется при отладке)----------------------*/
void print_identifier(struct identifier *dummy)
{
	while (1)
	{
		printf(" %s\n", dummy->s);
		if (dummy->pnext != NULL)
			dummy = dummy->pnext;
		else break;
	}
}

// Информация об обьявлениях
struct declaration_info
{
	int lvl_id; // Индификатор-уровень, для глобальных функций и переменных это 0, дальше 1 и тд
	        	// Удалять информацию при покидании уровня, где были обьявления, ориентируясь на lvl_id хранящийся в info
	struct identifier *vars;    // Лист переменных уровня id
	struct identifier *funcs;   // Лист функций уровня id
	struct identifier *structs; // Лист структур уровня id
	struct identifier *unions;  // Лист объединений уровня id
	struct identifier *enums;   // Лист перечислений уровня id
	struct identifier *pnext;   // Следующий уровень
};
struct declaration_info *id = NULL; // Глобальная переменная для хранения информаци об объявлениях
int global_lvl_id = 0; // Глобальный уровень обьявлений, при отсутствующем уровне в func_body, увеличиваем на 1 и присваиваем новому
					   // Когда же сворачиваем, т.е. покидаем уровень, сначала удаляем информацию псоледнего уровня, затем уменьшаем счетчик
					   // Самый высокий уровень равен 0, это уровень глобальных переменных

/*----------------------Вывод объявлений и их уровни(используется при отладке)----------------------*/
void print_lvls()
{
	if (id != NULL) // Если вообще существуют уровни
	{
		struct declaration_info *dummy = id;
		while(1)
		{
			// Выводим информацию об объявлениях
			printf("\nlvl: %d\n", dummy->lvl_id);
			printf("vars:\n");
			if (dummy->vars != NULL)
				print_identifier(dummy->vars);
			printf("funcs:\n");
			if (dummy->funcs != NULL)
				print_identifier(dummy->funcs);
			printf("structs:\n");
			if (dummy->structs != NULL)
				print_identifier(dummy->structs);
			printf("unions:\n");
			if (dummy->unions != NULL)
				print_identifier(dummy->unions);
			printf("enums:\n");
			if (dummy->enums != NULL)
				print_identifier(dummy->enums);
			// Если есть еще уровни
			if (dummy->pnext != NULL)
				dummy = dummy->pnext;
			else return;
		}
	}
}

/*----------------------Добавление названия в identifier----------------------*/
struct identifier *add_name(struct identifier *head, char *new_name, int parametrs_count)
{
	if (head == NULL) // Если имени еще не было
	{
		head = (struct identifier*)malloc(sizeof(struct identifier));
		head->s = new_name;
		head->parametrs_count = parametrs_count;
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
		dummy->parametrs_count = parametrs_count;
		dummy->pnext = NULL;
	}
	return head;
}

/*----------------------Добавление информации об объявлениях----------------------*/
void add_lvl_info(int what,  // 0 - vars, 1 - funcs, 2 - structs, 3 - unions, 4 - enums
	struct identifier *name, // Название
	int parametrs_count)     // Если это функция, то сюда передается количество параметров, в противном случае можно передать -1
{
	// Если еще не была создана глобальная id, то создаем ее
	if (id == NULL)
	{		
		id = (struct declaration_info*)malloc(sizeof(struct declaration_info));
		id->lvl_id = 0;
		id->vars = NULL;
		id->funcs = NULL;
		id->structs = NULL;
		id->unions = NULL;
		id->enums = NULL;
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
		while(1) // Проходим по всем названиям переменых
		{
			
			dummy->vars = add_name(dummy->vars, name->s, parametrs_count); // Добавляем название переменной
			if (name->pnext != NULL)
				name = name->pnext;
			else break;
		}
	}
	else if (what == 1) // Для функций
		dummy->funcs = add_name(dummy->funcs, name->s, parametrs_count);     // Добавляем название функци
	else if (what == 2) // Для структур
		dummy->structs = add_name(dummy->structs, name->s, parametrs_count); // Добавляем название структуры
	else if (what == 3) // Для объединений
		dummy->unions = add_name(dummy->unions, name->s, parametrs_count);   // Добавляем название объединения
	else if (what == 4) // Для перечислений
		dummy->enums = add_name(dummy->enums, name->s, parametrs_count);     // Добавляем название перечисления
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
		if (dummy->pnext != NULL) // Если каким то образом получилось что удаляется не последний уровень
		{
			id = id->pnext;
			free(dummy);
		}
		else // В противном случае удаляем информацию и обнуляем указатель
		{
			free(dummy);
			id = NULL;
		}
	}
	else
	{
		if (dummy->pnext != NULL)
		{
			dummy2->pnext = dummy->pnext;
			free(dummy);
		}
		else
		{
			free(dummy);
			dummy2->pnext = NULL;
		}
	}
}

/*----------------------Поиск имени в глобальной переменной----------------------*/
_Bool find_name(int what, char *s, int parametrs_count)
{
	struct declaration_info *dummy = id;         // Будем работать с пустышкой
	struct declaration_info *saved_id = NULL;    // Сохранение уровня, на котором было найдено последнее совпадение
	struct identifier *saved_point = NULL;       // Сохраненное совпадение, необходимое для проверки количества аргументов
	if (dummy != NULL) // Если id существует, то выполняем поиск
	{
		while (1) // Проходим по всем уровням 
		{
			struct identifier *dummy2 = NULL;
			if (what == 0 && dummy->vars != NULL)         // Если работаем с vars и они вообще есть на этом уровне
				dummy2 = dummy->vars;
			else if (what == 1 && dummy->funcs != NULL)   // Если работаем с funcs и они вообще есть на этом уровне
				dummy2 = dummy->funcs;
			else if (what == 2 && dummy->structs != NULL) // Если работаем со structs и они вообще есть на этом уровне
				dummy2 = dummy->structs;
			else if (what == 3 && dummy->unions != NULL)  // Если работаем с unions и они вообще есть на этом уровне
				dummy2 = dummy->unions;
			else if (what == 4 && dummy->enums != NULL)   // Если работаем с enums и они вообще есть на этом уровне
				dummy2 = dummy->enums;
			// Если есть среди чего искать на данном уровне
			if (dummy2 != NULL)
			{
				while (1) // Проходим по всем названиям переменных рассматриваемого уровня
				{
					if (!strcmp(dummy2->s, s)) // Нашли совпадение, смотрим, надо ли обновить уровень
					{
						if (saved_id == NULL) // Первое найденное совпадение
						{
							saved_id = dummy;
							saved_point = dummy2;
						}
						else if (saved_id->lvl_id < dummy->lvl_id) // Если у следующего совпадения уровень выше
						{
							saved_id = dummy;
							saved_point = dummy2;
						}
					}
					if (dummy2->pnext != NULL)
						dummy2 = dummy2->pnext; // Смотрим есть ли еще названия
					else break; // В противном случае выходим из данного уровня
				}
			}
			// Если есть еще уровни, идем дальше
			if (dummy->pnext != NULL)
				dummy = dummy->pnext;
			else if (saved_point == NULL) // Уровней больше нет и совпадений не найдено
				return 0;
			else if (what == 1) // Если искали функцию, надо проверить количество аргументов
			{
				if (saved_point->parametrs_count < parametrs_count)
				{
					verdict = 0;
					printf("Not C becouse of too many arguments to function: %s\n", saved_point->s);
				}
				else if (saved_point->parametrs_count > parametrs_count)
				{
					verdict = 0;
					printf("Not C becouse of too few arguments to function: %s\n", saved_point->s);
				}
				return 1;
			}
			else // Во всех остальных случаях true
				return 1;
		}
	}
	else // В противном случае ошибка, так как сравнивать вообще не с чем
	{
		return 0;
	}
}

/*----------------------Информация о выражении----------------------*/
struct info
{
	struct identifier *name; // Для вывода названий, строк и т.д.
	int what_decl;           // Если это объявление, то какое: 0 - var_declaration, 1 - func_declaration, 2 - structure_declaration
	_Bool func_call;         // Это выражение является вызовом функции
	int what_expr;           // Выражение содержит: 0 - variable, 1 - func_call, 2 - struct, 3 - union, 4 - enum, -1 - пока ничего или уже проверили
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
	int parametrs_count;           // Число используемых аргументов функции
	int line;                      // Номер строки
};

/*----------------------Проверка на наличие объявления----------------------*/
void check_declaration(struct info *inf)
{
	if (check_on == 1) 
	{
		// Если сейчас обрабатывается define, то не рассматриваем
		if (this_is_define == 1)
			return;
		// Если уже проверен или еще нет присвоения, то не рассматриваем 
		if (inf->what_expr == -1)
			return;
		// Если не нашли объявления
		if(inf->name != NULL) // Против ошибок, как выяснилось да, так тоже может быть
		{
			if (find_name(inf->what_expr, inf->name->s, inf->parametrs_count) == 0)
			{
				if (inf->what_expr == 0)      // Если рассматриваемое выражение переменная
				{
					verdict = 0;
					printf("Line: %d. Not C because used undeclared variable: %s\n", inf->line, inf->name->s);
				}
				else if (inf->what_expr == 1) // Если рассматриваемое выражение вызов функции
				{
					verdict = 0;
					printf("Line: %d. Not C because used undeclared function: %s\n", inf->line, inf->name->s);
				}
				else if (inf->what_expr == 2) // Если рассматриваемое выражение структура данных
				{
					verdict = 0;
					printf("Line: %d. Not C because used undeclared struct: %s\n", inf->line, inf->name->s);
				}
				else if (inf->what_expr == 3) // Если рассматриваемое выражение объединение
				{
					verdict = 0;
					printf("Line: %d. Not C because used undeclared union: %s\n", inf->line, inf->name->s);
				}
				else if (inf->what_expr == 4) // Если рассматриваемое выражение перечисление
				{
					verdict = 0;
					printf("Line: %d. Not C because used undeclared enum: %s\n", inf->line, inf->name->s);
				}
			}
		}
	}
}

/*----------------------Удаление информации об объявлении----------------------*/
void remove_declaration(int what, char *s)
{
	// Удаление производится с самого последнего уровня доступа, для этого производим поиск с нулевого уровня, при нахождении необходимого объявления, сохраняем информацию использующуюся
	// при удалении. При последующем совпадении данные обновляются. Когда закончилои обход всех уровней, производим удаление последней найденной информации.
	struct declaration_info *dummy = id; // Будем работать с пустышкой
	struct declaration_info *saved_id = NULL; // Для хранения уровня на котором нашли совпадение
	struct identifier *saved_point = NULL; // Для хранения найденного совпадения
	struct identifier *saved_before_point = NULL; // Для хранения предшествующего совпадению узла

	if (dummy != NULL) // Если id существует, то выполняем поиск
	{
		while (1) // Проходим по всем уровням 
		{
			struct identifier *dummy2 = NULL;

			if (what == 2 && dummy->structs != NULL) // Если работаем со структурами и они вообще есть на этом уровне
				dummy2 = dummy->structs;
			else if (what == 3 && dummy->unions != NULL) // Если работаем со объединениями и они вообще есть на этом уровне
				dummy2 = dummy->unions;
			else if (what == 4 && dummy->enums != NULL) // Если работаем со перечислениями и они вообще есть на этом уровне
				dummy2 = dummy->enums;
			// Если есть, среди чего искать на данном уровне
			if (dummy2 != NULL)
			{
				struct identifier *dummy3 = dummy2; // dummy_prev
				while (1) // Проходим по всем названиям структур рассматриваемого уровня
				{
					// Нашли совпадение
					if (!strcmp(dummy2->s, s))
					{
						if (saved_id == NULL) // Обновляем данные только в случае, когда либо еще не было сохранений или новый уровень больше
						{
							saved_id = dummy;
							saved_point = dummy2;
							saved_before_point = dummy3;
						}
						else if (saved_id->lvl_id < dummy->lvl_id)
						{
							saved_id = dummy;
							saved_point = dummy2;
							saved_before_point = dummy3;
						}
					}
					// Смотрим есть ли еще названия
					if (dummy2->pnext != NULL)
						dummy2 = dummy2->pnext;
					else break; // В противном случае выходим из данного уровня
				}
			}
			// Можем проверить еще уровни
			if (dummy->pnext != NULL)
				dummy = dummy->pnext;
			else // Если не можем проверить уровни, производим удаление последнего найденного совпадения
			{
				if (what == 2) // Производится удаление struct
				{
					if (saved_id->structs == saved_point)
						saved_id->structs = saved_point->pnext;
					else
						saved_before_point->pnext = saved_point->pnext;
				}
				else if (what == 3) // Производится удаление union
				{
					if (saved_id->unions == saved_point)
						saved_id->unions = saved_point->pnext;
					else
						saved_before_point->pnext = saved_point->pnext;
				}
				else if (what == 4) // Производится удаление enum
				{
					if (saved_id->enums == saved_point)
						saved_id->enums = saved_point->pnext;
					else
						saved_before_point->pnext = saved_point->pnext;
				}
				free(saved_point);
				return;
			}
		}
	}
	else // Если не с чем сравнивать, то возвращаемся
	{
		return;
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
	new_one->parametrs_count = 0;
	new_one->line = 0;
	return new_one;
}

/*----------------------Обновление строки----------------------*/
void update_line(int new_line)
{
	if (global_line < new_line)
	{
		global_line = new_line;
	}
	
}

/*----------------------Для передачи идентификатора и номера его строки----------------------*/
struct line_and_str
{
	int line;
	char *str;
};

%}

%start start
%token STRING DIGIT IDENTIFIER CHARACTER // "string" 123 some_name 'char'
%token P_DEFINE P_UNDEF P_ERROR P_WARNING P_INCLUDE P_IF P_IFDEF P_IFNDEF P_ELSE P_ELIF P_ENDIF P_NULL_DIRECTIVE AUTO TYPEDEF P_LINE P_PRAGMA // #define #undef #error #include #if #ifdef #ifndef #else #elif #endif #line #pragma #
%token CHAR DOUBLE FLOAT INT LONG SHORT SIGNED SIZEOF UNSIGNED VOID _BOOL SIZE_T // auto char double float int long short signed sizeof  unsigned void _Bool size_t
%token CASE DEFAULT IF ELSE FOR SWITCH DO WHILE // case default if else for whitch do while
%token ENUM STRUCT UNION // enum struct union
%token RESTRICT VOLATILE CONST // restrict volatile const
%token REGISTER EXTERN STATIC // register extern static
%token BREAK CONTINUE // break continue
%token RETURN GOTO // return goto
%token AND AND_EQ NOT NOT_EQ OR OR_EQ XOR_EQ EQ // && &= ! != || |= ^= ==
%token BITAND BITOR COMPL XOR // & | ~ ^
%token INC DEC // ++ --
%token GREATER_OR_EQ LOWER_OR_EQ // >= <=
%token SHIFTL SHIFTR SHIFTL_EQ SHIFTR_EQ  // << >> <<= >>=
%token ADD SUB MUL DIV MOD // += -= *= /= %=

%left CASE DEFAULT ':' VOID
%right '?' '=' ADD SUB MUL MOD DIV AND_EQ OR_EQ XOR_EQ SHIFTL_EQ SHIFTR_EQ
%right NOT COMPL SIZEOF
%left OR AND
%left BITOR XOR BITAND
%left EQ NOT_EQ
%left '<' '>'
%left GREATER_OR_EQ LOWER_OR_EQ
%left SHIFTL SHIFTR
%left INC DEC
%right IDENTIFIER
//%right '+' '-' '*' '/' '%'
%right '(' '[' '{'
%right '+' '-' '*' '/' '%'
%left ')' ']' '}'
%left '.' ARROW
%left ','
%left ';'

%union {
	char *str;
	int line;
	struct line_and_str *las;
	struct info *inf;
}

%type <char*> define_with_identefier
%type <inf> empty_func_call paremetrs var_declaration expr bin_expr unar_expr postfix_expr type_specifier _expr_
%type <inf> declaration_specifiers func_declaration func_head program square_brackets member_declaration
%type <las> IDENTIFIER
%type <line> CHAR SHORT INT SIGNED UNSIGNED LONG FLOAT DOUBLE _BOOL VOID SIZE_T STRUCT UNION ENUM
%type <line> P_DEFINE P_UNDEF P_ERROR P_WARNING P_INCLUDE P_IF P_IFDEF P_IFNDEF P_ELSE P_ELIF P_ENDIF P_NULL_DIRECTIVE AUTO TYPEDEF P_LINE P_PRAGMA
%type <line> DIGIT STRING CHARACTER
%type <line> FOR DO WHILE BREAK CASE DEFAULT SWITCH IF ELSE CONTINUE RETURN GOTO
%type <line> VOLATILE CONST REGISTER EXTERN STATIC
%type <line> type_qualifier storage_class
%type <line> ARROW INC DEC SIZEOF

%%
start: program
	| start program
	;

program: func_declaration
	| statements
	{
		$<inf>$ = create_point();
	}
	| var_declaration ';'
	{
		#ifdef __linux__
			add_lvl_info(0, $<inf->name>1, -1);
		#elif _WIN32
			add_lvl_info(0, $<inf>1->name, -1);
		#endif
	}
	| structure_declaration ';'
	{
		$<inf>$ = create_point();
	}
	| structure_declaration expr ';'
	{
		$<inf>$ = create_point();
	}
	| enum_definition ';'
	{
		$<inf>$ = create_point();
	}
	| enum_declaration ';'
	{
		$<inf>$ = create_point();
	}
	| preprocessor
	{
		$<inf>$ = create_point();
	}
	| _expr_ ';'
	| expr ':' expr ';'
	{
		$<inf>$ = create_point();
	}
	| ';'
	{
		$<inf>$ = create_point();
	}
	;

_expr_: expr
	| _expr_ ',' expr
	;

func_body: program
	{
		#ifdef __linux__
			if ($<inf->storage_class_func>1 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of declared function: %s with storage class specifier in function\n", $<inf->line>1, $<inf->name->s>1);
			}
		#elif _WIN32
			if ($<inf>1->storage_class_func == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of declared function: %s with storage class specifier in function\n", $<inf>1->line, $<inf>1->name->s);
			}
		#endif
	}
	| func_body program
	{
		#ifdef __linux__
			if ($<inf->storage_class_func>2 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of declared function: %s with storage class specifier in function\n", $<inf->line>2, $<inf->name->s>2);
			}
		#elif _WIN32
			if ($<inf>2->storage_class_func == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of declared function: %s with storage class specifier in function\n", $<inf>2->line, $<inf>2->name->s);
			}
		#endif
	}
	;

func_declaration: func_head ';'
	{
		del_lvl_info();  // Избавляемся от уровня рассмотренной функции
		global_lvl_id--; // Уменьшаем на 1 уровень
	}
	| func_head '{' '}'
	{
		del_lvl_info();
		global_lvl_id--;
	}
	| func_head '{' func_body '}'
	{
		del_lvl_info();
		global_lvl_id--;
	}
	;

func_head: declaration_specifiers expr '(' paremetrs ')'
	{
		// Уровень уже увеличен в parametrs
		// Добавляем название функции в базу обьявлений, однако перед этим уменьшим уровень, который был поднят в parametrs
		global_lvl_id--;
		#ifdef __linux__
			add_lvl_info(1, $<inf->name>2, $<inf->parametrs_count>4);
		#elif _WIN32
			add_lvl_info(1, $<inf>2->name, $<inf>4->parametrs_count);
		#endif
		global_lvl_id++; // Восстанавливаем уровень
		// Если при обьявлении функции использовался storage_class
		#ifdef __linux__
			if ($<inf->storage_class>1 == 1)
				$<inf->storage_class_func>1 = 1;
		#elif _WIN32
			if ($<inf>1->storage_class == 1)
				$<inf>1->storage_class_func = 1;
		#endif
		$<inf>$ = $<inf>1; // Сохраняем информацию о declaration_specifiers
		#ifdef __linux__
			$<inf->name>$ = $<inf->name>2; // Сохраняем информацию о названии функции
		#elif _WIN32
			$<inf>$->name = $<inf>2->name;
		#endif
	}
	| declaration_specifiers empty_func_call
	{
		// Добавляем название функции в базу обьявлений, уровень не повышен, следовательно не уменьшаем его
		#ifdef __linux__
			add_lvl_info(1, $<inf->name>2, $<inf->parametrs_count>2);
		#elif _WIN32
			add_lvl_info(1, $<inf>2->name, $<inf>2->parametrs_count);
		#endif
		// Производим увеличение уровня, в func_body он сам не повысится
		global_lvl_id++;
		#ifdef __linux__
			if ($<inf->storage_class>1 == 1)
				$<inf->storage_class_func>1 = 1;
		#elif _WIN32
			if ($<inf>1->storage_class == 1)
				$<inf>1->storage_class_func = 1;
		#endif
		$<inf>$ = $<inf>1;
		#ifdef __linux__
			$<inf->name>$ = $<inf->name>2;
		#elif _WIN32
			$<inf>$->name = $<inf>2->name;
		#endif
	}
	;

empty_func_call: expr '(' ')' // func()
	{
		// func()() - Это не С
		#ifdef __linux__
			if($<inf->func_call>1 == 1)
			{
				verdict = 0;
				printf("Line %d. Not C because of incorrect function: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
			else
			{
				$<inf>$ = $<inf>1;
				$<inf->func_call>$ = 1;
				$<inf->what_expr>$ = 1;
				$<inf->parametrs_count>$ = 0;
			}
		#elif _WIN32
			if($<inf>1->func_call == 1)
			{
				verdict = 0;
				printf("Line %d. Not C because of incorrect function: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
			else
			{
				$<inf>$ = $<inf>1;
				$<inf>$->func_call = 1;
				$<inf>$->what_expr = 1;
				$<inf>$->parametrs_count = 0;
			}
		#endif
	}
	;

paremetrs: var_declaration
	{
		global_lvl_id++; // Заносим обьявление переменных на следующий уровень
		#ifdef __linux__
			add_lvl_info(0, $<inf->name>1, -1); // Необходимо для корректной обработки переменных внутри функции
			$<inf->parametrs_count>1++;
		#elif _WIN32
			add_lvl_info(0, $<inf>1->name, -1);
			$<inf>1->parametrs_count++;
		#endif
	}
	| var_declaration ',' var_declaration
	{
		global_lvl_id++;
		#ifdef __linux__
			add_lvl_info(0, $<inf->name>1, -1);
			add_lvl_info(0, $<inf->name>3, -1);
			$<inf->parametrs_count>1 += 2;
		#elif _WIN32
			add_lvl_info(0, $<inf>1->name, -1);
			add_lvl_info(0, $<inf>3->name, -1);
			$<inf>1->parametrs_count += 2;
		#endif
	}
	| paremetrs ',' var_declaration
	{
		#ifdef __linux__
			add_lvl_info(0, $<inf->name>3, -1); // Уровень уже увеличен
			$<inf->parametrs_count>1++;
		#elif _WIN32
			add_lvl_info(0, $<inf>3->name, -1);
			$<inf>1->parametrs_count++;
		#endif
	}
	| type_specifier
	{
		$<inf>$ = create_point();
		global_lvl_id++;
	}
	| type_specifier ',' type_specifier
	{
		$<inf>$ = create_point();
		global_lvl_id++;
	}
	| paremetrs ',' type_specifier
	{
		$<inf>$ = create_point();
		global_lvl_id++;
	}
	;

var_declaration: declaration_specifiers expr
	{
		#ifdef __linux__
			if ($<inf->array>2 == 1 && $<inf->not_using_of_brackets>2 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid initializer in declaration of array: %s\n", $<inf->line>1, $<inf->name->s>2);
			}
			$<inf->assignment>1 = $<inf->assignment>2;
			$<inf->flexible_array>1 = $<inf->flexible_array>2;
			$<inf->name>1 = add_name($<inf->name>1, $<inf->name->s>2, -1); // Добавляем название переменной
		#elif _WIN32
			if ($<inf>2->array == 1 && $<inf>2->not_using_of_brackets == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid initializer in declaration of array: %s\n", $<inf>1->line, $<inf>2->name->s);
			}
			$<inf>1->assignment = $<inf>2->assignment;
			$<inf>1->flexible_array = $<inf>2->flexible_array;
			$<inf>1->name = add_name($<inf>1->name, $<inf>2->name->s, -1);
		#endif
	}
	| var_declaration ',' expr
	{
		#ifdef __linux__
			if ($<inf->assignment>1 == 0)
				$<inf->assignment>1 = $<inf->assignment>3;
			if ($<inf->flexible_array>1 == 0)
				$<inf->flexible_array>1 = $<inf->flexible_array>3;
			$<inf->name>1 = add_name($<inf->name>1, $<inf->name->s>3, -1); // Если переменных несколько, то добавляем еще
		#elif _WIN32
			if ($<inf>1->assignment == 0)
				$<inf>1->assignment = $<inf>3->assignment;
			if ($<inf>1->flexible_array == 0)
				$<inf>1->flexible_array = $<inf>3->flexible_array;
			$<inf>1->name = add_name($<inf>1->name, $<inf>3->name->s, -1);
		#endif
	}
	;

square_brackets: '[' ']'
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->flexible_array>$ = 1;
		#elif _WIN32
			$<inf>$->flexible_array = 1;
		#endif
	}
	| '[' expr ']'
	{
		$<inf>$ = create_point();
	}
	| square_brackets '[' expr ']'
	| square_brackets '[' ']' // Это ошибка, пустая скобка в массиве может быть только первая
	{
		#ifdef __linux__
			$<inf->end_empty_brackets>1 = 1;
		#elif _WIN32
			$<inf>1->end_empty_brackets = 1;
		#endif
	}
	;

structure_declaration: struct_identifier '{' member_declaration '}'
	{
		#ifdef __linux__
			if ($<inf->assignment>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in structure: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
			if ($<inf->only_flexible_array>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in otherwise empty structure: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
			if ($<inf->not_last_flexible_array>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member not at end of structure: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
			if ($<inf->storage_class>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in structure: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
		#elif _WIN32
			if ($<inf>3->assignment == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in structure: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
			if ($<inf>3->only_flexible_array == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in otherwise empty structure: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
			if ($<inf>3->not_last_flexible_array == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member not at end of structure: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
			if ($<inf>3->storage_class == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in structure: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
		#endif
		global_lvl_id--; // Уменьшаем, так как повышен был в struct_identifier
	}
	| STRUCT '{' member_declaration '}'
	{
		#ifdef __linux__
			if ($<inf->assignment>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in structure\n", $<line>1);
			}
			if ($<inf->only_flexible_array>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in otherwise empty structure\n", $<line>1);
			}
			if ($<inf->not_last_flexible_array>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member not at end of structure\n", $<line>1);
			}
			if ($<inf->storage_class>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in structure\n", $<line>1);
			}
		#elif _WIN32
			if ($<inf>3->assignment == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in structure\n", $<line>1);
			}
			if ($<inf>3->only_flexible_array == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in otherwise empty structure\n", $<line>1);
			}
			if ($<inf>3->not_last_flexible_array == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member not at end of structure\n", $<line>1);
			}
			if ($<inf>3->storage_class == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in structure\n", $<line>1);
			}
		#endif
	}
	| union_identifier '{' member_declaration '}'
	{
		#ifdef __linux__
			if ($<inf->assignment>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in union: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
			if ($<inf->flexible_array>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in union: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
			if ($<inf->storage_class>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in union: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
		#elif _WIN32
			if ($<inf>3->assignment == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in union: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
			if ($<inf>3->flexible_array == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in union: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
			if ($<inf>3->storage_class == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in union: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
		#endif
		global_lvl_id--; // Уменьшаем, так как повышен был в union_identifier
	}
	| UNION '{' member_declaration '}'
	{
		#ifdef __linux__
			if ($<inf->assignment>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in union\n", $<line>1);
			}
			if ($<inf->only_flexible_array>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in union\n", $<line>1);
			}
			if ($<inf->storage_class>3 == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in union\n", $<line>1);
			}
		#elif _WIN32
			if ($<inf>3->assignment == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of invalid declaration in union\n", $<line>1);
			}
			if ($<inf>3->only_flexible_array == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of flexible array member in union\n", $<line>1);
			}
			if ($<inf>3->storage_class == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of storage class member in union\n", $<line>1);
			}
		#endif
	}
	| struct_identifier '{' '}'
	{
		global_lvl_id--;
	}
	| STRUCT '{' '}'
	| union_identifier '{' '}'
	{
		global_lvl_id--;
	}
	| UNION '{' '}'
	;

member_declaration: var_declaration ';'
	{
		#ifdef __linux__
			if ($<inf->flexible_array>1 == 1) // Случай, когда только flexible_array
				$<inf->only_flexible_array>1 = 1;
		#elif _WIN32
			if ($<inf>1->flexible_array == 1)
				$<inf>1->only_flexible_array = 1;
        #endif
	}
	| _bit_field ';'
	{
		#ifdef __linux__
			if ($<inf->flexible_array>1 == 1)
				$<inf->only_flexible_array>1 = 1;
		#elif _WIN32
			if ($<inf>1->flexible_array == 1)
				$<inf>1->only_flexible_array = 1;
        #endif
	}
	| member_declaration var_declaration ';'
	{
		#ifdef __linux__
			$<inf->only_flexible_array>1 = 0; // Так как это уже не случай, когда только flexible_array
			if ($<inf->assignment>1 == 0)
				$<inf->assignment>1 = $<inf->assignment>2;
			if ($<inf->flexible_array>1 == 1) // Когда flexible_array не является последним элементом
				$<inf->not_last_flexible_array>1 = 1;
			$<inf->flexible_array>1 = $<inf->flexible_array>2;
			if ($<inf->storage_class>1 == 0) // Когда storage_class в struct
				$<inf->storage_class>1 = $<inf->storage_class>2;
		#elif _WIN32
			$<inf>1->only_flexible_array = 0;
			if ($<inf>1->assignment == 0)
				$<inf>1->assignment = $<inf>2->assignment;
			if ($<inf>1->flexible_array == 1)
				$<inf>1->not_last_flexible_array = 1;
			$<inf>1->flexible_array = $<inf>2->flexible_array;
			if ($<inf>1->storage_class == 0)
				$<inf>1->storage_class = $<inf>2->storage_class;
        #endif
	}
	| member_declaration _bit_field ';'
	{
		#ifdef __linux__
			$<inf->only_flexible_array>1 = 0;
			if ($<inf->assignment>1 == 0)
				$<inf->assignment>1 = $<inf->assignment>2;
			if ($<inf->flexible_array>1 == 1)
				$<inf->not_last_flexible_array>1 = 1;
			$<inf->flexible_array>1 = $<inf->flexible_array>2;
			if ($<inf->storage_class>1 == 0)
				$<inf->storage_class>1 = $<inf->storage_class>2;
		#elif _WIN32
			$<inf>1->only_flexible_array = 0;
			if ($<inf>1->assignment == 0)
				$<inf>1->assignment = $<inf>2->assignment;
			if ($<inf>1->flexible_array == 1)
				$<inf>1->not_last_flexible_array = 1;
			$<inf>1->flexible_array = $<inf>2->flexible_array;
			if ($<inf>1->storage_class == 0)
				$<inf>1->storage_class = $<inf>2->storage_class;
        #endif
	}
	;

_bit_field: var_declaration ':' expr
	| _bit_field ',' expr ':' expr
	;

enum_declaration: enum_identifier '{' enumerator '}' // enum enum_name {...}
	| ENUM '{' enumerator '}'                        // enum {...}
	{
		update_line($<line>1);
	}
	;

enum_definition: declaration_specifiers enum_identifier IDENTIFIER // storage_class enum enum_name a
	{
		#ifdef __linux__
			update_line($<las->line>3);
		#elif _WIN32
			update_line($<las>3->line);
        #endif
		#ifdef __linux__
			remove_declaration(4, $<inf->name->s>2);
		#elif _WIN32
			remove_declaration(4, $<inf>2->name->s);
        #endif
		check_declaration($<inf>2); // Проверяем на существование определения перечисления ранее
	}
	| enum_identifier IDENTIFIER 								   // enum enum_name a
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
		#ifdef __linux__
			remove_declaration(4, $<inf->name->s>1);
		#elif _WIN32
			remove_declaration(4, $<inf>1->name->s);
        #endif
		check_declaration($<inf>1); // Проверяем на существование определения перечисления ранее
	}
	| declaration_specifiers enum_declaration IDENTIFIER           // storage_class enum [enum_name] {...} a
	{
		#ifdef __linux__
			update_line($<las->line>3);
		#elif _WIN32
			update_line($<las>3->line);
        #endif
	}
	| enum_declaration IDENTIFIER                                  // enum [enum_name] {...} a
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
	}
	| enum_definition ',' IDENTIFIER                               // [storage_class] enum enum_name a, b, c
	{
		#ifdef __linux__
			update_line($<las->line>3);
		#elif _WIN32
			update_line($<las>3->line);
        #endif
	}
	| enum_definition '=' IDENTIFIER                               // [storage_class] enum [enum_name] {...} a = smth_from {...}
	{
		#ifdef __linux__
			update_line($<las->line>3);
		#elif _WIN32
			update_line($<las>3->line);
        #endif
	}
	;

enumerator: IDENTIFIER                   // { name }
	{
		#ifdef __linux__
			update_line($<las->line>1);
		#elif _WIN32
			update_line($<las>1->line);
        #endif
	}
	| enumerator ',' IDENTIFIER          // { name_1, name_2 }
	{
		#ifdef __linux__
			update_line($<las->line>3);
		#elif _WIN32
			update_line($<las>3->line);
        #endif
	}
	| IDENTIFIER '=' expr                // { name = 12 } - может быть равен числу
	{
		#ifdef __linux__
			update_line($<las->line>1);
		#elif _WIN32
			update_line($<las>1->line);
        #endif
	}
	| enumerator ',' IDENTIFIER '=' expr // { name_1, name_2 = 12}
	{
		#ifdef __linux__
			update_line($<las->line>3);
		#elif _WIN32
			update_line($<las>3->line);
        #endif
	}
	;

declaration_specifiers: type_specifier
	{
		// $<inf>$ = create_point();
		$<inf>$ = $<inf>1;
		#ifdef __linux__
			$<inf->type_specifier>$ = 1;
		#elif _WIN32
			$<inf>$->type_specifier = 1;
        #endif
	}
	| storage_class
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->storage_class>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->storage_class = 1;
        #endif
	}
	| type_qualifier
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->type_qualifier>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	| type_specifier storage_class
	{
		//$<inf>$ = create_point();
		$<inf>$ = $<inf>1;
		#ifdef __linux__
			$<inf->type_specifier>$ = 1;
			$<inf->storage_class>$ = 1;
		#elif _WIN32
			$<inf>$->type_qualifier = 1;
			$<inf>$->storage_class = 1;
        #endif
	}
	| storage_class type_specifier
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->storage_class>$ = 1;
			$<inf->type_specifier>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->storage_class = 1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	| type_specifier type_qualifier
	{
		// $<inf>$ = create_point();
		$<inf>$ = $<inf>1;
		#ifdef __linux__
			$<inf->type_specifier>$ = 1;
			$<inf->type_qualifier>$ = 1;
		#elif _WIN32
			$<inf>$->type_specifier = 1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	| type_qualifier type_specifier
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->type_qualifier>$ = 1;
			$<inf->type_specifier>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->type_qualifier = 1;
			$<inf>$->type_specifier = 1;
        #endif
	}
	| type_specifier storage_class type_qualifier
	{
		//$<inf>$ = create_point();
		$<inf>$ = $<inf>1;
		$<inf->type_specifier>$ = 1;
		$<inf->storage_class>$ = 1;
		$<inf->type_qualifier>$ = 1;
	}
	| storage_class type_specifier type_qualifier
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->storage_class>$ = 1;
			$<inf->type_specifier>$ = 1;
			$<inf->type_qualifier>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->storage_class = 1;
			$<inf>$->type_specifier = 1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	| storage_class type_qualifier type_specifier
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->storage_class>$ = 1;
			$<inf->type_specifier>$ = 1;
			$<inf->type_qualifier>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->storage_class = 1;
			$<inf>$->type_specifier = 1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	| type_qualifier storage_class type_specifier
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->storage_class>$ = 1;
			$<inf->type_specifier>$ = 1;
			$<inf->type_qualifier>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->storage_class = 1;
			$<inf>$->type_specifier = 1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	| type_specifier type_qualifier storage_class
	{
		// $<inf>$ = create_point();
		$<inf>$ = $<inf>1;
		#ifdef __linux__
			$<inf->storage_class>$ = 1;
			$<inf->type_specifier>$ = 1;
			$<inf->type_qualifier>$ = 1;
		#elif _WIN32
			$<inf>$->storage_class = 1;
			$<inf>$->type_specifier = 1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	| type_qualifier type_specifier storage_class
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->storage_class>$ = 1;
			$<inf->type_specifier>$ = 1;
			$<inf->type_qualifier>$ = 1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
			$<inf>$->storage_class = 1;
			$<inf>$->type_specifier = 1;
			$<inf>$->type_qualifier = 1;
        #endif
	}
	;

expr: bin_expr
	{
		#ifdef __linux__
			$<inf->what_expr>1 = -1;
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| unar_expr
	{
		#ifdef __linux__
			$<inf->what_expr>1 = -1;
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| postfix_expr
	{
		check_declaration($<inf>1);
		#ifdef __linux__
			$<inf->what_expr>1 = -1;
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| '(' expr ')'
	{
		$<inf>$ = $<inf>2;
	}
	| '(' type_specifier '*' ')' expr
	{
		$<inf>$ = $<inf>5;
	}
	| DIGIT
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->what_expr>$ = -1;
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| STRING
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
			$<inf->what_expr>$ = -1;
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| CHARACTER
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->what_expr>$ = -1;
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| IDENTIFIER
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			update_line($<las->line>1);
			$<inf->line>$ = $<las->line>1;
			$<inf->name>$ = add_name($<inf->name>$, $<las->str>1, -1);
			$<inf->what_expr>$ = 0;
		#elif _WIN32
			update_line($<las>1->line);
			$<inf>$->line = $<las>1->line;
			$<inf>$->name = add_name($<inf>$->name, $<las>1->str, -1);
			$<inf>$->what_expr = 0;
        #endif
	}
	;

bin_expr: expr '*' expr           // multiplication
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '/' expr               // division
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endifе
	}
	| expr '%' expr               // modulo
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '+' expr               // binary addition
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '-' expr               // binary subtraction
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr SHIFTL expr            // bitwise shift left
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr SHIFTR expr            // bitwise shift right
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '<' expr               // less than
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr LOWER_OR_EQ expr       // less than or equal to
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '>' expr               // more than
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr GREATER_OR_EQ expr     // more than or equal to
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr EQ expr                // equal
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr NOT_EQ expr            // not equal
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr BITAND expr        	  // bitwise AND
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr XOR expr               // bitwise exclusive OR
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr BITOR expr             // bitwise inclusive OR
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr AND expr               // logical AND
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr OR expr            	  // logical inclusive OR
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '?' expr ':' expr      // conitional expression
	{
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '=' expr               // simple assignment
	{
		// check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->not_using_of_brackets>1 = 1;
			$<inf->assignment>1 = 1;
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->not_using_of_brackets = 1;
			$<inf>1->assignment = 1;
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '=' '{' _expr '}'       // simple assignment
	{
		check_declaration($<inf>1);
		check_declaration($<inf>4);
		#ifdef __linux__
			$<inf->assignment>1 = 1;
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->assignment = 1;
			$<inf>1->what_expr = -1; // Отмечаем как проверенное
        #endif
	}
	| expr MUL expr               // multiply and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr DIV expr               // divide and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr MOD expr               // modulo and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr ADD expr               // add and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr SUB expr               // subtract and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr SHIFTL_EQ expr         // shift left and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr SHIFTR_EQ expr         // shift right and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr AND_EQ expr            // bitwise AND and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr XOR_EQ expr            // bitwise exclusive OR and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr OR_EQ expr             // bitwise inclusive OR and assign
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	;

_expr: expr
	| _expr ',' expr
	;

unar_expr: SIZEOF expr              // size of object in bytes
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| SIZEOF '(' type_specifier ')' // size of type in bytes
	{
		$<inf>$ = $<inf>3;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| SIZEOF '(' type_specifier '*'')' // size of type in bytes
	{
		$<inf>$ = $<inf>3;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| INC expr                      // prefix increment
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| DEC expr                      // prefix decrement
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| COMPL expr                    // bitwise negation
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| NOT expr                      // not
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| '-' expr                      // unary minus
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| '+' expr                      // unary plus
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| BITAND expr                   // address of
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| '*' expr                      // indirection or dereference
	{
		$<inf>$ = $<inf>2;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| '*' RESTRICT expr             // using of restrict
	{
		$<inf>$ = $<inf>3;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| '(' type_specifier ')' expr   // type conversion
	{
		$<inf>$ = $<inf>4;
		#ifdef __linux__
			$<inf->what_expr>$ = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	;

postfix_expr: expr '.' expr       // member selection
	{
		check_declaration($<inf>1);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr ARROW expr             // member selection
	{
		check_declaration($<inf>1);
		#ifdef __linux__
			$<inf->what_expr>1 = -1; // Отмечаем как проверенное
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr square_brackets        // subscripting
	{
		$<inf->array>1 = 1;
		#ifdef __linux__
			$<inf->flexible_array>1 = $<inf->flexible_array>2;
			if($<inf->end_empty_brackets>2 == 1) // Пустая скобка не идет первой
			{
				verdict = 0;
				printf("Line: %d. Not C because of incorrect usage of array: %s\n", $<inf->line>1, $<inf->name->s>1);
			}
			$<inf->what_expr>1 = -1;
		#elif _WIN32
			$<inf>1->flexible_array = $<inf>2->flexible_array;
			if($<inf>2->end_empty_brackets == 1)
			{
				verdict = 0;
				printf("Line: %d. Not C because of incorrect usage of array: %s\n", $<inf>1->line, $<inf>1->name->s);
			}
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr '(' func_arg ')'       // function call
	{
		#ifdef __linux__
			$<inf->func_call>1 = 1;
			$<inf->what_expr>1 = 1;
			$<inf->parametrs_count>1 = $<inf->parametrs_count>3;
		#elif _WIN32
			$<inf>1->func_call = 1;
			$<inf>1->what_expr = 1;
			$<inf>1->parametrs_count = $<inf>3->parametrs_count;
        #endif
	}
	| expr '(' expr ')'           // function call
	{
		#ifdef __linux__
			$<inf->func_call>1 = 1;
			$<inf->what_expr>1 = 1;
			$<inf->parametrs_count>1 = 1;
		#elif _WIN32
			$<inf>1->func_call = 1;
			$<inf>1->what_expr = 1;
			$<inf>1->parametrs_count = 1;
        #endif
	}
	| empty_func_call             // function call
	{
		#ifdef __linux__
			$<inf->parametrs_count>1 = 0;
		#elif _WIN32
			$<inf>1->parametrs_count = 0;
        #endif
	}
	| type_specifier '(' expr ')' // value construction
	{
		$<inf>$ = $3;
		#ifdef __linux__
			$<inf->what_expr>$ = -1;
		#elif _WIN32
			$<inf>$->what_expr = -1;
        #endif
	}
	| expr INC                    // postfix increment
	{
		check_declaration($<inf>1);
		#ifdef __linux__
			$<inf->what_expr>1 = -1;
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	| expr DEC                    // postfix decrement
	{
		check_declaration($<inf>1);
		#ifdef __linux__
			$<inf->what_expr>1 = -1;
		#elif _WIN32
			$<inf>1->what_expr = -1;
        #endif
	}
	;

func_arg: expr ',' expr
	{
		check_declaration($<inf>1);
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->parametrs_count>1 = 2;
		#elif _WIN32
			$<inf>1->parametrs_count = 2;
        #endif
	}
	| func_arg ',' expr
	{
		check_declaration($<inf>3);
		#ifdef __linux__
			$<inf->parametrs_count>1++;
		#elif _WIN32
			$<inf>1->parametrs_count++;
        #endif
	}
	;

storage_class: REGISTER
	{
		update_line($<line>1);
	}
	| EXTERN
	{
		update_line($<line>1);
	}
	| STATIC
	{
		update_line($<line>1);
	}
	;

type_qualifier: VOLATILE
	{
		update_line($<line>1);
	}
	| CONST
	{
		update_line($<line>1);
	}
	;

statements: labels
	| if
	| switch
	| while
	| do
	| for
	| _break ';'
	| _continue ';'
	| _return expr ';'
	| _return ';'
	| _return '(' ')' ';'
	| _goto expr ';'
	;

_continue: CONTINUE
	{
		update_line($<line>1);
	}
	;

_return: RETURN
	{
		update_line($<line>1);
	}
	;

_goto: GOTO
	{
		update_line($<line>1);
	}
	;

labels: IDENTIFIER ':' statements
	{
		#ifdef __linux__
			update_line($<las->line>1);
		#elif _WIN32
			update_line($<las>1->line);
        #endif
	}
	/*
	| IDENTIFIER ':' ';'
	{
		#ifdef __linux__
			update_line($<las->line>1);
		#elif _WIN32
			update_line($<las>1->line);
        #endif
	}
	*/
	| _case expr ':' statements // expr должен быть константным
	| _default ':' statements
	;

if: _if '(' expr ')' '{' func_body '}'
	| _if '(' expr ')' '{' '}'
	| _if '(' expr ')' func_body
	//| if _else if
	//| if _else expr ';'
	| if _else '{' func_body '}'
	| if _else func_body
	| if '{' '}'
	| if _else '{' '}'
	;

_if: IF
	{
		update_line($<line>1);
	}
	;

_else: ELSE
	{
		update_line($<line>1);
	}
	;

switch: _switch '(' expr ')'  '{' switch_body '}'
	;

_switch: SWITCH	
	{
		update_line($<line>1);
	}
	;

switch_body: _case expr ':'
	| _case expr ':' case_body
	| switch_body _case expr ':' case_body
	| _default ':' case_body
	| switch_body _default ':' case_body
	;

_case: CASE
	{
		update_line($<line>1);
	}
	;

_default: DEFAULT
	{
		update_line($<line>1);
	}
	;

case_body: program
	| case_body program
	;

_break: BREAK
	{
		update_line($<line>1);
	}
	;

while: _while '(' expr ')' expr ';'
	| _while '(' expr ')' '{' func_body '}'
	{
		del_lvl_info();  // Удаляем информацию уровня func_body
		global_lvl_id--; // Уменьшаем уровень
	}
	;

_while: WHILE
	{
		update_line($<line>1);
		if (work_with_do == 0)
			global_lvl_id++; // Увеличиваем уровень для while
		else
			work_with_do--;
	}
	;

do: _do expr ';' _while '(' expr ')' ';'
	{
		del_lvl_info();  // Удаляем информацию уровня func_body
		global_lvl_id--; // Уменьшаем уровень
	}
	| _do '{' func_body '}' _while '(' expr ')' ';'
	{
		del_lvl_info();
		global_lvl_id--;
	}
	;

_do: DO
	{
		update_line($<line>1);
		global_lvl_id++; // Увеличиваем уровень для do
		work_with_do++;  // Отмечаем, чтобы while не увеличила уровень
	}
	;

for: _for '(' for_expr_1 ';' for_expr_2 ';' for_expr_2 ')' expr ';'
	{
		del_lvl_info();  // Избавляемся от рассмотренного уровня цикла for
		global_lvl_id--; // Уменьшаем уровень
	}
	| _for '(' for_expr_1 ';' for_expr_2 ';' for_expr_2 ')' '{' func_body '}'
	{
		del_lvl_info();
		global_lvl_id--;
	}
	| _for '(' for_expr_1 ';' for_expr_2 ';' for_expr_2 ')' statements
	{
		del_lvl_info();
		global_lvl_id--;
	}
	| _for '(' for_expr_1 ';' for_expr_2 ';' for_expr_2 ')' '{' '}'
	{
		del_lvl_info();
		global_lvl_id--;
	}
	| _for '(' for_expr_1 ';' for_expr_2 ';' for_expr_2 ')' ';'
	{
		del_lvl_info();
		global_lvl_id--;
	}
	;

_for: FOR
	{
		update_line($<line>1);
		global_lvl_id++; // Увеличиваем уровень для цикла for
	}
	;

for_expr_1: 
	| var_declaration // initialization expression
	{
		#ifdef __linux__
			add_lvl_info(0, $<inf->name>1, -1); // Это необходимо чтобы func_body не ругалось на отсутствие переменной
		#elif _WIN32
			add_lvl_info(0, $<inf>1->name, -1);
        #endif
	}
	| expr
	| for_expr_1 ',' expr
	;

for_expr_2: 
	| expr // conditional expression
	| for_expr_2 ',' expr
	;

preprocessor: define
	| undef
	| _error
	| warning
	| include
	| line
	| pragma
	;

define: define_with_identefier DIGIT
	{
		#ifdef __linux__
			add_lvl_info(0, add_name(NULL, $<las->str>1, -1), -1);
		#elif _WIN32
			add_lvl_info(0, add_name(NULL, $<las>1->str, -1), -1);
		#endif
		this_is_define = 0;
	}
	| define_with_identefier CHARACTER
	{
		#ifdef __linux__
			add_lvl_info(0, add_name(NULL, $<las->str>1, -1), -1);
		#elif _WIN32
			add_lvl_info(0, add_name(NULL, $<las>1->str, -1), -1);
		#endif
		this_is_define = 0;
	}
	| define_with_identefier STRING
	{
		#ifdef __linux__
			add_lvl_info(0, add_name(NULL, $<las->str>1, -1), -1);
		#elif _WIN32
			add_lvl_info(0, add_name(NULL, $<las>1->str, -1), -1);
		#endif
		this_is_define = 0;
	}
	/*
	| define_with_identefier '(' for_define ')' expr
	{
		#ifdef __linux__
			add_lvl_info(0, add_name(NULL, $<las->str>1, -1), -1);
		#elif _WIN32
			add_lvl_info(0, add_name(NULL, $<las>1->str, -1), -1);
		#endif
		this_is_define = 0;
	}
	*/
	| define_with_identefier
	{
		#ifdef __linux__
			add_lvl_info(0, add_name(NULL, $<las->str>1, -1), -1);
		#elif _WIN32
			add_lvl_info(0, add_name(NULL, $<las>1->str, -1), -1);
		#endif
		this_is_define = 0;
	}
	;
/*
for_define: 
	| IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>1);
		#elif _WIN32
			update_line($<las>1->line);
        #endif
	}
	| for_define ',' IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>3);
		#elif _WIN32
			update_line($<las>3->line);
        #endif
	}
	;
*/
define_with_identefier: _define IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
		this_is_define = 1;
		$<las>$ = $<las>2;
	}
	;

_define: P_DEFINE
	{
		update_line($<line>1);
	}
	;

undef: _undef IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
	}
	;

_undef: P_UNDEF
	{
		update_line($<line>1);
	}
	;

_error: __error STRING
	{
		update_line($<line>2);
	}
	;

__error: P_ERROR
	{
		update_line($<line>1);
	}
	;

warning: _warning STRING
	{
		update_line($<line>2);
	}
	;

_warning: P_WARNING
	{
		update_line($<line>1);
	}
	;

include: _include STRING         // "file_name"
	{
		update_line($<line>2);
	}
	| _include '<' file_name '>' // <file_name> <header_name>
	| include IDENTIFIER          // identifiers
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
	}
	;

_include: P_INCLUDE
	{
		update_line($<line>1);
	}
	;

file_name: IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>1);
		#elif _WIN32
			update_line($<las>1->line);
        #endif
	}
	| file_name IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
	}
	| file_name '\\'
	| file_name '/'
	| file_name '.'
	;

line: _line DIGIT
	{
		update_line($<line>2);
	}
	| _line STRING
	{
		update_line($<line>2);
	}
	;

_line: P_LINE
	{
		update_line($<line>1);
	}
	;

pragma: _pragma IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
	}
	| pragma IDENTIFIER
	{
		#ifdef __linux__
			update_line($<las->line>2);
		#elif _WIN32
			update_line($<las>2->line);
        #endif
	}
	;

_pragma: P_PRAGMA
	{
		update_line($<line>1);
	}
	;
 
type_specifier: CHAR
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED CHAR
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED CHAR
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SHORT
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SHORT INT
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED SHORT
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED SHORT INT
	{
		update_line($<line>3);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED SHORT
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED SHORT INT
	{
		update_line($<line>3);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| INT
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED INT
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED INT
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| LONG
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| LONG INT
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED LONG
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED LONG INT
	{
		update_line($<line>3);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED LONG
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED LONG INT
	{
		update_line($<line>3);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| LONG LONG
	{
		update_line($<line>2);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| LONG LONG INT
	{
		update_line($<line>3);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED LONG LONG
	{
		update_line($<line>3);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIGNED LONG LONG INT
	{
		update_line($<line>4);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED LONG LONG
	{
		update_line($<line>3);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| UNSIGNED LONG LONG INT
	{
		update_line($<line>4);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| FLOAT
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| DOUBLE
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| LONG DOUBLE
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| _BOOL
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| VOID
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| SIZE_T
	{
		update_line($<line>1);
		$<inf>$ = create_point();
		#ifdef __linux__
			$<inf->line>$ = $<line>1;
		#elif _WIN32
			$<inf>$->line = $<line>1;
        #endif
	}
	| struct_identifier
	{
		// Сначала удаляется последнее добавленное зараенее определение, т.к. это уже не верно
		#ifdef __linux__
			remove_declaration(2, $<inf->name->s>1);
		#elif _WIN32
			remove_declaration(2, $<inf>1->name->s);
        #endif
		global_lvl_id--; // Уменьшили общий уровень
		check_declaration($<inf>1); // Проверяем на существование определения структуры ранее
	}
	| union_identifier
	{
		#ifdef __linux__
			remove_declaration(3, $<inf->name->s>1);
		#elif _WIN32
			remove_declaration(3, $<inf>1->name->s);
        #endif
		global_lvl_id--;
		check_declaration($<inf>1); // Проверяем на существование определения объединения ранее
	}
	;

struct_identifier: STRUCT IDENTIFIER
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			update_line($<las->line>2); // Обновляем информацию о строке по идентификатору
			$<inf->line>$ = $<line>1;
			$<inf->name>$ = add_name($<inf->name>$, $<las->str>2, -1);
			$<inf->what_expr>$ = 2;
			add_lvl_info(2, add_name(NULL, $<las->str>2, -1), -1);
		#elif _WIN32
			update_line($<las>2->line);
			$<inf>$->line = $<line>1;
			$<inf>$->name = add_name($<inf>$->name, $<las>2->str, -1);
			$<inf>$->what_expr = 2;
			add_lvl_info(2, add_name(NULL, $<las>2->str, -1), -1);
        #endif
		global_lvl_id++; // Увеличиваем на случай, если будет переменная внутри структуры такого же типа
	}
	;

union_identifier: UNION IDENTIFIER
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			update_line($<las->line>2);
			$<inf->line>$ = $<line>1;
			$<inf->name>$ = add_name($<inf->name>$, $<las->str>2, -1);
			$<inf->what_expr>$ = 3;
			add_lvl_info(3, add_name(NULL, $<las->str>2, -1), -1);
		#elif _WIN32
			update_line($<las>2->line);
			$<inf>$->line = $<line>1;
			$<inf>$->name = add_name($<inf>$->name, $<las>2->str, -1);
			$<inf>$->what_expr = 3;
			add_lvl_info(3, add_name(NULL, $<las>2->str, -1), -1);
        #endif
		global_lvl_id++;
	}
	;

enum_identifier: ENUM IDENTIFIER
	{
		$<inf>$ = create_point();
		#ifdef __linux__
			update_line($<las->line>2);
			$<inf->line>$ = $<line>1;
			$<inf->name>$ = add_name($<inf->name>$, $<las->str>2, -1);
			$<inf->what_expr>$ = 4;
			add_lvl_info(4, add_name(NULL, $<las->str>2, -1), -1);
		#elif _WIN32
			update_line($<las>2->line);
			$<inf>$->line = $<line>1;
			$<inf>$->name = add_name($<inf>$->name, $<las>2->str, -1);
			$<inf>$->what_expr = 4;
			add_lvl_info(4, add_name(NULL, $<las>2->str, -1), -1);
        #endif
		// Тут не увеличиваем, внутри просто индификаторы
	}
	;
%%

main(int argc, char* argv[])
{
	if (argc == 2)
	{
		printf("START\n");
		yyin = fopen(argv[1], "r");
		yyparse();
		if (verdict == 1)
			printf("Verdict: Looks like C\n");
		else
			printf("Verdict: Looks like not C\n");
	}
	else if (argc == 3 && (!strcmp(argv[2], "1")))
	{
		check_on = 1;
		printf("START\n");
		yyin = fopen(argv[1], "r");
		yyparse();
		if (verdict == 1)
			printf("Verdict: Looks like C\n");
		else
			printf("Verdict: Looks like not C\n");
	}
	else if (argc == 3 && (!strcmp(argv[2], "9")))
	{
		#if YYDEBUG
		yydebug = 1;
		#endif
		printf("START\n");
		yyin = fopen(argv[1], "r");
		yyparse();
		if (verdict == 1)
			printf("Verdict: Looks like C\n");
		else
			printf("Verdict: Looks like not C\n");
	}
}

yyerror(char *s)
{
	verdict = 0;
	fprintf(stderr, "Line: %d. %s. Not C.\n", global_line, s);
}

yywrap()
{
	fclose(yyin);
	return(1);
}