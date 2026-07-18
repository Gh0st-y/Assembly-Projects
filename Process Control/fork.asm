; fork.asm (x86-64)
; Calls fork() directly via the syscall instructions and demonstrates
; that execution continues in Both the parent and the child, distinguished
; only by the return value in rax

section .data
    parent_msg db "I am the parent", 0xA
    parent_len equ $ - parent_msg

    child_msg db "I am the child", 0xA
    child_len equ $ - child_msg 

    error_msg db "fork() failed", 0xA
    error_len equ $ - error_msg

section .text
    global _start

_start:
    mov rax, 57                 ; syscall number for fork (x86-64 table)
    syscall                     ; trap into the kernel - this ONE call returns TWICE

; --- both parent and child resume execution here ---

    cmp rax, 0
    je .child                   ; rax == 0      -> we are the child
    jg .parent                  ; rax > 0       -> we are the parent
    jmp .error                  ; rax < 0       -> fork failed

.parent:
    mov rax, 1                  ; syscall: write
    mov rdi, 1                  ; fd 1 = stdout
    mov rsi, parent_msg
    mov rdx, parent_len
    syscall

    mov rax, 60                 ; syscall: exit
    xor rdi, rdi                ; exit code 0
    syscall

.child:
    mov rax, 1
    mov rdi, 1
    mov rsi, child_msg
    mov rdx, child_len
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall

.error:
    mov rax, 1
mov rdi, 2                      ; fd 2 = stderr (this is an error, after all)
    mov rsi, error_msg
    mov rdx, error_len
    syscall

    mov rax, 60
    xor rdi, 1                  ; exit code 1 to signal failure
    syscall