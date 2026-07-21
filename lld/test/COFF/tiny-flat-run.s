# REQUIRES: x86, system-windows

# RUN: llvm-mc -filetype=obj -triple=x86_64-windows %s -o %t.obj
# RUN: lld-link /entry:main /subsystem:console /fixed /driver \
# RUN:   /align:1 /filealign:1 /out:%t.exe %t.obj
# RUN: %t.exe

.text
.globl main
main:
  xorl %eax, %eax
  retq
