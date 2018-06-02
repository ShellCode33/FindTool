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

.DATA

; | is my custom printf_unicode formatter
WSTR Formatter, "|", 0
WSTR MissingArgument, 10, "Usage: | [DIRECTORY] [OPTIONS]", 10, "Options :", 10, 9, "--gui, -g : launches the GUI", 10, 9, "--depth, -d : maximum directory search depth", 10, 0
WSTR DepthArg1, "--depth", 0
WSTR DepthArg2, "-d", 0
WSTR GUIArg1, "--gui", 0
WSTR GUIArg2, "-g", 0

;Errors
FileError db "Can't open file or file doesn't exist.", 10, 0
PathTooLongError db "The path you're trying to access is too long. Skipping it.", 10, 0

;Path management
WSTR PrintRoot, "|\", 0
WSTR PrintFile, "|", 10, 0
WSTR ToExcludeFromListing1, ".", 0
WSTR ToExcludeFromListing2, "..", 0
WSTR BackSlash, "\", 0
WSTR EndPathWildcard, "\*", 0

plop db "%i", 10, 0

.DATA?
ArgC dd ?
StdOut dd ?
FileData WIN32_FIND_DATAW <>
FileHandle HANDLE ?

.CODE

include utils.asm
include cli.asm
include gui.asm

start:
	
	push STD_OUTPUT_HANDLE
	call GetStdHandle
	mov [StdOut], eax

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
			push 0 ; GUI enabled boolean [ebp-8]
			
			; directory offset in the command line. By default the offset is 4 because de directory is the second argument of the command line. But if the depth is specified, the offset might be 12
			; "find --depth 3 .."
			;    0      4   8 12  <-- possible offsets
			push 4 ; [ebp-12]
			
			cmp DWORD PTR[ebp+8], 1
			je argc_error
			
			; Check if the --gui has been supplied, if so, delete it from the argv and decrement argc to keep the parsing going
			
			mov ebx, 4
			
		find_gui_loop:
			mov eax, [ebp+12] ; argv addr
			
			push [eax+ebx]
			push offset GUIArg1
			call crt_wcscmp
			add esp, 8
			cmp eax, 0
			je gui_specified_in_cli 
			
			mov eax, [ebp+12] ; argv addr
			
			push [eax+ebx]
			push offset GUIArg2
			call crt_wcscmp
			add esp, 8
			cmp eax, 0
			je gui_specified_in_cli
			
			add ebx, 4
			mov eax, [ebp+8] ; argc
			mov ecx, 4
			mul ecx
			cmp eax, ebx
			je gui_not_specified ; keep looping while there are arguments to process
			
			jmp find_gui_loop
			
		gui_specified_in_cli:
			mov DWORD PTR[ebp-8], 1 ; set boolean to true
			
			; we shift arguments to the left in order to remove --gui from the command line
		shift_args_loop:
			mov eax, [ebp+8] ; argc
			mov ecx, 4
			mul ecx
			cmp ebx, eax
			je shift_done ; keep looping while there are arguments to process

			mov eax, [ebp+12] ; argv addr
			mov ecx, eax
			mov eax, [eax+ebx] ; get first string address in eax
			add ecx, ebx
			add ecx, 4 ; get argv offset that points to the next string address
			
			; swap addresses in argv
			mov edx, [ecx]
			mov [ecx], eax
			mov eax, [ebp+12]
			mov [eax+ebx], edx
			
			add ebx, 4
			jmp shift_args_loop
		
		shift_done:
			; --gui is now removed, we can decrease argc
			dec DWORD PTR[ebp+8]
			
		gui_not_specified:
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
			add esp, 8
			cmp eax, 0
			je directory_last
			
			mov eax, [ebp+12] ; argv addr
			push [eax+4]
			push offset DepthArg2
			call crt_wcscmp
			add esp, 8
			cmp eax, 0
			je directory_last
			
			mov eax, [ebp+12] ; argv addr
			push [eax+8]
			push offset DepthArg1
			call crt_wcscmp
			add esp, 8
			cmp eax, 0
			je directory_first
			
			mov eax, [ebp+12] ; argv addr
			push [eax+8]
			push offset DepthArg2
			call crt_wcscmp
			add esp, 8
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
			mov DWORD PTR[ebp-12], 12 ; change directory offset
			mov ecx, 8 ; depth string offset
			; jmp parse_depth
			
		parse_depth:
			mov eax, [ebp+12] ; argv addr
			lea ebx, [ebp-4]
			
			push ebx
			push 0 ; = STIF_DEFAULT
			push [eax+ecx]
			call StrToIntExW
			
			cmp eax, 0
			je argc_error
		
		start_listing:
			mov eax, [ebp+12] ; argv addr
			mov ebx, [ebp-12] ; directory offset
			
			cmp DWORD PTR[ebp-8], 0 ; GUI boolean
			je cli_mode
			
			push [ebp-4] ; depth
			push [eax+ebx] ; directory string
			call start_gui
			jmp stop_function
			
		cli_mode:
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
	
end start