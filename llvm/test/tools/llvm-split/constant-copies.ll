; Partitions that read a constant global owned by another partition get an
; available_externally copy of it, so that codegen can fold reads of the
; initializer. Only the owning partition defines the global.

; REQUIRES: x86-registered-target

; RUN: llvm-split -j=2 -o %t %s
; RUN: llvm-dis -o - %t0 | FileCheck --check-prefix=CHECK0 %s
; RUN: llvm-dis -o - %t1 | FileCheck --check-prefix=CHECK1 --implicit-check-not=comdat %s
; RUN: llc -o - %t0 \
; RUN:   | FileCheck --check-prefix=ASM0 --implicit-check-not=local_str: %s
; RUN: llc -o - %t1 | FileCheck --check-prefix=ASM1 \
; RUN:   --implicit-check-not='{{^}}str:' --implicit-check-not='{{^}}cd:' %s

target triple = "x86_64-pc-windows-msvc"

$cd = comdat any

; Plain-data constants are copied into the partitions that read them.
; CHECK0: @str = unnamed_addr constant [14 x i8] c",\22session_id\22:", align 1
; CHECK1: @str = available_externally unnamed_addr constant [14 x i8] c",\22session_id\22:", align 1
@str = unnamed_addr constant [14 x i8] c",\22session_id\22:", align 1

; Externalized locals are copied, and the copy is not in a comdat.
; CHECK0: @local_str = available_externally hidden constant [4 x i8] c"abc\00"
; CHECK1: @local_str = hidden constant [4 x i8] c"abc\00"
@local_str = internal constant [4 x i8] c"abc\00"
; CHECK0: @cd = linkonce_odr constant [4 x i8] c"def\00", comdat
; CHECK1: @cd = available_externally constant [4 x i8] c"def\00"{{$}}
@cd = linkonce_odr constant [4 x i8] c"def\00", comdat

; Non-constant, interposable, thread-local and relocated globals are only
; declared outside their partition.
; CHECK0: @var = global [4 x i8] c"ghi\00"
; CHECK1: @var = external global [4 x i8]{{$}}
@var = global [4 x i8] c"ghi\00"
; CHECK0: @weak_str = linkonce constant [4 x i8] c"jkl\00"
; CHECK1: @weak_str = external constant [4 x i8]{{$}}
@weak_str = linkonce constant [4 x i8] c"jkl\00"
; CHECK0: @tls_str = thread_local constant [4 x i8] c"mno\00"
; CHECK1: @tls_str = external thread_local constant [4 x i8]{{$}}
@tls_str = thread_local constant [4 x i8] c"mno\00"
; CHECK0: @ptr_table = constant ptr @str
; CHECK1: @ptr_table = external constant ptr{{$}}
@ptr_table = constant ptr @str

; The memcpy from the copy of @local_str is folded into an immediate store.
; CHECK0: define void @foo(
; CHECK1: declare void @foo(
; ASM0-LABEL: foo:
; ASM0: movw $25442, (%rcx)
; ASM0-NEXT: retq
define void @foo(ptr %d) {
  call void @llvm.memcpy.p0.p0.i64(ptr %d, ptr getelementptr inbounds (i8, ptr @local_str, i64 1), i64 2, i1 false)
  ret void
}

; The memcpy from the copy of @str is folded into immediate stores.
; CHECK0: declare void @bar(
; CHECK1: define void @bar(
; ASM1-LABEL: bar:
; ASM1-NOT: str
; ASM1: movabsq $2478221553556220275, %rax
; ASM1-NOT: str
; ASM1: movabsq $8028074750225097260, %rax
; ASM1-NOT: str
; ASM1: retq
define void @bar(ptr %d) {
  call void @llvm.memcpy.p0.p0.i64(ptr %d, ptr @str, i64 13, i1 false)
  ret void
}

; CHECK0: declare i8 @baz(
; CHECK1: define i8 @baz(
define i8 @baz() {
  %cd = load i8, ptr @cd
  %var = load i8, ptr @var
  %weak = load i8, ptr @weak_str
  %tls.addr = call ptr @llvm.threadlocal.address.p0(ptr @tls_str)
  %tls = load i8, ptr %tls.addr
  %ptr = load ptr, ptr @ptr_table
  %ptr.val = load i8, ptr %ptr
  %a = add i8 %cd, %var
  %b = add i8 %a, %weak
  %c = add i8 %b, %tls
  %r = add i8 %c, %ptr.val
  ret i8 %r
}

; Only the owning partition emits the constants.
; ASM0: {{^}}str:
; ASM0: {{^}}cd:
; ASM1: {{^}}local_str:
