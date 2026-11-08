; RUN: llc -mtriple=x86_64-pc-windows-msvc -mattr=+avx -enable-ipra < %s | FileCheck %s

; llvm-pe: VZEROUPPER defines YMM0-15 but keeps XMM0-15, so a callee whose
; only use of them is a vzeroupper does not clobber the caller's XMM values.

define internal void @callee(ptr %p) noinline nounwind {
  %v = load <8 x float>, ptr %p
  %w = fadd <8 x float> %v, %v
  store <8 x float> %w, ptr %p
  ret void
}

define float @caller(ptr %p, float %x) nounwind {
  %y = fmul float %x, %x
  call void @callee(ptr %p)
  %z = fadd float %y, %x
  ret float %z
}

; CHECK-LABEL: caller:
; CHECK-NOT: (%rsp)
; CHECK-NOT: %xmm6
; CHECK: callq callee
; CHECK-NOT: (%rsp)
; CHECK: retq
