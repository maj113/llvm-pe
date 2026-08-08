// RUN: %clang_cl /d2FH4 /c -### -- %s 2>&1 | FileCheck %s --check-prefix=FH4
// RUN: %clang_cl /d2FH4- /d2FH4 /c -### -- %s 2>&1 | FileCheck %s --check-prefix=FH4
// FH4: "-fms-cxx-eh4"
// FH4-NOT: "-fno-ms-cxx-eh4"

// RUN: %clang_cl /d2FH4 /d2FH4- /c -### -- %s 2>&1 | FileCheck %s --check-prefix=NO-FH4
// NO-FH4: "-fno-ms-cxx-eh4"
// NO-FH4-NOT: "-fms-cxx-eh4"

// RUN: %clang --target=x86_64-pc-windows-msvc -fms-cxx-eh4 -### -c %s 2>&1 | FileCheck %s --check-prefix=FH4
// RUN: %clang --target=x86_64-pc-windows-msvc -fms-cxx-eh4 -fno-ms-cxx-eh4 -### -c %s 2>&1 | FileCheck %s --check-prefix=NO-FH4

int main(void) { return 0; }
