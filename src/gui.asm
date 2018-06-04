.DATA
AppName db "FindTool", 0
WindowWidth equ 500
WindowHeight equ 400
DefaultPadding equ 10

EditBox db "EDIT", 0
EditBoxId equ 1337

Button db "BUTTON", 0
ButtonId equ 1338
ButtonContent db "FIND", 0

WSTR LookingFor, "Looking for '|'...", 10, 0

ListBox db "LISTBOX", 0
ListBoxId equ 1339

BufferSize equ 1024

; Errors
RegisterWindowError db "Failed to register the window class.", 10, 0
CantCreateWindowError db "Can't create the window.", 10, 0
CantCreateComponentError db "Can't create component in the window.", 10, 0

.DATA?
hInstance HINSTANCE ?
wc WNDCLASSEX <>
msg MSG <>

mainWindowHWND HWND ?
hwndButton HWND ?
hwndEditBox HWND ?
hwndListBox HWND ?

rootDirectory dd ?
depth dd ?

InputBuffer WORD BufferSize dup (?) ; This buffer will be used by the GetWindowText function to get the data inside the EditBox

.CODE
start_gui PROC
		push ebp
		mov ebp, esp
		
		mov eax, [ebp+8]
		mov rootDirectory, eax
		
		mov eax, [ebp+12]
		mov depth, eax
		
		push rootDirectory
		push offset LookingFor
		call printf_unicode
		
		push NULL
		call GetModuleHandle
		mov hInstance, eax
		
		mov wc.cbSize, SIZEOF WNDCLASSEX
		mov wc.style, NULL
		mov wc.lpfnWndProc, offset events_handler
		mov wc.cbClsExtra, NULL
		mov wc.cbWndExtra, NULL
		push hInstance
		pop wc.hInstance
		mov wc.hbrBackground, COLOR_WINDOW+1
		mov wc.lpszMenuName, NULL
		mov wc.lpszClassName, offset AppName
		
		push IDI_APPLICATION
		push NULL
		call LoadIcon
		mov wc.hIcon, eax
		mov wc.hIconSm, eax
		
		push IDC_ARROW
		push NULL
		call LoadCursor
		mov wc.hCursor, eax
		
		push offset wc
		call RegisterClassEx
		
		cmp eax, NULL
		je register_window_failed
		
		push NULL
		push hInstance
		push NULL
		push NULL
		push WindowHeight
		push WindowWidth
		push CW_USEDEFAULT
		push CW_USEDEFAULT
		push WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX
		push offset AppName
		push offset AppName
		push WS_EX_CLIENTEDGE
		call CreateWindowEx
		
		cmp eax, NULL
		je cant_create_window
		
		mov mainWindowHWND, eax
		
		push SW_SHOWDEFAULT
		push mainWindowHWND
		call ShowWindow
		
		push mainWindowHWND
		call UpdateWindow
		
	handle_messages:
		push 0
		push 0
		push NULL
		push offset msg
		call GetMessage
		
		cmp eax, 0
		je stop_function
		
		push offset msg
		call TranslateMessage
		
		push offset msg
		call DispatchMessage
	
		jmp handle_messages
		
	register_window_failed:
		push offset RegisterWindowError
		call crt_printf
		add esp, 4
		jmp stop_function
		
	cant_create_window:
		push offset CantCreateWindowError
		call crt_printf
		add esp, 4
		jmp stop_function
		
	stop_function:
	
		leave
		ret 8
start_gui ENDP

events_handler PROC
		push ebp
		mov ebp, esp
		
		; hwnd:HWND 	[ebp+8]
		; uMsg:UINT 	[ebp+12]
		; wParam:WPARAM [ebp+16]
		; lParam:LPARAM [ebp+20]
		
		cmp DWORD PTR[ebp+12], WM_CREATE
		je WM_CREATE_CASE

		cmp DWORD PTR[ebp+12], WM_COMMAND
		je WM_COMMAND_CASE
		
		cmp DWORD PTR[ebp+12], WM_DESTROY
		je WM_DESTROY_CASE
		
		; Default message processing
		push [ebp+20]
		push [ebp+16]
		push [ebp+12]
		push [ebp+8]
		call DefWindowProc
		leave
		ret 16
		
	WM_CREATE_CASE:
		
		push GWL_HINSTANCE
		push [ebp+8]
		call GetWindowLong
		mov ebx, eax
		
		push NULL
		push ebx
		push EditBoxId
		push [ebp+8]
		push 20
		push WindowWidth-100
		push DefaultPadding
		push DefaultPadding
		push WS_VISIBLE or WS_CHILD or WS_BORDER
		push NULL
		push offset EditBox
		push 0
		call CreateWindowEx
		
		cmp eax, NULL
		je window_component_create_failed
		
		mov hwndEditBox, eax
	
		push rootDirectory
		push 0
		push WM_SETTEXT
		push hwndEditBox
		call SendMessageW
		
		push NULL
		push ebx
		push ButtonId
		push [ebp+8]
		push 20
		push 60
		push DefaultPadding
		push WindowWidth-80
		push WS_VISIBLE or WS_CHILD or BS_DEFPUSHBUTTON
		push offset ButtonContent
		push offset Button
		push 0
		call CreateWindowEx
		
		cmp eax, NULL
		je window_component_create_failed
		
		mov hwndButton, eax
		
		push NULL
		push ebx
		push ListBoxId
		push [ebp+8]
		push WindowHeight-70
		push WindowWidth-30
		push 40
		push DefaultPadding
		push WS_VISIBLE or WS_CHILD or LBS_STANDARD or LBS_NOTIFY
		push NULL
		push offset ListBox
		push 0
		call CreateWindowEx

		cmp eax, NULL
		je window_component_create_failed
		
		mov hwndListBox, eax
		
		push depth
		push rootDirectory
		call recursive_listing_gui
		
		jmp stop_function
		
	WM_COMMAND_CASE:
		movsx eax, WORD PTR[ebp+18] ; <=> HIWORD Macro (http://www.masmforum.com/board/index.php?PHPSESSID=786dd40408172108b65a5a36b09c88c0&topic=18144.0)
		
		cmp eax, BN_CLICKED
		je button_clicked
		
		jmp stop_function
		
	button_clicked:
		
		push BufferSize
		push offset InputBuffer
		push hwndEditBox
		call GetWindowTextW
		
		push offset InputBuffer
		push offset LookingFor
		call printf_unicode
		
		
		; Clean existing data in the ListBox
		push 0
		push 0
		push LB_RESETCONTENT
		push hwndListBox
		call SendMessageW
		
		; call recursive_listing_gui with the directory in the edit box
		push -1 ; TODO : create an EditBox to change de depth
		push offset InputBuffer
		call recursive_listing_gui
		
		jmp stop_function
		
	WM_DESTROY_CASE:
		push NULL
		call PostQuitMessage
		jmp stop_function
	
	window_component_create_failed:
		push offset CantCreateComponentError
		call crt_printf
		add esp, 4
	
	stop_function:
		xor eax,eax ; return 0
		leave
		ret 16
events_handler ENDP

; void recursive_listing_gui(wchar_t *root_directory, unsigned int depth)
recursive_listing_gui PROC
		push ebp
		mov ebp, esp
		
		; malloc addr	[ebp-4]
		; file handler	[ebp-8]
		sub esp, 8
		
		cmp DWORD PTR[ebp+12], 0
		je stop_function ; if the depth equals 0, we stop the function and return
		
		; check that the root lenght isn't greater than MAX_PATH
		push [ebp+8]
		call crt_wcslen
		add esp, 4 ; clean stack (IS IT BETTER TO CLEAN THE STACK EVERYTIME OR TO KEEP EVERYTHING ON THE STACK AND CLEAN IT AT THE END OF THE FUNCTION WITH THE 'LEAVE' ? SPEED/MEMORY )
		mov ebx, eax
		
		cmp ebx, MAX_PATH
		jg path_too_long_error
		
		; We will have to alter the path given to the function but we don't wan't to change the original pointer, so we allocate memory in the heap and copy the string.
		add eax, 3 ; 1 ending null, 2 other characters for a potential \* appending
		
		push SizeOfWchar ; unicode characters are not on 1 byte so we use calloc and pass the size of each element
		push eax
		call crt_calloc
		add esp, 8
		mov [ebp-4], eax ; save malloc addr on the stack
		
		push [ebp+8] ; original string we want to copy
		push eax ; malloc addr
		call crt_wcscpy
		add esp, 8
		
		mov eax, ebx ; restore string lenght in eax
		mov ecx, SizeOfWchar
		mul ecx ; convert string size to bytes size
		mov ebx, [ebp-4] ; root string addr is now in ebx
		
	remove_backslash:
		sub eax, SizeOfWchar
		cmp WORD PTR[ebx+eax], '\'
		jne done_removing_backslashes
		
		mov WORD PTR[ebx+eax], 0 ; replace \ by a null byte
		jmp remove_backslash
		
	done_removing_backslashes:
	
		; If no wildcard is specified, we print the root and append /*, otherwise we skip that and go to the listing
		
		push ebx ; root parameter
		call is_wildcard_in_string
		cmp eax, 0
		jne retreive_first_file ; If there is a wildcard already, we skip the appending
		
		; We add the root to the listbox
		push ebx ; malloc addr
		push 0
		push LB_ADDSTRING
		push hwndListBox
		call SendMessageW
		
		; Append the wildcard
		push offset EndPathWildcard
		push [ebp-4] ; malloc addr (root string)
		call crt_wcscat
		add esp, 8
	
	retreive_first_file:
		push offset FileData
		push [ebp-4] ; root parameter
		call FindFirstFileW
		
		cmp eax, INVALID_HANDLE_VALUE
		je file_error
		
		mov [ebp-8], eax ; save iterator on the stack
		
		; Remove filename from the path
		push [ebp-4]
		call PathRemoveFileSpecW
		
	listing_loop:
		; Ignore file if it's '.'
		push offset ToExcludeFromListing1
		push offset FileData.cFileName
		call crt_wcscmp
		add esp, 8 ; strcmp doesn't remove parameters from the stack
		cmp eax, 0
		je next_loop_step_skip_free
		
		; Ignore file if it's '..'
		push offset ToExcludeFromListing2
		push offset FileData.cFileName
		call crt_wcscmp
		add esp, 8 ; strcmp doesn't remove parameters from the stack
		cmp eax, 0
		je next_loop_step_skip_free

		; ---------- Allocating memory in the heap ----------
		mov ebx, 4 ; size of the allocation (starting from 4 for the \ between the old path and the new directory, 2 more for \* at the end of the new path and 1 more for the null byte at the end)
		
		push [ebp-4]
		call crt_wcslen
		add ebx, eax ; add to ebx the size of the root
		
		push offset FileData.cFileName
		call crt_wcslen
		add ebx, eax ; add to ebx the size of the new directory to list
		
		push SizeOfWchar
		push ebx
		call crt_calloc ; malloc + put zeros in memory
		add esp, 8
		push eax ; save malloc addr
		; ---------------------------------------------------
		
		; -------------- Building the new path --------------
		push [ebp-4]
		call crt_wcslen
		add esp, 4
		cmp eax, 0
		je skip_root ; If the root is empty (can happen with relative paths when specifying only one single directory), we skip appending the root and the backslash to the new folder
		
		push [ebp-4] ; root addr
		push [esp+4] ; malloc addr
		call crt_wcscat
		add esp, 8
		
		push offset BackSlash
		push [esp+4] ; malloc addr
		call crt_wcscat
		add esp, 8

	skip_root:
		push offset FileData.cFileName
		push [esp+4] ; malloc addr
		call crt_wcscat
		add esp, 8
		; ---------------------------------------------------
		
		mov eax, FileData.dwFileAttributes
		and eax, FILE_ATTRIBUTE_DIRECTORY
		cmp eax, 0
		jne skip_print ; If it's a directory : skip adding in the listbox
		
		; We add the new path to the listbox
		push [esp] ; malloc addr
		push 0
		push LB_ADDSTRING
		push hwndListBox
		call SendMessageW
		
		jmp next_loop_step
		
	skip_print:
		; Decrement the depth
		mov ebx, [ebp+12]
		dec ebx
		
		push ebx ; push the depth
		push [esp+4] ; push malloc addr (which is the new path)
		call recursive_listing_gui
		
	next_loop_step:
		; malloc addr is already on the stack
		call crt_free
		add esp, 4
		
	next_loop_step_skip_free:
		push offset FileData
		push [ebp-8] ; FindFirstFile handler
		call FindNextFileW
		
		cmp eax, 0
		jne listing_loop
		
		jmp close_and_return
		
	file_error:
		push offset FileError
		call crt_printf
		add esp, 4
		jmp stop_function
		
	path_too_long_error:
		push offset PathTooLongError
		call crt_printf
		add esp, 4
		jmp stop_function
		
	close_and_return:
		push [ebp-8] ; FindFirstFile handler
		call FindClose
		
	stop_function:
		cmp DWORD PTR[ebp-4], NULL
		je skip_free
		
		push [ebp-4]
		call crt_free
		
	skip_free:
		leave
		ret 8
	
recursive_listing_gui ENDP