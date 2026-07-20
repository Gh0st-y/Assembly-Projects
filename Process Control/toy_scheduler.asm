; tpy_scheduler.asm (x86-64)

; A minimal cooperative scheduler: two "tasks" (task_a, task_b) that
; take turns running by explicitly yielding control to each other via
; a hand-written switch_context routine. No kernel involvement at all -
; this is entirely a userspace simulation of what a real OS scheduler
; does when it context-switches between processes/threads.

; Core idea: a "context" is just a saved stack pointer. Because the 
; callee-saved registers (rbp, rbx, r12-r15) get pushed onto whichever
; stack is active before we swap rsp, that one saved pointer is enough
; to reconstruct an entire suspended execution state later.

STACK_SIZE equ 4096

section .bss
    align 16
    task_a_stack: resb STACK_SIZE
    align 16
    task_b_stack: resb STACK_SIZE

    main_ctx: resq 1            ; saved rsp for the original _start "task" (never resumed here)
    taskA_ctx: resq 1           ; saved rsp for task A
    taskB_ctx: resq 1           ; saved rsp for task B

section .data
    msg_a1 db "Task A: iteration 1", 0xA
    msg_a1_len equ $ - msg_a1
    msg_a2 db "Task A: iteration 2", 0xA
    msg_a2_len equ $ - msg_a2
    msg_a3 db "Task A: iteration 3", 0xA
    msg_a3_len equ $ - msg_a3

    msg_b1 db "Task B: iteration 1", 0xA
    msg_b1_len equ $ - msg_b1
    msg_b2 db "Task B: iteration 2", 0xA
    msg_b2_len equ $ - msg_b2
    msg_b3 db "Task B: iteration 3", 0xA
    msg_b3_len equ $ - msg_b3

    done_msg db "Both tasks finished -- scheduler exiting", 0xA
    done_len equ $ - done_msg

section .text
    global _start

; ------------------------------------------------------------------
; switch_context(old_ctx_ptr in rdi, new_ctx_ptr in rsi)

; Saves the CURRENT stack pointer (after pushing callee-saved regs)
; into [rdi], then loads a NEW stack pointer from [rsi] and restores
; ITS callee-saved regs. The final 'ret' then jumps to whatever 
; address is sitting on top of the newly-loaded stack, which is 
; either a previous caller of switch_context (a real resume point)
; or, the first time, out hand-built fake frame (see _start below)
; ------------------------------------------------------------------
switch_context:
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov [rdi], rsp              ; "save everything" = save the pointer to it all
    mov rsp, [rsi]              ; "load everything" = load a different pointer

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret                         ; jumps to whatever address is now on top of stack

; ------------------------------------------------------------------
_start: 
    ; --- Build task A's initial fake frame ---
    ; Layout switch_context expects when it pops+rets into a task
    ; for the very first time: 6 dummy qwords (matching the 6 pushes
    ; above) followed by the task's real entry address, which 'ret'
    ; will jump to as if it were a genuine return address.
    lea rax, [task_a_stack + STACK_SIZE]    ; top of task A's stack (grows down)
    sub rax, 56                             ; room for 6 dummy regs + entry addr
    mov qword [rax + 0], 0                  ; dummy r15
    mov qword [rax + 8], 0                  ; dummy r14
    mov qword [rax + 16], 0                 ; dummy r13
    mov qword [rax + 24], 0                 ; dummy r12
    mov qword [rax + 32], 0                 ; dummy rbx
    mov qword [rax + 40], 0                 ; dummy rbp
    mov qword [rax + 48], task_a_entry      ; fake "return address"
    mov [taskA_ctx], rax                    ; this IS task A's saved context

    ; --- Build task B's initial fake frame, same pattern ---
    lea rax, [task_b_stack + STACK_SIZE]
    sub rax, 56
    mov qword [rax + 0], 0
    mov qword [rax + 8], 0
    mov qword [rax + 16], 0
    mov qword [rax + 24], 0
    mov qword [rax + 32], 0
    mov qword [rax + 40], 0
    mov qword [rax + 48], task_b_entry
    mov [taskB_ctx], rax

    ; --- Kick things off: save _start's own context, switch into task A ---
    mov rdi, main_ctx
    mov rsi, taskA_ctx
    call switch_context

    ; Not reached in this design (task B ends the whole process below),
    ; kept only as a safety net in case control ever did return here.
    mov rax, 60
    xor rdi, rdi
    syscall

; ------------------------------------------------------------------
task_a_entry:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_a1
    mov rdx, msg_a1_len
    syscall

    mov rdi, taskA_ctx              ; yield: save my context here
    mov rsi, taskB_ctx              ; ...and resume task B from here
    call switch_context

    mov rax, 1
    mov rdi, 1
    mov rsi, msg_a2
    mov rdx, msg_a2_len
    syscall

    mov rdi, taskA_ctx
    mov rsi, taskB_ctx
    call switch_context

    mov rax, 1
    mov rdi, 1
    mov rsi, msg_a3
    mov rdx, msg_a3_len
    syscall

    mov rdi, taskA_ctx
    mov rsi, taskB_ctx
    call switch_context

    jmp $                           ; safety net: never actually reached

; ------------------------------------------------------------------
task_b_entry:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg_b1
    mov rdx, msg_b1_len
    syscall

    mov rdi, taskB_ctx
    mov rsi, taskA_ctx
    call switch_context

    mov rax, 1
    mov rdi, 1
    mov rsi, msg_b2
    mov rdx, msg_b2_len
    syscall

    mov rdi, taskB_ctx
    mov rsi, taskA_ctx
    call switch_context

    mov rax, 1
    mov rdi, 1
    mov rsi, msg_b3
    mov rdx, msg_b3_len
    syscall

    ; Task B ends the whole toy program after its final turn.
    mov rax, 1
    mov rdi, 1
    mov rsi, done_msg
    mov rdx, done_len
    syscall
 
    mov rax, 60
    xor rdi, rdi
    syscall