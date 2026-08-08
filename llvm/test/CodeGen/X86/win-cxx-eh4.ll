; RUN: llc < %s -mtriple=x86_64-pc-windows-msvc -O2 | FileCheck %s --check-prefix=ASM
; RUN: llc < %s -mtriple=x86_64-pc-windows-msvc -O2 -filetype=obj -o %t
; RUN: llvm-readobj --unwind %t | FileCheck %s --check-prefix=UNWIND
; RUN: llvm-readobj --symbols %t | FileCheck %s --check-prefix=OBJ

@type_info = external global i8

declare i32 @__CxxFrameHandler4(...)
declare void @may_throw()
declare void @destroy(ptr) nounwind
declare void @cleanup_a()
declare void @cleanup_b()

define void @pure_noexcept() nounwind uwtable personality ptr @__CxxFrameHandler4 {
entry:
  call void @may_throw()
  ret void
}

; FH4's NoExcept bit enforces noexcept without an explicit terminate funclet,
; even when the function otherwise has no EH pads.
; ASM-LABEL: pure_noexcept:
; ASM: .seh_handler __CxxFrameHandler4, @unwind, @except
; ASM-NOT: __std_terminate
; ASM: $cppxdata$pure_noexcept:
; ASM-NEXT: .byte 96{{.*}}# FuncInfo4Header

define void @noexcept_catch() nounwind personality ptr @__CxxFrameHandler4 {
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

; NoExcept combines with EHs and the two map bits in the parent record.
; ASM: $cppxdata$noexcept_catch:
; ASM-NEXT: .byte 120{{.*}}# FuncInfo4Header
; It also forces a catch record so an exception escaping the funclet terminates.
; ASM: $cppxdata$catch$
; ASM-NEXT: .byte 105{{.*}}# FuncInfo4Header

define void @sibling_cleanup_isolation() personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %return unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch.a, label %catch.b]
        unwind to caller

catch.a:
  %cp.a = catchpad within %cs [ptr @type_info, i32 0, ptr null]
  invoke void @may_throw() [ "funclet"(token %cp.a) ]
          to label %a.unreachable unwind label %cleanup.a

a.unreachable:
  unreachable

cleanup.a:
  %cl.a = cleanuppad within %cp.a []
  call void @cleanup_a() [ "funclet"(token %cl.a) ]
  cleanupret from %cl.a unwind to caller

catch.b:
  %cp.b = catchpad within %cs [ptr null, i32 64, ptr null]
  invoke void @may_throw() [ "funclet"(token %cp.b) ]
          to label %b.unreachable unwind label %cleanup.b

b.unreachable:
  unreachable

cleanup.b:
  %cl.b = cleanuppad within %cp.b []
  call void @cleanup_b() [ "funclet"(token %cl.b) ]
  cleanupret from %cl.b unwind to caller

return:
  ret void
}

; Every catch record shares the function's global state numbering, but only
; actions owned by that catch may appear in its unwind map. In particular, a
; sibling's cleanup must remain a no-op hole rather than leaking across records.
; ASM: $stateUnwindMap$catch$2$sibling_cleanup_isolation:
; ASM-NOT: "?dtor$7@?0?sibling_cleanup_isolation@4HA"@IMGREL
; ASM: "?dtor$4@?0?sibling_cleanup_isolation@4HA"@IMGREL
; ASM: $cppxdata$catch$2$sibling_cleanup_isolation:
; ASM: $stateUnwindMap$catch$5$sibling_cleanup_isolation:
; ASM-NOT: "?dtor$4@?0?sibling_cleanup_isolation@4HA"@IMGREL
; ASM: "?dtor$7@?0?sibling_cleanup_isolation@4HA"@IMGREL
; ASM: $cppxdata$catch$5$sibling_cleanup_isolation:

define void @simple_catch() personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %return unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr @type_info, i32 0, ptr null]
  catchret from %cp to label %return

return:
  ret void
}

; The parent has the FH4 personality, but an otherwise-simple catch funclet
; does not need a second personality record. Its catchret returns continuation
; index zero rather than a code address.
; ASM-LABEL: simple_catch:
; ASM: .seh_handler __CxxFrameHandler4, @unwind, @except
; ASM-LABEL: "?catch$2@?0?simple_catch@4HA":
; ASM-NOT: .seh_handler
; ASM: xorl %eax, %eax
; ASM: retq{{.*}}# CATCHRET
; ASM: .seh_endproc
; ASM: $handlerMap$0$simple_catch:
; ASM: .byte 18{{.*}}# HandlerTypeHeader
; ASM: $cppxdata$simple_catch:
; ASM: .byte 56{{.*}}# FuncInfo4Header

; UNWIND-LABEL: StartAddress: simple_catch
; UNWIND: Handler: __CxxFrameHandler4
; UNWIND-LABEL: StartAddress: ?catch$2@?0?simple_catch@4HA
; UNWIND: Flags [ (0x0)
; UNWIND: UnwindCodes [
; UNWIND: ]
; UNWIND-NEXT: }

; Object emission must relax the IP-map expression to one byte. Together with
; the one-byte count and state, the following handler map starts three bytes
; after the IP map rather than after the textual assembly's five-byte fallback.
; OBJ: Name: $ip2state$simple_catch
; OBJ-NEXT: Value: [[#%u,IPMAP:]]
; OBJ: Name: $handlerMap$0$simple_catch
; OBJ-NEXT: Value: [[#IPMAP + 3]]

define i32 @two_continuations(i1 %which) personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %normal unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr null, i32 64, ptr null]
  br i1 %which, label %catch.zero, label %catch.one

catch.zero:
  catchret from %cp to label %return.zero

catch.one:
  catchret from %cp to label %return.one

normal:
  ret i32 2

return.zero:
  ret i32 0

return.one:
  ret i32 1
}

; FH4 stores at most two continuation targets and catchret returns their
; zero-based index. Use-list order is intentionally not prescribed, so check
; for both return values and both encoded targets without assigning paths.
; ASM-LABEL: "?catch$3@?0?two_continuations@4HA":
; ASM: movl $1, %eax
; ASM: retq{{.*}}# CATCHRET
; ASM: xorl %eax, %eax
; ASM: retq{{.*}}# CATCHRET
; ASM: $handlerMap$0$two_continuations:
; ASM: .byte 33{{.*}}# HandlerTypeHeader
; ASM: # Continuation
; ASM: # Continuation

; UNWIND-LABEL: StartAddress: ?catch$3@?0?two_continuations@4HA
; UNWIND: Flags [ (0x0)
; UNWIND: UnwindCodes [
; UNWIND: ]
; UNWIND-NEXT: }

define i32 @three_continuations(i32 %which)
    personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %normal unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch] unwind to caller

catch:
  %cp = catchpad within %cs [ptr null, i32 64, ptr null]
  switch i32 %which, label %catch.two [
    i32 0, label %catch.zero
    i32 1, label %catch.one
  ]

catch.zero:
  catchret from %cp to label %return.zero

catch.one:
  catchret from %cp to label %return.one

catch.two:
  catchret from %cp to label %return.two

normal:
  ret i32 3

return.zero:
  ret i32 0

return.one:
  ret i32 1

return.two:
  ret i32 2
}

; A handler with more than two continuations uses the ABI's address-return
; form: the handler map has no continuation entries and each catchret returns
; its destination address instead of an index.
; ASM-LABEL: three_continuations:
; ASM-LABEL: "?catch$3@?0?three_continuations@4HA":
; ASM: leaq {{.*}}(%rip), %rax
; ASM: retq{{.*}}# CATCHRET
; ASM: leaq {{.*}}(%rip), %rax
; ASM: retq{{.*}}# CATCHRET
; ASM: leaq {{.*}}(%rip), %rax
; ASM: retq{{.*}}# CATCHRET
; ASM: $handlerMap$0$three_continuations:
; ASM: .byte 1{{.*}}# HandlerTypeHeader
; ASM-NOT: # Continuation
; ASM: $tryMap$three_continuations:

define i32 @two_handlers_shared_continuations(i1 %which)
    personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %normal unwind label %catch.dispatch

catch.dispatch:
  %cs = catchswitch within none [label %catch.a, label %catch.b]
        unwind to caller

catch.a:
  %cp.a = catchpad within %cs [ptr @type_info, i32 0, ptr null]
  br i1 %which, label %a.zero, label %a.one

a.zero:
  catchret from %cp.a to label %return.zero

a.one:
  catchret from %cp.a to label %return.one

catch.b:
  %cp.b = catchpad within %cs [ptr null, i32 64, ptr null]
  br i1 %which, label %b.one, label %b.zero

b.one:
  catchret from %cp.b to label %return.one

b.zero:
  catchret from %cp.b to label %return.zero

normal:
  ret i32 2

return.zero:
  ret i32 0

return.one:
  ret i32 1
}

; Both catches share both destinations, but their metadata stores the targets
; in opposite orders. Catchret lookup must use the current catch funclet, not
; merely the parent try and destination.
; ASM-LABEL: "?catch$3@?0?two_handlers_shared_continuations@4HA":
; ASM: # %a.zero
; ASM-NEXT: movl $1, %eax
; ASM: # %a.one
; ASM-NEXT: xorl %eax, %eax
; ASM-LABEL: "?catch$6@?0?two_handlers_shared_continuations@4HA":
; ASM: # %b.one
; ASM-NEXT: movl $1, %eax
; ASM: # %b.zero
; ASM-NEXT: xorl %eax, %eax

define void @direct_object_cleanup() personality ptr @__CxxFrameHandler4 {
entry:
  %object = alloca i8, align 1
  invoke void @may_throw()
          to label %normal unwind label %cleanup

normal:
  call void @destroy(ptr %object)
  ret void

cleanup:
  %cp = cleanuppad within none []
  call void @destroy(ptr %object) [ "funclet"(token %cp) ]
  cleanupret from %cp unwind to caller
}

; A one-call destructor cleanup is represented directly in FH4 xdata (type 1)
; and its outlined cleanup funclet is removed.
; ASM-LABEL: direct_object_cleanup:
; ASM-NOT: ?dtor$
; ASM: $stateUnwindMap$direct_object_cleanup:
; ASM: .long {{.*}}+1
; ASM-NEXT: .long destroy@IMGREL{{.*}}# UnwindAction
; ASM: $cppxdata$direct_object_cleanup:
; ASM: .byte 40{{.*}}# FuncInfo4Header

define void @direct_pointer_cleanup(ptr %object) personality ptr @__CxxFrameHandler4 {
entry:
  %slot = alloca ptr, align 8
  store ptr %object, ptr %slot, align 8
  invoke void @may_throw()
          to label %normal unwind label %cleanup

normal:
  call void @destroy(ptr %object)
  ret void

cleanup:
  %cp = cleanuppad within none []
  %loaded = load ptr, ptr %slot, align 8
  call void @destroy(ptr %loaded) [ "funclet"(token %cp) ]
  cleanupret from %cp unwind to caller
}

; Loading the destructor argument from a parent-frame pointer slot selects the
; FH4 type-2 direct cleanup form.
; ASM-LABEL: direct_pointer_cleanup:
; ASM-NOT: ?dtor$
; ASM: $stateUnwindMap$direct_pointer_cleanup:
; ASM: .long {{.*}}+2
; ASM-NEXT: .long destroy@IMGREL{{.*}}# UnwindAction

define void @branched_cleanup() personality ptr @__CxxFrameHandler4 {
entry:
  %object = alloca i8, align 1
  invoke void @may_throw()
          to label %normal unwind label %cleanup

normal:
  call void @destroy(ptr %object)
  ret void

cleanup:
  %cp = cleanuppad within none []
  call void @destroy(ptr %object) [ "funclet"(token %cp) ]
  br label %cleanup.more

cleanup.more:
  call void @destroy(ptr %object) [ "funclet"(token %cp) ]
  cleanupret from %cp unwind to caller
}

; A multi-block cleanup cannot use a direct destructor encoding even when its
; entry block superficially contains one suitable call.
; ASM-LABEL: branched_cleanup:
; ASM: "?dtor$
; ASM: $stateUnwindMap$branched_cleanup:
; ASM: .long "?dtor${{.*}}@IMGREL{{.*}}# UnwindAction

define i32 @nested_catch_continuation() personality ptr @__CxxFrameHandler4 {
entry:
  invoke void @may_throw()
          to label %normal unwind label %outer.dispatch

outer.dispatch:
  %outer.cs = catchswitch within none [label %outer.catch]
              unwind to caller

outer.catch:
  %outer.cp = catchpad within %outer.cs [ptr null, i32 64, ptr null]
  invoke void @may_throw() [ "funclet"(token %outer.cp) ]
          to label %outer.return unwind label %inner.dispatch

inner.dispatch:
  %inner.cs = catchswitch within %outer.cp [label %inner.catch]
              unwind to caller

inner.catch:
  %inner.cp = catchpad within %inner.cs [ptr null, i32 64, ptr null]
  catchret from %inner.cp to label %outer.return

outer.return:
  catchret from %outer.cp to label %done

normal:
  br label %done

done:
  %result = phi i32 [ 0, %normal ], [ 1, %outer.return ]
  ret i32 %result
}

; The outer catch contains a nested try, so its catchret block need not remain
; adjacent to the outer funclet entry after layout. Continuation lookup must be
; tied to finalized EH-scope membership rather than inferred from layout.
; ASM-LABEL: nested_catch_continuation:
; ASM: xorl %eax, %eax
; ASM: retq{{.*}}# CATCHRET
; ASM: xorl %eax, %eax
; ASM: retq{{.*}}# CATCHRET
; ASM: $cppxdata$catch$
