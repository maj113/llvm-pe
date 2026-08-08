; RUN: llc < %s -mtriple=x86_64-pc-windows-msvc -O2 | FileCheck %s

declare i32 @__CxxFrameHandler4(...)
declare void @may_throw()

define void @async_catch() personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %return unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr null, i32 64, ptr null]
  catchret from %cp to label %return

return:
  ret void
}

; /EHa clears the synchronous-exceptions-only (EHs) bit.
; CHECK: $cppxdata$async_catch:
; CHECK-NEXT: .byte 24{{.*}}# FuncInfo4Header

!llvm.module.flags = !{!0}
!0 = !{i32 2, !"eh-asynch", i32 1}
