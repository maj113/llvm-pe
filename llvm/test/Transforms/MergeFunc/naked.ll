; RUN: opt -passes=mergefunc -S < %s | FileCheck %s

; A naked function cannot be replaced with a generated thunk: the thunk reads
; its formal arguments in IR, which is invalid for functions with the naked
; attribute. Leave naked functions untouched.

@llvm.used = appending global [2 x ptr] [ptr @naked_a, ptr @naked_b], section "llvm.metadata"

define internal i32 @naked_a(ptr %a, ptr %b) naked {
; CHECK-LABEL: define internal i32 @naked_a(
; CHECK-SAME: ptr %a, ptr %b) #[[NAKED:[0-9]+]] {
; CHECK-NEXT:    call void asm sideeffect "nop", ""()
; CHECK-NEXT:    unreachable
  call void asm sideeffect "nop", ""()
  unreachable
}

define internal i32 @naked_b(ptr %a, ptr %b) naked {
; CHECK-LABEL: define internal i32 @naked_b(
; CHECK-SAME: ptr %a, ptr %b) #[[NAKED]] {
; CHECK-NEXT:    call void asm sideeffect "nop", ""()
; CHECK-NEXT:    unreachable
  call void asm sideeffect "nop", ""()
  unreachable
}

; CHECK: attributes #[[NAKED]] = { naked }
