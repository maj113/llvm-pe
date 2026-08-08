// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -fcxx-exceptions \
// RUN:   -fexceptions -fms-cxx-eh4 -emit-llvm -o - %s | FileCheck %s --check-prefix=FH4
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -fcxx-exceptions \
// RUN:   -fexceptions -fms-cxx-eh4 -fno-ms-cxx-eh4 -emit-llvm -o - %s | FileCheck %s --check-prefix=FH3
// RUN: %clang_cc1 -triple i686-pc-windows-msvc -fcxx-exceptions \
// RUN:   -fexceptions -fms-cxx-eh4 -emit-llvm -o - %s | FileCheck %s --check-prefix=FH3
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -fcxx-exceptions \
// RUN:   -fexceptions -fms-cxx-eh4 -O2 -S -o - %s | FileCheck %s --check-prefix=ASM
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -fcxx-exceptions \
// RUN:   -fexceptions -fms-cxx-eh4 -O0 -S -o - %s | FileCheck %s --check-prefix=STACK

extern void may_throw();
extern int may_throw_value(int);
extern int cannot_throw_value(int) noexcept;

void use_exception() {
  try {
    may_throw();
  } catch (...) {
  }
}

void pure_noexcept() noexcept { may_throw(); }
void empty_noexcept() noexcept {}

int noexcept_to_throwing(int x) noexcept { return may_throw_value(x); }
int noexcept_to_nothrow(int x) noexcept { return cannot_throw_value(x); }
int mixed_noexcept(int x) noexcept {
  if (x)
    may_throw();
  return cannot_throw_value(x);
}
int musttail_noexcept(int x) noexcept {
  [[clang::musttail]] return cannot_throw_value(x);
}

struct CleanupObject {
  ~CleanupObject();
};

void distinct_cleanup_slots() {
  try {
    may_throw();
  } catch (...) {
    CleanupObject outer;
    try {
      CleanupObject inner;
      may_throw();
    } catch (...) {
    }
  }
}

// FH4: personality ptr @__CxxFrameHandler4
// FH4: declare{{.*}} i32 @__CxxFrameHandler4(...)
// FH4-LABEL: define{{.*}} void @"?pure_noexcept@@YAXXZ"
// FH4-SAME: () #[[NOEXCEPT:[0-9]+]] personality ptr @__CxxFrameHandler4
// FH4: notail call void @"?may_throw@@YAXXZ"()
// FH4-NOT: __std_terminate
// FH4-LABEL: define{{.*}} void @"?empty_noexcept@@YAXXZ"()
// FH4-NOT: personality
// FH4-NEXT: entry:
// FH4-LABEL: define{{.*}} i32 @"?musttail_noexcept@@YAHH@Z"
// FH4: musttail call{{.*}} @"?cannot_throw_value@@YAHH@Z"
// FH4-NEXT: ret i32
// FH4: attributes #[[NOEXCEPT]] = { {{.*}}nounwind
// FH3: personality ptr @__CxxFrameHandler3
// FH3: declare{{.*}} i32 @__CxxFrameHandler3(...)

// A throwing callee needs the caller's FH4 frame to remain live, whereas a
// noexcept callee can enforce the contract after a tail call itself.
// ASM-LABEL: "?noexcept_to_throwing@@YAHH@Z":
// ASM: .seh_handler __CxxFrameHandler4, @unwind, @except
// ASM: callq "?may_throw_value@@YAHH@Z"
// ASM: "$cppxdata$?noexcept_to_throwing@@YAHH@Z":
// ASM-NEXT: .byte 96{{.*}}# FuncInfo4Header
// ASM-LABEL: "?noexcept_to_nothrow@@YAHH@Z":
// ASM-NOT: .seh_handler
// ASM: jmp "?cannot_throw_value@@YAHH@Z"{{.*}}# TAILCALL
// ASM-LABEL: "?mixed_noexcept@@YAHH@Z":
// ASM: .seh_handler __CxxFrameHandler4, @unwind, @except
// ASM: callq "?may_throw@@YAXXZ"
// ASM: jmp "?cannot_throw_value@@YAHH@Z"{{.*}}# TAILCALL

// Direct FH4 cleanup objects are ordinary stack objects, not fixed catch
// objects. In particular, simultaneously-live objects must not alias at -O0.
// STACK-LABEL: "$stateUnwindMap$catch$1$?distinct_cleanup_slots@@YAXXZ":
// STACK: .long "??1CleanupObject@@QEAA@XZ"@IMGREL # UnwindAction
// STACK-NEXT: .byte 78{{.*}}# UnwindObject
// STACK: .long "??1CleanupObject@@QEAA@XZ"@IMGREL # UnwindAction
// STACK-NEXT: .byte 76{{.*}}# UnwindObject
