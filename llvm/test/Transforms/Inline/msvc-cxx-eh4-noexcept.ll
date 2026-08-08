; RUN: opt -passes="always-inline" -pass-remarks=inline \
; RUN:   -pass-remarks-missed=inline -S < %s 2>&1 \
; RUN:   | FileCheck %s --implicit-check-not="remark: "

; CHECK-DAG: remark: {{.*}} 'contract' is not inlined into 'unmarked_caller': incompatible Microsoft C++ EH4 noexcept
; CHECK-DAG: remark: {{.*}} 'contract' inlined into 'marked_caller' with (cost=always): always inline attribute

declare i32 @__CxxFrameHandler4(...)
declare void @may_throw()

define internal void @contract() #0 personality ptr @__CxxFrameHandler4 {
entry:
  call void @may_throw()
  ret void
}

define void @unmarked_caller() {
entry:
  ; CHECK-LABEL: define void @unmarked_caller()
  ; CHECK: call void @contract()
  call void @contract()
  ret void
}

define void @marked_caller() #1 personality ptr @__CxxFrameHandler4 {
entry:
  ; CHECK-LABEL: define void @marked_caller()
  ; CHECK-NOT: call void @contract()
  ; CHECK: call void @may_throw() #[[NOUNWIND:[0-9]+]]
  call void @contract()
  ret void
}

; CHECK: attributes #[[NOUNWIND]] = { nounwind }

attributes #0 = { alwaysinline nounwind "msvc-cxx-eh4-noexcept" }
attributes #1 = { nounwind "msvc-cxx-eh4-noexcept" }
