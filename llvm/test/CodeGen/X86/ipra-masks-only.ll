; RUN: llc -mtriple=x86_64-pc-windows-msvc -enable-ipra < %s | FileCheck %s --check-prefix=NOCSR
; RUN: llc -mtriple=x86_64-pc-windows-msvc -enable-ipra -x86-ipra-nocsr=false < %s | FileCheck %s --check-prefix=MASKS

; llvm-pe: -x86-ipra-nocsr=false keeps IPRA to register masks: the callee
; still saves its callee-saved registers, and the caller still keeps a value
; in a scratch register the callee leaves alone across the call.

define internal void @callee() noinline nounwind norecurse {
  call void asm sideeffect "", "~{rsi}"()
  ret void
}

define i64 @caller(i64 %a, i64 %b) nounwind {
  %s = add i64 %a, %b
  call void @callee()
  %t = mul i64 %s, %a
  ret i64 %t
}

; NOCSR-LABEL: callee:
; NOCSR-NOT: pushq %rsi
; NOCSR: retq
; MASKS-LABEL: callee:
; MASKS: pushq %rsi
; MASKS: popq %rsi

; MASKS-LABEL: caller:
; MASKS-NOT: pushq
; MASKS-NOT: (%rsp)
; MASKS: callq callee
; MASKS: imulq %rcx,
