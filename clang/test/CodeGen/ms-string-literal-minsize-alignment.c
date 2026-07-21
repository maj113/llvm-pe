// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -emit-llvm -O2 -o - %s | FileCheck %s --check-prefix=DEFAULT
// RUN: %clang_cc1 -triple x86_64-pc-windows-msvc -emit-llvm -Oz -o - %s | FileCheck %s --check-prefix=MINSIZE

const char *narrow(void) { return "1234567"; }
const unsigned short *wide(void) { return L"1234567"; }

// DEFAULT-DAG: unnamed_addr constant [8 x i8] c"1234567\00", comdat, align 8
// DEFAULT-DAG: unnamed_addr constant [8 x i16] {{.*}}, comdat, align 8
// MINSIZE-DAG: unnamed_addr constant [8 x i8] c"1234567\00", comdat, align 1
// MINSIZE-DAG: unnamed_addr constant [8 x i16] {{.*}}, comdat, align 2
