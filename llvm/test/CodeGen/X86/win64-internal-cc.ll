; RUN: llc -mtriple=x86_64-pc-windows-msvc -x86-internal-cc < %s | FileCheck %s
; RUN: llc -mtriple=x86_64-pc-windows-msvc -x86-internal-cc -x86-internal-cc-csr=sysv < %s | FileCheck %s --check-prefix=SYSV
; RUN: llc -mtriple=x86_64-pc-windows-msvc < %s | FileCheck %s --check-prefix=OFF

; llvm-pe: functions only called directly from their module take the internal
; call contract: no shadow space and six (or eight) argument registers.

declare void @ext(i64)

define internal fastcc i64 @sum7(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i64 %g) noinline {
  %1 = add i64 %a, %b
  %2 = add i64 %1, %c
  %3 = add i64 %2, %d
  %4 = add i64 %3, %e
  %5 = add i64 %4, %f
  %6 = add i64 %5, %g
  ret i64 %6
}

; CHECK-LABEL: sum7:
; CHECK-DAG: addq %r10,
; CHECK-DAG: addq %r11,
; CHECK-DAG: 8(%rsp)
; CHECK: retq
; SYSV-LABEL: sum7:
; SYSV-NOT: (%rsp)
; SYSV: retq
; OFF-LABEL: sum7:
; OFF: 40(%rsp)
; OFF: 48(%rsp)
; OFF: 56(%rsp)

define i64 @caller(i64 %x) nounwind {
  %r = call fastcc i64 @sum7(i64 %x, i64 2, i64 3, i64 4, i64 5, i64 6, i64 7)
  call void @ext(i64 %r)
  ret i64 %r
}

; The internal call needs no shadow space: one stack argument and the
; 32-byte home area for @ext only.
; CHECK-LABEL: caller:
; CHECK-DAG: movl $5, %r10d
; CHECK-DAG: movl $6, %r11d
; CHECK-DAG: movq $7, (%rsp)
; CHECK: callq sum7
; CHECK: callq ext
; SYSV-LABEL: caller:
; SYSV-DAG: movl $5, %r10d
; SYSV-DAG: movl $6, %r11d
; SYSV-DAG: movl $7, %esi
; SYSV: callq sum7
; OFF-LABEL: caller:
; OFF: movq $7, 48(%rsp)

; Address taken: stays Win64.
define internal i64 @taken(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e) noinline nounwind {
  %s = add i64 %a, %e
  ret i64 %s
}
@fp = global ptr @taken
; CHECK-LABEL: taken:
; CHECK: 40(%rsp)

; With an unwind table: stays Win64.
define internal i64 @unwound(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e) noinline uwtable {
  %s = add i64 %a, %e
  ret i64 %s
}
define i64 @call_unwound() nounwind {
  %r = call i64 @unwound(i64 1, i64 2, i64 3, i64 4, i64 5)
  ret i64 %r
}
; CHECK-LABEL: unwound:
; CHECK: 40(%rsp)

; A sibcall to Win64 code keeps the caller on Win64.
define internal i64 @wrapper(i64 %a) noinline nounwind {
  %r = tail call i64 @extret(i64 %a)
  ret i64 %r
}
declare i64 @extret(i64)
define i64 @call_wrapper(i64 %a) nounwind {
  %r = call i64 @wrapper(i64 %a)
  %s = add i64 %r, 1
  ret i64 %s
}
; CHECK-LABEL: wrapper:
; CHECK: jmp extret
