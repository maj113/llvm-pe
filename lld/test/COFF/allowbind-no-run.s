# REQUIRES: x86, system-windows

# RUN: split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows %t/dll.s -o %t/dll.obj
# RUN: lld-link /dll /noentry /export:imported /out:%t/test.dll \
# RUN:   /implib:%t/test.lib %t/dll.obj
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows %t/exe.s -o %t/exe.obj
# RUN: lld-link /entry:main /subsystem:console /allowbind:no \
# RUN:   /out:%t/test.exe %t/exe.obj %t/test.lib
# RUN: llvm-readobj --coff-imports %t/test.exe \
# RUN:   | FileCheck --check-prefix=IMPORT %s
# RUN: %t/test.exe

# IMPORT:      Import {
# IMPORT-NEXT:   Name: test
# IMPORT-NEXT:   ImportLookupTableRVA: 0x0
# IMPORT-NEXT:   ImportAddressTableRVA: 0x{{[0-9A-F]+}}
# IMPORT-NEXT:   Symbol: imported (0)
# IMPORT-NEXT: }

#--- dll.s
.text
.globl imported
imported:
  xorl %eax, %eax
  retq

#--- exe.s
.text
.globl main
main:
  subq $40, %rsp
  callq imported
  addq $40, %rsp
  retq
