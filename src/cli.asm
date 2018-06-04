; void recursive_listing(wchar_t *root_directory, unsigned int depth)
recursive_listing PROC
		push ebp
		mov ebp, esp
		
		; malloc addr	[ebp-4]
		; file handler	[ebp-8]
		sub esp, 8
		
		cmp DWORD PTR[ebp+12], 0
		je skip_free ; if the depth equals 0, we stop the function and return (no calloc yet -> skip free)
		
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
		
		mov eax, FileData.dwFileAttributes
		and eax, FILE_ATTRIBUTE_DIRECTORY
		cmp eax, 0
		jne skip_print ; If it's a directory, we skip the prints
		
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
		
	skip_print:
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
	
recursive_listing ENDP