.386
.model flat,stdcall
option casemap:none

include c:\masm32\include\windows.inc
include c:\masm32\include\gdi32.inc
include c:\masm32\include\gdiplus.inc
include c:\masm32\include\user32.inc
include c:\masm32\include\kernel32.inc
include c:\masm32\include\msvcrt.inc
include c:\masm32\include\shlwapi.inc
include c:\masm32\include\shell32.inc
include c:\masm32\include\OleAut32.inc
include c:\masm32\macros\macros.asm ; only for WSTR which is very useful to create unicode strings

includelib c:\masm32\lib\gdi32.lib
includelib c:\masm32\lib\kernel32.lib
includelib c:\masm32\lib\user32.lib
includelib c:\masm32\lib\msvcrt.lib
includelib c:\masm32\lib\shlwapi.lib
includelib c:\masm32\lib\shell32.lib
includelib c:\masm32\lib\OleAut32.lib


;32 ,16, 8, 8 bits
;EAX,AX,AH,AL : Called the Accumulator register. 
;               It is used for I/O port access, arithmetic, interrupt calls,
;               etc...
;
;EBX,BX,BH,BL : Called the Base register
;               It is used as a base pointer for memory access
;               Gets some interrupt return values
;
;ECX,CX,CH,CL : Called the Counter register
;               It is used as a loop counter and for shifts
;               Gets some interrupt values
;
;EDX,DX,DH,DL : Called the Data register
;
;ES:EDI EDI DI : Destination index register
;                Used for string, memory array copying and setting and
;                for far pointer addressing with ES
;
;DS:ESI EDI SI : Source index register
;                Used for string and memory array copying
;
;SS:EBP EBP BP : Stack Base pointer register
;                Holds the base address of the stack
;
;SS:ESP ESP SP : Stack pointer register
;                Holds the top address of the stack
;
;CS:EIP EIP IP : Index Pointer
;                Holds the offset of the next instruction
;                It can only be read 
				
.DATA
; variables initialisees

;ERRORS
FileError db "Can't open file or file doesn't exist.", 10, 0
PathTooLongError db "The path you're trying to access is too long. Skipping it.", 10, 0

SizeOfWchar dd 2 ; I haven't find a way to do a sizeof(wchar_t) so I hardcoded the value. If the program doesn't work, you should try to set this value to 4.

; | is my custom printf_unicode formatter
WSTR Formatter, "|", 0
WSTR MissingArgument, "Usage: | [DIRECTORY]", 10, 0
WSTR PrintRoot, "|\", 0
WSTR PrintFile, "|", 10, 0
WSTR ToExcludeFromListing1, ".", 0
WSTR ToExcludeFromListing2, "..", 0
WSTR BackSlash, "\", 0
WSTR EndPathWildcard, "\*", 0
WSTR DepthArg1, "--depth", 0
WSTR DepthArg2, "-d", 0
WSTR Wildcard1, "*", 0
WSTR Wildcard2, "?", 0
WSTR Wildcard3, 62, 0 ; >
WSTR Wildcard4, 60, 0 ; <
WSTR Wildcard5, 34, 0 ; "

.DATA?
; variables non-initialisees (bss)
FileData WIN32_FIND_DATAW <>
FileHandle HANDLE ?
StdOut dd ?
ArgC dd ?

.CODE

start:

	call GetCommandLineW
	
	push offset ArgC
	push eax ; pointer to the command line returned by GetCommandLineW
	call CommandLineToArgvW ; Parses the command line
	
	push eax
	push [ArgC]
	call main
	
	; free allocated argv by CommandLineToArgvW
	call LocalFree ; argv addr is still on top of the stack

	ret

	; void main(int argc, char **argv)
	main PROC
			push ebp
			mov ebp, esp
			
			push -1 ; default depth (=infinite depth)  [ebp-4]
			
			push STD_OUTPUT_HANDLE
			call GetStdHandle
			mov [StdOut], eax
			
			; directory offset in the command line. By default the offset is 4 because de directory is the second argument of the command line. But if the depth is specified, the offset might be 12
			; "find --depth 3 .."
			;    0      4   8 12  <-- possible offsets
			mov ebx, 4
			
			; argc = [ebp+8]
			cmp DWORD PTR[ebp+8], 2
			je start_listing
			
			cmp DWORD PTR[ebp+8], 4
			je use_depth
			
			jmp argc_error
			
		use_depth:
			mov eax, [ebp+12] ; argv addr
			push [eax+4]
			push offset DepthArg1
			call crt_wcscmp
			cmp eax, 0
			je directory_last
			
			mov eax, [ebp+12] ; argv addr
			push [eax+4]
			push offset DepthArg2
			call crt_wcscmp
			cmp eax, 0
			je directory_last
			
			mov eax, [ebp+12] ; argv addr
			push [eax+8]
			push offset DepthArg1
			call crt_wcscmp
			cmp eax, 0
			je directory_first
			
			mov eax, [ebp+12] ; argv addr
			push [eax+8]
			push offset DepthArg2
			call crt_wcscmp
			cmp eax, 0
			je directory_first
			
		directory_first:
			mov eax, [ebp+12] ; argv addr
			mov eax, [eax+12] ; the 4th parameter is the depth to use
			mov ecx, 12 ; depth string offset
			jmp parse_depth
		
		directory_last:
			mov eax, [ebp+12] ; argv addr
			mov eax, [eax+8] ; the 3d parameter is the depth to use
			mov ebx, 12 ; change directory offset
			mov ecx, 8 ; depth string offset
			; jmp parse_depth
			
		parse_depth:
			mov eax, [ebp+12] ; argv addr
			lea ebx, [ebp-4]
			
			push ebx
			push 0 ; = STIF_DEFAULT
			push [eax+ecx]
			call StrToIntExW
			
		
		start_listing:
			mov eax, [ebp+12] ; argv addr
			
			push [ebp-4] ; depth
			push [eax+ebx] ; directory string
			call recursive_listing

			jmp stop_function
		
		argc_error:
			mov eax, [ebp+12]
			push [eax]
			push offset MissingArgument
			call printf_unicode
			
		stop_function:
			leave
			ret 4 ; 4 because we still need the argv pointer to LocalFree it
	main ENDP
	
	; void recursive_listing(wchar_t *root_directory, unsigned int depth)
	recursive_listing PROC
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
			
			push [SizeOfWchar] ; unicode characters are not on 1 byte so we use calloc and pass the size of each element
			push eax
			call crt_calloc
			add esp, 8
			mov [ebp-4], eax ; save malloc addr on the stack
			
			push [ebp+8] ; original string we want to copy
			push eax ; malloc addr
			call crt_wcscpy
			add esp, 8
			
			mov eax, ebx ; restore string lenght in eax
			mul [SizeOfWchar] ; convert string size to bytes size
			mov ebx, [ebp-4] ; root string addr is now in ebx
			
		remove_backslash:
			sub eax, [SizeOfWchar]
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
			
			push [SizeOfWchar]
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
	
	is_wildcard_in_string PROC
			push ebp
			mov ebp, esp
			
			mov esi, [ebp+8]
			
			push offset Wildcard1
			push esi
			call crt_wcsstr
			cmp eax, NULL
			jne wildcard_found
			
			push offset Wildcard2
			push esi
			call crt_wcsstr
			cmp eax, NULL
			jne wildcard_found
			
			push offset Wildcard3
			push esi
			call crt_wcsstr
			cmp eax, NULL
			jne wildcard_found
			
			push offset Wildcard4
			push esi
			call crt_wcsstr
			cmp eax, NULL
			jne wildcard_found
			
			push offset Wildcard5
			push esi
			call crt_wcsstr
			cmp eax, NULL
			jne wildcard_found
			
			jmp stop_function
		
		wildcard_found:
			mov eax, 1
		
		stop_function:
			leave
			ret 4
	is_wildcard_in_string ENDP
	
	; This function is able to print unicode correctly in the terminal. crt_wprintf doesn't show special characters such as éèàç
	; Variadic function in order to be able to print formated unicode using the following formatter : |
	; This only formatter will take the address on the stack of an unicode string and print it instead of |
	; I chose to use | because a Windows path can't contain that character.
	; void printf_unicode(WSTR *format, ...)
	printf_unicode PROC
			push ebp
			mov ebp, esp
			
			mov esi, [ebp+8]
			
			; allocate space for the string size (numbers of characters, not bytes) [ebp-4]
			; allocate space for substring address of crt_wcsstr [ebp-8]
			sub esp, 8
			push 12 ; [ebp+12] --> offset of first potential parameter. [ebp-12]
			
			; create a copy of the formatter because we will put some \0 in it to remove formatters.
			push esi
			call SysAllocString
			mov esi, eax
			mov [ebp+8], esi ; overwrite previous string address
			
			mov ecx, 0 ; loop index
			
		begin_loop:
			
			push offset Formatter
			push esi
			call crt_wcsstr
			cmp eax, NULL
			je no_formatter_found
			
			mov [ebp-8], eax
			
			cmp DWORD PTR[SizeOfWchar], 4
			je dword_size
			
			mov WORD PTR[eax], 0 ; remove the formatter with a null byte, supposing wide characters are on 2 bytes... (Can change from one machine to another...)
			jmp skip_dword_size
			
		dword_size:
			mov DWORD PTR[eax], 0 ; remove the formatter with a null byte, supposing wide characters are on 4 bytes... (Can change from one machine to another...)
		
		skip_dword_size:
			push esi
			call crt_wcslen
			mov [ebp-4], eax
			
			; put string size address in eax
			lea eax, [ebp-4]
			
			; print current string token
			push NULL
			push eax
			push [eax]
			push esi
			push [StdOut]
			call WriteConsoleW
			
			mov eax, [ebp-12] ; load string offset to print
			mov ebx, [ebp+eax]
			
			push ebx
			call crt_wcslen
			mov [ebp-4], eax
			
			; put string size address in eax
			lea eax, [ebp-4]
			
			; print variadic arg string
			push NULL
			push eax
			push [eax]
			push ebx
			push [StdOut]
			call WriteConsoleW
			
			add DWORD PTR[ebp-12], 4 ; increase stack offset to point on the next arg
			
			mov esi, [ebp-8] ; skip that part of the string
			add esi, [SizeOfWchar] ; skip null byte, supposing wide characters are on 2 bytes... (Can change from one machine to another...)
			jmp begin_loop
			
		no_formatter_found:
			
			push esi
			call crt_wcslen
			mov [ebp-4], eax
			
			; put string size address in eax
			lea eax, [ebp-4]
			
			; print last string token
			push NULL
			push eax
			push [eax]
			push esi
			push [StdOut]
			call WriteConsoleW
			
			push [ebp+8]
			call SysFreeString
			
			; we use [ebp-12] to know how many bytes we should remove from the stack
			sub DWORD PTR[ebp-12], 8 ; sub 8 because it was the first arg offset (the format string) and we want to know how many bytes were given as parameters
			mov ebx, [ebp-12]
			leave

			pop eax ; save return address in eax
			
			add esp, ebx ; clean stack
			push eax ; restore return address
			ret
	printf_unicode ENDP
end start
