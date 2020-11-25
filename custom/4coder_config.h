/*
4coder_config.h - Configuration structs.
*/

// TOP

#if !defined(FCODER_CONFIG_H)
#define FCODER_CONFIG_H

#include <stdio.h>

////////////////////////////////
// NOTE(allen): Config Parser Types

struct Error_Location{
    i32 line_number;
    i32 column_number;
};

struct Config_Error{
    Config_Error *next;
    Config_Error *prev;
    String_Const_u8 file_name;
    u8 *pos;
    String_Const_u8 text;
};

struct Config_Error_List{
    Config_Error *first;
    Config_Error *last;
    i32 count;
};

struct Config_Parser{
    Token *token;
    Token *opl;
    
    String_Const_u8 file_name;
    String_Const_u8 data;
    
    Arena *arena;
    
    Config_Error_List errors;
};

struct Config_LValue{
    String_Const_u8 identifier;
    i32 index;
};

typedef i32 Config_RValue_Type;
enum{
    ConfigRValueType_Null,
    ConfigRValueType_LValue,
    ConfigRValueType_Boolean,
    ConfigRValueType_Integer,
    ConfigRValueType_String,
    ConfigRValueType_Compound,
    ConfigRValueType_COUNT
};

struct Config_Compound{
    struct Config_Compound_Element *first;
    struct Config_Compound_Element *last;
    i32 count;
};

struct Config_RValue{
    Config_RValue_Type type;
    union{
        Config_LValue *lvalue;
        b32 boolean;
        i32 integer;
        u32 uinteger;
        String_Const_u8 string;
        char character;
        Config_Compound *compound;
    };
};

struct Config_Integer{
    b32 is_signed;
    union{
        i32 integer;
        u32 uinteger;
    };
};

typedef i32 Config_Layout_Type;
enum{
    ConfigLayoutType_Unset,
    ConfigLayoutType_Identifier,
    ConfigLayoutType_Integer,
    ConfigLayoutType_COUNT,
};
struct Config_Layout{
    Config_Layout_Type type;
    u8 *pos;
    union{
        String_Const_u8 identifier;
        i32 integer;
    };
};

struct Config_Compound_Element{
    Config_Compound_Element *next;
    Config_Compound_Element *prev;
    
    Config_Layout l;
    Config_RValue *r;
};

struct Config_Assignment{
    Config_Assignment *next;
    Config_Assignment *prev;
    
    u8 *pos;
    Config_LValue *l;
    Config_RValue *r;
    
    b32 visited;
};

struct Config{
    i32 *version;
    Config_Assignment *first;
    Config_Assignment *last;
    i32 count;
    
    Config_Error_List errors;
    
    String_Const_u8 file_name;
    String_Const_u8 data;
};

////////////////////////////////
// NOTE(allen): Config Iteration

typedef i32 Iteration_Step_Result;
enum{
    Iteration_Good = 0,
    Iteration_Skip = 1,
    Iteration_Quit = 2,
};

struct Config_Get_Result{
    b32 success;
    Config_RValue_Type type;
    u8 *pos;
    union{
        b32 boolean;
        i32 integer;
        u32 uinteger;
        String_Const_u8 string;
        char character;
        Config_Compound *compound;
    };
};

struct Config_Iteration_Step_Result{
    Iteration_Step_Result step;
    Config_Get_Result get;
};

struct Config_Get_Result_Node{
    Config_Get_Result_Node *next;
    Config_Get_Result_Node *prev;
    Config_Get_Result result;
};

struct Config_Get_Result_List{
    Config_Get_Result_Node *first;
    Config_Get_Result_Node *last;
    i32 count;
};

////////////////////////////////
// NOTE(allen): Config Data Type

struct Config_Data{
    u8 user_name_space[256];
    String_Const_u8 user_name;
    
    String_Const_u8_Array code_exts;
    
    u8 mapping_space[64];
    String_Const_u8 mapping;
    
    u8 mode_space[64];
    String_Const_u8 mode;
    
    b8 bind_by_physical_key;
    b8 use_scroll_bars;
    b8 use_file_bars;
    b8 hide_file_bar_in_ui;
    b8 use_error_highlight;
    b8 use_jump_highlight;
    b8 use_scope_highlight;
    b8 use_paren_helper;
    b8 use_comment_keyword;
    b8 lister_whole_word_backspace_when_modified;
    b8 show_line_number_margins;
    b8 enable_output_wrapping;
    b8 indent_with_tabs;
    b8 enable_undo_fade_out;
    
    b8 enable_code_wrapping;
    b8 automatically_indent_text_on_save;
    b8 automatically_save_changes_on_build;
    b8 automatically_load_project;
    
    f32 cursor_roundness;
    f32 mark_thickness;
    f32 lister_roundness;
    
    i32 virtual_whitespace_regular_indent;
    
    i32 indent_width;
    i32 default_tab_width;
    
    u8 default_theme_name_space[256];
    String_Const_u8 default_theme_name;
    
    b8 highlight_line_at_cursor;
    
    u8 default_font_name_space[256];
    String_Const_u8 default_font_name;
    i32 default_font_size;
    b8 default_font_hinting;
    
    u8 default_compiler_bat_space[256];
    String_Const_u8 default_compiler_bat;
    
    u8 default_flags_bat_space[1024];
    String_Const_u8 default_flags_bat;
    
    u8 default_compiler_sh_space[256];
    String_Const_u8 default_compiler_sh;
    
    u8 default_flags_sh_space[1024];
    String_Const_u8 default_flags_sh;
    
    b8 lalt_lctrl_is_altgr;
};

////////////////////////////////
// NOTE(allen): Config Parser Functions

function Config_Parser def_config_parser_init(Arena *arena, String_Const_u8 file_name, String_Const_u8 data, Token_Array array);

function void def_config_parser_inc(Config_Parser *ctx);
function u8*  def_config_parser_get_pos(Config_Parser *ctx);

function b32 def_config_parser_recognize_base_kind(Config_Parser *ctx, Token_Base_Kind kind);
function b32 def_config_parser_recognize_cpp_kind(Config_Parser *ctx, Token_Cpp_Kind kind);
function b32 def_config_parser_recognize_boolean(Config_Parser *ctx);
function b32 def_config_parser_recognize_text(Config_Parser *ctx, String_Const_u8 text);

function b32 def_config_parser_match_cpp_kind(Config_Parser *ctx, Token_Cpp_Kind kind);
function b32 def_config_parser_match_text(Config_Parser *ctx, String_Const_u8 text);

function String_Const_u8 def_config_parser_get_lexeme(Config_Parser *ctx);
function Config_Integer  def_config_parser_get_int(Config_Parser *ctx);
function b32             def_config_parser_get_boolean(Config_Parser *ctx);

function void def_config_parser_recover(Config_Parser *ctx);

function Config*                  def_config_parser_top       (Config_Parser *ctx);
function i32*                     def_config_parser_version   (Config_Parser *ctx);
function Config_Assignment*       def_config_parser_assignment(Config_Parser *ctx);
function Config_LValue*           def_config_parser_lvalue    (Config_Parser *ctx);
function Config_RValue*           def_config_parser_rvalue    (Config_Parser *ctx);
function Config_Compound*         def_config_parser_compound  (Config_Parser *ctx);
function Config_Compound_Element* def_config_parser_element   (Config_Parser *ctx);

function Config* def_config_parse(Application_Links *app, Arena *arena, String_Const_u8 file_name, String_Const_u8 data, Token_Array array);
function Config* def_config_from_text(Application_Links *app, Arena *arena, String_Const_u8 file_name, String_Const_u8 data);

function Config_Error* def_config_push_error(Arena *arena, Config_Error_List *list, String_Const_u8 file_name, u8 *pos, char *error_text);
function Config_Error* def_config_push_error(Arena *arena, Config *config, u8 *pos, char *error_text);

function void def_config_parser_push_error(Config_Parser *ctx, u8 *pos, char *error_text);
function void def_config_parser_push_error_here(Config_Parser *ctx, char *error_text);

function void def_config_parser_recover(Config_Parser *ctx);

////////////////////////////////
// NOTE(allen): Dump Config to Variables

function Variable_Handle def_fill_var_from_config(Application_Links *app, Variable_Handle parent, String_ID key, Config *config);

////////////////////////////////
// NOTE(allen): Config Variables Read

function Variable_Handle def_get_config_var(String_ID key);
function void            def_set_config_var(String_ID key, String_ID val);

function b32  def_get_config_b32(String_ID key);
function void def_set_config_b32(String_ID key, b32 val);

#endif

// BOTTOM

