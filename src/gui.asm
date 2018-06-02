.DATA
StartGUI db "Starting GUI...",10, 0

.CODE
start_gui PROC
	push ebp
	mov ebp, esp

	push offset StartGUI
	call crt_printf
	add esp, 4
	
	

	leave
	ret 8
start_gui ENDP