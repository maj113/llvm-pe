# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-windows %s -o %t.obj
# RUN: lld-link /entry:entry /subsystem:console /fixed /align:1 /filealign:1 \
# RUN:   /opt:noref,noicf,lldbranchrelax %t.obj /out:%t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s --check-prefix=RELAX
# RUN: lld-link /entry:entry /subsystem:console /fixed /align:1 /filealign:1 \
# RUN:   /opt:noref,noicf,nolldbranchrelax %t.obj /out:%t.no.exe
# RUN: llvm-objdump -d %t.no.exe | FileCheck %s --check-prefix=NO-RELAX
# RUN: not lld-link /entry:entry /subsystem:console /debug \
# RUN:   /opt:noref,noicf,lldbranchrelax %t.obj /out:%t.debug.exe 2>&1 | \
# RUN:   FileCheck %s --check-prefix=DEBUG

# RELAX:      {{[0-9a-f]+}}: c3                           retq
# RELAX:      {{[0-9a-f]+}}: b8 11 22 33 44               movl
# RELAX-NEXT: {{[0-9a-f]+}}: eb 01                        jmp
# RELAX-NEXT: {{[0-9a-f]+}}: 90                           nop
# RELAX-NEXT: {{[0-9a-f]+}}: c3                           retq
# RELAX:      {{[0-9a-f]+}}: e8 {{[0-9a-f ]+}}            callq
# RELAX:      {{[0-9a-f]+}}: b8 55 66 77 88               movl
# RELAX-NEXT: {{[0-9a-f]+}}: e9 {{[0-9a-f ]+}}            jmp
# NO-RELAX:   {{[0-9a-f]+}}: b8 11 22 33 44               movl
# NO-RELAX-NEXT: {{[0-9a-f]+}}: e9 {{[0-9a-f ]+}}         jmp
# DEBUG: /opt:lldbranchrelax is incompatible with debug, hotpatch, or explicit
# DEBUG-SAME: function ordering

        .section .text,"xr",one_only,tail_source
        .globl tail_source
tail_source:
        jmp tail_target

        .section .text,"xr",one_only,tail_target
        .globl tail_target
tail_target:
        retq

        .section .text,"xr",one_only,interior_jump
        .globl interior_jump
interior_jump:
        movl $0x44332211, %eax
        jmp interior_target

        .section .text,"xr",one_only,near_target
        .globl near_target
near_target:
        nop
        .globl interior_target
interior_target:
        retq

        .section .text,"xr",one_only,target
        .globl target
target:
        movl $1, %eax
        retq

        .section .text,"xr",one_only,call_source
        .globl call_source
call_source:
        callq target
        retq

        .section .text,"xr",one_only,far_target
        .globl far_target
far_target:
        .fill 65, 1, 0x90
        retq

        .section .text,"xr",one_only,padding
        .globl padding
padding:
        .fill 200, 1, 0x90

        .section .text,"xr",one_only,far_jump
        .globl far_jump
far_jump:
        .fill 65, 1, 0x90
        movl $0x88776655, %eax
        jmp far_target

        .section .text,"xr",one_only,entry
        .globl entry
entry:
        callq tail_source
        callq interior_jump
        callq call_source
        callq far_jump
        retq
