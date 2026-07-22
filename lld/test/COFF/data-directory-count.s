# REQUIRES: x86

# RUN: split-file %s %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows %t/plain.s -o %t/plain.obj
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows %t/pdata.s -o %t/pdata.obj
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows %t/tls.s -o %t/tls.obj
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows %t/load.s -o %t/load.obj
# RUN: llvm-cvtres /machine:x64 /out:%t/resource.obj %p/Inputs/resource.res

# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /out:%t/none.exe %t/plain.obj
# RUN: llvm-readobj --file-headers %t/none.exe | FileCheck --check-prefix=NONE %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /out:%t/resource.exe %t/plain.obj %t/resource.obj
# RUN: llvm-readobj --file-headers --coff-resources %t/resource.exe \
# RUN:   | FileCheck --check-prefix=RESOURCE %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /export:main /out:%t/export.exe %t/plain.obj
# RUN: llvm-readobj --file-headers %t/export.exe | FileCheck --check-prefix=EXPORT %s
# RUN: lld-link /entry:main /driver /align:1 /filealign:1 \
# RUN:   /out:%t/reloc.exe %t/plain.obj
# RUN: llvm-readobj --file-headers %t/reloc.exe | FileCheck --check-prefix=RELOC %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /out:%t/pdata.exe %t/plain.obj %t/pdata.obj
# RUN: llvm-readobj --file-headers %t/pdata.exe | FileCheck --check-prefix=PDATA %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 /debug \
# RUN:   /out:%t/debug.exe %t/plain.obj
# RUN: llvm-readobj --file-headers %t/debug.exe | FileCheck --check-prefix=DEBUG %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /out:%t/tls.exe %t/plain.obj %t/tls.obj
# RUN: llvm-readobj --file-headers %t/tls.exe | FileCheck --check-prefix=TLS %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /out:%t/load.exe %t/plain.obj %t/load.obj
# RUN: llvm-readobj --file-headers %t/load.exe | FileCheck --check-prefix=LOAD %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /guard:cf /include:ExitProcess \
# RUN:   /out:%t/iat.exe %t/plain.obj %t/load.obj \
# RUN:   %p/Inputs/std64.lib
# RUN: llvm-readobj --file-headers %t/iat.exe | FileCheck --check-prefix=IAT %s
# RUN: lld-link /entry:main /fixed /driver /align:1 /filealign:1 \
# RUN:   /delayload:std64.dll /include:ExitProcess \
# RUN:   /alternatename:__delayLoadHelper2=main /out:%t/delay.exe \
# RUN:   %t/plain.obj %p/Inputs/std64.lib
# RUN: llvm-readobj --file-headers %t/delay.exe \
# RUN:   | FileCheck --check-prefix=DELAY %s

# NONE:   NumberOfRvaAndSize: 0
# RESOURCE: NumberOfRvaAndSize: 3
# RESOURCE: ResourceTableRVA: 0x{{[1-9A-F][0-9A-F]*}}
# RESOURCE: Total Number of Resources: 1
# EXPORT: NumberOfRvaAndSize: 1
# PDATA:  NumberOfRvaAndSize: 4
# RELOC:  NumberOfRvaAndSize: 6
# DEBUG:  NumberOfRvaAndSize: 7
# TLS:    NumberOfRvaAndSize: 10
# LOAD:   NumberOfRvaAndSize: 11
# IAT:    NumberOfRvaAndSize: 13
# DELAY:  NumberOfRvaAndSize: 14

#--- plain.s
.text
.globl main
main:
  retq

#--- pdata.s
.section .pdata,"dr"
.long 0
.long 0
.long 0

#--- tls.s
.data
.globl _tls_used
_tls_used:
  .zero 40

#--- load.s
.data
.globl _load_config_used
_load_config_used:
  .zero 256
