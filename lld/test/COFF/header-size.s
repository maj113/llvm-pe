// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-windows %s -o %t.obj
// RUN: lld-link -entry:main -subsystem:console %t.obj -out:%t.exe
// RUN: llvm-readobj --sections %t.exe | FileCheck %s
// RUN: lld-link -entry:main -subsystem:console %t.obj -out:%t.flat.exe \
// RUN:   /fixed /align:1 /filealign:1 /driver
// RUN: llvm-readobj --file-headers --sections %t.flat.exe \
// RUN:   | FileCheck --check-prefix=FLAT %s
// RUN: wc -c < %t.flat.exe | FileCheck --check-prefix=FLAT-SIZE %s
    .globl main
main:
    ret

// Check that the first section data comes at 512 bytes in the file.
// If the size allocated for headers would include size for section
// headers which aren't written, PointerToRawData would be 0x400 instead.
// CHECK: PointerToRawData: 0x200

// A fixed image cannot populate .reloc later. Its removal must happen before
// address assignment so no unused section-header gap precedes .text.
// FLAT:      SizeOfHeaders: 336
// FLAT:      Name: .text
// FLAT:      PointerToRawData: 0x150
// FLAT-SIZE: 384
