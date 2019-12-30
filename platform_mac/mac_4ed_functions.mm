/* macOS System/Graphics/Font API Implementations */

//////////////////////
//    System API    //
//////////////////////

////////////////////////////////

function
system_get_path_sig(){
    String_Const_u8 result = {};
    
    switch (path_code){
        case SystemPath_CurrentDirectory:
        {
            char *working_dir = getcwd(NULL, 0);
            u64 working_dir_length = cstring_length(working_dir);
            
            // TODO(yuval): Maybe use push_string_copy instead
            u8 *out = push_array(arena, u8, working_dir_length);
            block_copy(out, working_dir, working_dir_length);
            
            free(working_dir);
            
            result = SCu8(out, working_dir_length);
        } break;
        
        case SystemPath_Binary:
        {
            local_persist b32 has_stashed_4ed_path = false;
            if (!has_stashed_4ed_path){
                local_const i32 binary_path_capacity = KB(32);
                u8 *memory = (u8*)system_memory_allocate(binary_path_capacity, string_u8_litexpr(file_name_line_number));
                
                pid_t pid = getpid();
                i32 size = proc_pidpath(pid, memory, binary_path_capacity);
                Assert(size <= binary_path_capacity - 1);
                
                mac_vars.binary_path = SCu8(memory, size);
                mac_vars.binary_path = string_remove_last_folder(mac_vars.binary_path);
                mac_vars.binary_path.str[mac_vars.binary_path.size] = 0;
                
                has_stashed_4ed_path = true;
            }
            
            result = push_string_copy(arena, mac_vars.binary_path);
        } break;
    }
    
    return(result);
}

function
system_get_canonical_sig(){
    NSString *path_ns_str =
        [[NSString alloc] initWithBytes:name.data length:name.size encoding:NSUTF8StringEncoding];
    
    NSString *standardized_path_ns_str = [path_ns_str stringByStandardizingPath];
    String_Const_u8 standardized_path = SCu8((u8*)[standardized_path_ns_str UTF8String],[standardized_path_ns_str lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    
    String_Const_u8 result = push_string_copy(arena, standardized_path);
    
    [path_ns_str release];
    
    return(result);
}

////////////////////////////////

function File_Attributes
mac_get_file_attributes(struct stat file_stat) {
    File_Attributes result;
    result.size = file_stat.st_size;
    result.last_write_time = file_stat.st_mtimespec.tv_sec;
    
    result.flags = 0;
    if (S_ISDIR(file_stat.st_mode)) {
        result.flags |= FileAttribute_IsDirectory;
    }
    
    return(result);
}

function inline File_Attributes
mac_file_attributes_from_path(char *path) {
    File_Attributes result = {};
    
    struct stat file_stat;
    if (stat(path, &file_stat) == 0){
        result = mac_get_file_attributes(file_stat);
    }
    
    return(result);
}

function inline File_Attributes
mac_file_attributes_from_fd(i32 fd) {
    File_Attributes result = {};
    
    struct stat file_stat;
    if (fstat(fd, &file_stat) == 0){
        result = mac_get_file_attributes(file_stat);
    }
    
    return(result);
}

function
system_get_file_list_sig(){
    File_List result = {};
    
    u8 *c_directory = push_array(arena, u8, directory.size + 1);
    block_copy(c_directory, directory.str, directory.size);
    c_directory[directory.size] = 0;
    
    DIR *dir = opendir((char*)c_directory);
    if (dir){
        File_Info* first = 0;
        File_Info* last = 0;
        i32 count = 0;
        
        for (struct dirent *entry = readdir(dir);
             entry;
             entry = readdir(dir)){
            char *c_file_name = entry->d_name;
            String_Const_u8 file_name = SCu8(c_file_name);
            
            if (string_match(file_name, string_u8_litexpr(".")) || string_match(file_name, string_u8_litexpr(".."))){
                continue;
            }
            
            File_Info *info = push_array(arena, File_Info, 1);
            sll_queue_push(first, last, info);
            count += 1;
            
            info->file_name = push_string_copy(arena, file_name);
            
            // NOTE(yuval): Get file attributes
            {
                Temp_Memory temp = begin_temp(arena);
                
                b32 append_slash = false;
                u64 file_path_size = directory.size + file_name.size;
                if (string_get_character(directory, directory.size - 1) != '/'){
                    append_slash = true;
                    file_path_size += 1;
                }
                
                char *file_path = push_array(arena, char, file_path_size + 1);
                char *file_path_at = file_path;
                
                block_copy(file_path_at, directory.str, directory.size);
                file_path_at += directory.size;
                
                if (append_slash){
                    *file_path_at = '/';
                    file_path_at += 1;
                }
                
                block_copy(file_path_at, file_name.str, file_name.size);
                file_path_at += file_name.size;
                
                *file_path_at = 0;
                
                info->attributes = mac_file_attributes_from_path(file_path);
                
                end_temp(temp);
            }
        }
        
        closedir(dir);
        
        result.infos = push_array(arena, File_Info*, count);
        result.count = count;
        
        i32 index = 0;
        for (File_Info *node = first;
             node != 0;
             node = node->next){
            result.infos[index] = node;
            index += 1;
        }
    }
    
    return(result);
}

function
system_quick_file_attributes_sig(){
    Temp_Memory temp = begin_temp(scratch);
    
    char *c_file_name = push_array(scratch, char, file_name.size + 1);
    block_copy(c_file_name, file_name.str, file_name.size);
    c_file_name[file_name.size] = 0;
    
    File_Attributes result = mac_file_attributes_from_path(c_file_name);
    
    end_temp(temp);
    
    return(result);
}

function inline Plat_Handle
mac_to_plat_handle(i32 fd){
    Plat_Handle result = *(Plat_Handle*)(&fd);
    return(result);
}

function inline i32
mac_to_fd(Plat_Handle handle){
    i32 result = *(i32*)(&handle);
    return(result);
}

function
system_load_handle_sig(){
    b32 result = false;
    
    i32 fd = open(file_name, O_RDONLY);
    if ((fd != -1) && (fd != 0)) {
        *out = mac_to_plat_handle(fd);
        result = true;
    }
    
    return(result);
}

function
system_load_attributes_sig(){
    i32 fd = mac_to_fd(handle);
    File_Attributes result = mac_file_attributes_from_fd(fd);
    
    return(result);
}

function
system_load_file_sig(){
    i32 fd = mac_to_fd(handle);
    
    do{
        ssize_t bytes_read = read(fd, buffer, size);
        if (bytes_read == -1){
            if (errno != EINTR){
                // NOTE(yuval): An error occured while reading from the file descriptor
                break;
            }
        } else{
            size -= bytes_read;
            buffer += bytes_read;
        }
    } while (size > 0);
    
    b32 result = (size == 0);
    return(result);
}

function
system_load_close_sig(){
    b32 result = true;
    
    i32 fd = mac_to_fd(handle);
    if (close(fd) == -1){
        // NOTE(yuval): An error occured while close the file descriptor
        result = false;
    }
    
    return(result);
}

function
system_save_file_sig(){
    File_Attributes result = {};
    
    i32 fd = open(file_name, O_WRONLY | O_TRUNC | O_CREAT, 00640);
    if (fd != -1) {
        do{
            ssize_t bytes_written = write(fd, data.str, data.size);
            if (bytes_written == -1){
                if (errno != EINTR){
                    // NOTE(yuval): An error occured while writing to the file descriptor
                    break;
                }
            } else{
                data.size -= bytes_written;
                data.str += bytes_written;
            }
        } while (data.size > 0);
        
        if (data.size == 0) {
            result = mac_file_attributes_from_fd(fd);
        }
        
        close(fd);
    }
    
    return(result);
}

////////////////////////////////

function inline System_Library
mac_to_system_library(void *dl_handle){
    System_Library result = *(System_Library*)(&dl_handle);
    return(result);
}

function inline void*
mac_to_dl_handle(System_Library system_lib){
    void *result = *(void**)(&system_lib);
    return(result);
}

function
system_load_library_sig(){
    b32 result = false;
    
    void *lib = 0;
    
    // NOTE(yuval): Open library handle
    {
        Temp_Memory temp = begin_temp(scratch);
        
        char *c_file_name = push_array(scratch, char, file_name.size + 1);
        block_copy(c_file_name, file_name.str, file_name.size);
        c_file_name[file_name.size] = 0;
        
        lib = dlopen(c_file_name, RTLD_LAZY | RTLD_GLOBAL);
        
        end_temp(temp);
    }
    
    if (lib){
        *out = mac_to_system_library(lib);
        result = true;
    }
    
    return(result);
}

function
system_release_library_sig(){
    void *lib = mac_to_dl_handle(handle);
    i32 rc = dlclose(lib);
    
    b32 result = (rc == 0);
    return(result);
}

function
system_get_proc_sig(){
    void *lib = mac_to_dl_handle(handle);
    Void_Func *result = (Void_Func*)dlsym(lib, proc_name);
    
    return(result);
}

////////////////////////////////

function
system_now_time_sig(){
    u64 now = mach_absolute_time();
    
    // NOTE(yuval): Now time nanoseconds conversion
    f64 now_nano = (f64)((f64)now *
                         (f64)mac_vars.timebase_info.numer /
                         (f64)mac_vars.timebase_info.denom);
    
    // NOTE(yuval): Conversion to useconds
    u64 result = (u64)(now_nano * 1.0E-3);
    return(result);
}

function
system_wake_up_timer_create_sig(){
    Mac_Object *object = mac_alloc_object(MacObjectKind_Timer);
    dll_insert(&mac_vars.timer_objects, &object->node);
    
    object->timer.timer = nil;
    
    Plat_Handle result = mac_to_plat_handle(object);
    return(result);
}

function
system_wake_up_timer_release_sig(){
    Mac_Object *object = (Mac_Object*)mac_to_object(handle);
    if (object->kind == MacObjectKind_Timer){
        if ((object->timer.timer != nil) && [object->timer.timer isValid]) {
            [object->timer.timer invalidate];
            mac_free_object(object);
        }
    }
}

function
system_wake_up_timer_set_sig(){
    Mac_Object *object = (Mac_Object*)mac_to_object(handle);
    if (object->kind == MacObjectKind_Timer){
        f64 time_seconds = ((f64)time_milliseconds / 1000.0);
        object->timer.timer = [NSTimer scheduledTimerWithTimeInterval: time_seconds
                target: mac_vars.view
                selector: @selector(requestDisplay)
                userInfo: nil repeats:NO];
    }
}

function
system_signal_step_sig(){
    NotImplemented;
}

function
system_sleep_sig(){
    NotImplemented;
}

////////////////////////////////

function
system_post_clipboard_sig(){
    NotImplemented;
}

////////////////////////////////

function
system_cli_call_sig(){
    b32 result = false;
    
    NotImplemented;
    
    return(result);
}

function
system_cli_begin_update_sig(){
    NotImplemented;
}

function
system_cli_update_step_sig(){
    b32 result = false;
    
    NotImplemented;
    
    return(result);
}

function
system_cli_end_update_sig(){
    b32 result = false;
    
    NotImplemented;
    
    return(result);
}

////////////////////////////////

function
system_open_color_picker_sig(){
    NotImplemented;
}

function
system_get_screen_scale_factor_sig(){
    f32 result = 0.0f;
    
    NotImplemented;
    
    return(result);
}

////////////////////////////////

function
system_thread_launch_sig(){
    System_Thread result = {};
    
    NotImplemented;
    
    return(result);
}

function
system_thread_join_sig(){
    NotImplemented;
}

function
system_thread_free_sig(){
    NotImplemented;
}

function
system_thread_get_id_sig(){
    i32 result = 0;
    
    NotImplemented;
    
    return(result);
}

function
system_acquire_global_frame_mutex_sig(){
    NotImplemented;
}

function
system_release_global_frame_mutex_sig(){
    NotImplemented;
}

function
system_mutex_make_sig(){
    System_Mutex result = {};
    
    NotImplemented;
    
    return(result);
}

function
system_mutex_acquire_sig(){
    NotImplemented;
}

function
system_mutex_release_sig(){
    NotImplemented;
}

function
system_mutex_free_sig(){
    NotImplemented;
}

function
system_condition_variable_make_sig(){
    System_Condition_Variable result = {};
    
    NotImplemented;
    
    return(result);
}

function
system_condition_variable_wait_sig(){
    NotImplemented;
}

function
system_condition_variable_signal_sig(){
    NotImplemented;
}

function
system_condition_variable_free_sig(){
    NotImplemented;
}

////////////////////////////////

function
system_memory_allocate_sig(){
    void* result = malloc(size);
    
    return(result);
}

function
system_memory_set_protection_sig(){
    b32 result = false;
    
    NotImplemented;
    
    return(result);
}

function
system_memory_free_sig(){
    NotImplemented;
}

function
system_memory_annotation_sig(){
    Memory_Annotation result = {};
    
    NotImplemented;
    
    return(result);
}

////////////////////////////////

function
system_show_mouse_cursor_sig(){
    NotImplemented;
}

function
system_set_fullscreen_sig(){
    b32 result = false;
    
    NotImplemented;
    
    return(result);
}

function
system_is_fullscreen_sig(){
    b32 result = false;
    
    NotImplemented;
    
    return(result);
}

function
system_get_keyboard_modifiers_sig(){
    Input_Modifier_Set result = {};
    
    NotImplemented;
    
    return(result);
}

////////////////////////////////

////////////////////////
//    Graphics API    //
////////////////////////

////////////////////////////////

function
graphics_get_texture_sig(){
    u32 result = 0;
    
    NotImplemented;
    
    return(result);
}

function
graphics_fill_texture_sig(){
    b32 result = false;
    
    NotImplemented;
    
    return(result);
}

////////////////////////////////

////////////////////
//    Font API    //
////////////////////

////////////////////////////////

function
font_make_face_sig(){
    Face* result = 0;
    
    NotImplemented;
    
    return(result);
}

////////////////////////////////