; fork_exec.asm (x86-64)
; Parent forks a child; the child replaces itself with /bin/echo via execve.
; The parent waits for the child to finish, then prints its own message.
; This is the exact pattern a shell uses to launch every command you type.

section .data
    path            db "/bin/echo", 0
    arg1            db "hello-from-execve", 0

    parent_msg      db "parent: child finished, I'm still me", 0xA
    parent_len      equ $ - parent_msg

    exec_fail_msg   db "child: execve failed", 0xA
    exec_fail_len   equ $ - exec_fail_msg

    fork_fail_msg   db "fork() failed", 0xA
    fork_fail_len   equ $ - fork_fail_msg

section .bss
    ; argv and envp are arrays of 8-byte pointers, null-terminated.
    ; We build them at runtime into these reserved slots instead of
    ; trying to lay them out as static data (simpler to read/reason about).
    argv            resq 3          ; argv[0], argv[1], argv[2]=NULL
    envp            resq 1          ; envp[0]=NULL (empty environment)
    status          resq 1          ; scratch space for wait4()'s status output

section .text
    global _start

_start:
    mov rax, 57                     ; fork
    syscall

    cmp rax, 0
    je .child                       ; rax == 0 -> child
    jg .parent                      ; rax > 0 -> parent (rax = child pid), fall through path
    jmp .fork_error

; --------------------------------------------------------------------------------
.child:
    ; Build argv = { path, arg1, NULL }
    mov qword [argv],       path
    mov qword [argv + 8],   arg1
    mov qword [argv + 16],  0

    ; Build envp = { NULL } (empty environment)
    mov qword [envp], 0

    mov rax, 59                     ; execve
    mov rdi, path
    mov rsi, argv
    mov rdx, envp
    syscall

    ; If we ever reach this line, execve FAILED - a successful execve
    ; never returns here, because this whole program image is gone
    mov rax, 1
    mov rdi, 2                      ; stderr
    mov rsi, exec_fail_msg
    mov rdx, exec_fail_len
    syscall

    mov rax, 60
    mov rdi, 1
    syscall                  

; --------------------------------------------------------------------------------
.parent:
    ; rax currently holds the child's PID from the fork() call above
    mov rdi, rax                    ; wait4's 1st arg: pid to wait for
    mov rax, 61                     ; wait4
    mov rsi, status                 ; where to store exit status
    mov rdx, 0                      ; options = 0
    mov r10, 0                      ; rusage = NULL
    syscall

    mov rax, 1
    mov rdi, 1
    mov rsi, parent_msg
    mov rdx, parent_len
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall

; --------------------------------------------------------------------------------
.fork_error:
    mov rax, 1
    mov rdi, 2
    mov rsi, fork_fail_msg
    mov rdx, fork_fail_len
    syscall
 
    mov rax, 60
    mov rdi, 1
    syscall 