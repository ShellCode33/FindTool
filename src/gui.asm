; http://www.alsprogrammingresource.com/list_boxes.html

.DATA
StartGUI db "Starting GUI...",10, 0
AppName db "FindTool", 0
WindowWidth equ 500
WindowHeight equ 400

ListBoxName db "Listbox", 0
ListBoxId equ 1337
Item1 db "Item 1", 0
Item2 db "Item 2", 0
Item3 db "Item 3", 0

PrintInt db "%s", 10, 0

; Errors
RegisterWindowError db "Failed to register the window class.", 10, 0
CantCreateWindowError db "Can't create the window.", 10, 0
CantCreateListBoxError db "Can't create the listbox.", 10, 0

.DATA?
hInstance HINSTANCE ?
mainWindowHWND HWND ?
hwndListBox HWND ?
wc WNDCLASSEX <>
msg MSG <>

rootDirectory dd ?
depth dd ?


.CODE
start_gui PROC
		push ebp
		mov ebp, esp
		
		mov eax, [ebp+8]
		mov [rootDirectory], eax
		
		mov eax, [ebp+12]
		mov [depth], eax
		
		push offset StartGUI
		call crt_printf
		add esp, 4
		
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
		push WS_OVERLAPPEDWINDOW
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
		
		push NULL
		push eax
		push ListBoxId
		push [ebp+8]
		push WindowHeight
		push WindowWidth
		push 0
		push 0
		push WS_VISIBLE or WS_CHILD or LBS_STANDARD or LBS_NOTIFY
		push NULL
		push offset ListBoxName
		push 0
		call CreateWindowEx

		cmp eax, NULL
		je listbox_create_failed
		
		mov hwndListBox, eax
		
		push offset Item1
		push 0
		push LB_ADDSTRING
		push hwndListBox
		call SendMessage
		
		push depth
		push rootDirectory
		call recursive_listing_gui
		
		jmp stop_function
		
	WM_DESTROY_CASE:
		push NULL
		call PostQuitMessage
		jmp stop_function
	
	listbox_create_failed:
		push offset CantCreateListBoxError
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
		cmp WORD PTR[ebx+eax], '\' ; TODO : test SizeOfWchar to cmp a WORD or a DWORD
		jne done_removing_backslashes
		
		; TODO : test SizeOfWchar to cmp a WORD or a DWORD
		mov WORD PTR[ebx+eax], 0 ; replace \ by a null byte
		jmp remove_backslash
		
	done_removing_backslashes:
	
		; If no wildcard is specified, we print the root and append /*, otherwise we skip that and go to the listing
		
		push ebx ; root parameter
		call is_wildcard_in_string
		cmp eax, 0
		jne retreive_first_file ; If there is a wildcard already, we skip the appending
		
		; Print the root alone as if it were a file
		push ebx
		push offset PrintFile
		call printf_unicode
		
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
		je next_loop_step
		
		; Ignore file if it's '..'
		push offset ToExcludeFromListing2
		push offset FileData.cFileName
		call crt_wcscmp
		add esp, 8 ; strcmp doesn't remove parameters from the stack
		cmp eax, 0
		je next_loop_step
		
		push [ebp-4]
		call crt_wcslen
		cmp eax, 0
		je skip_print_root ; If the root is empty (can happen with relative paths when specifying only one single directory), we skip printing the root and the backslash
		
		; Print root
		push [ebp-4]
		push offset PrintRoot
		call printf_unicode

	skip_print_root:
		; Print filename
		push offset FileData.cFileName
		push offset PrintFile
		call printf_unicode
		
		push offset FileData.cFileName
		push 0
		push LB_ADDSTRING
		push hwndListBox
		call SendMessageW
		
		mov eax, FileData.dwFileAttributes
		and eax, FILE_ATTRIBUTE_DIRECTORY
		cmp eax, 0
		je next_loop_step ; If it's a directory : recursive call, otherwise we continue the loop
		
		; PREPARING RECURSIVE CALL

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
		
		; Decrement the depth
		mov ebx, [ebp+12]
		dec ebx
		
		push ebx ; push the depth
		push eax ; push malloc addr (which is the new path)
		call recursive_listing
		
		; malloc addr is already on the stack
		call crt_free
		add esp, 4
		
	next_loop_step:
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