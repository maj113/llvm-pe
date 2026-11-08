; RUN: llc -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s --check-prefix=DEFAULT
; RUN: llc -mtriple=x86_64-pc-windows-msvc -x86-function-alignment=1 < %s | FileCheck %s --check-prefix=ONE
; RUN: llc -mtriple=x86_64-pc-windows-msvc -x86-function-alignment=4 < %s | FileCheck %s --check-prefix=FOUR

; llvm-pe: -x86-function-alignment sets the preferred alignment of functions
; not optimised for size.

define void @f() {
; DEFAULT: .p2align 4
; DEFAULT-NEXT: f:
; ONE-NOT: .p2align
; ONE: f:
; FOUR: .p2align 2
; FOUR-NEXT: f:
  ret void
}
