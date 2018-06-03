.DATA
; Windows path wildcards
WSTR Wildcard1, "*", 0
WSTR Wildcard2, "?", 0
WSTR Wildcard3, 62, 0 ; >
WSTR Wildcard4, 60, 0 ; <
WSTR Wildcard5, 34, 0 ; "

SizeOfWchar equ SIZEOF WCHAR

.CODE

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
		push 12 ; [ebp+12] is the offset of the first potential parameter. [ebp-12]
		
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
		mov WORD PTR[eax], 0 ; remove the formatter with a null byte, supposing wide characters are on 2 bytes...

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
		push StdOut
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
		push StdOut
		call WriteConsoleW
		
		add DWORD PTR[ebp-12], 4 ; increase stack offset to point on the next arg
		
		mov esi, [ebp-8] ; skip that part of the string
		add esi, SizeOfWchar ; skip null byte, supposing wide characters are on 2 bytes... (Can change from one machine to another...)
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
		push StdOut
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