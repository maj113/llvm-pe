//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// REQUIRES: target={{.+}}-aix{{.*}}
// REQUIRES: has-filecheck

// ADDITIONAL_COMPILE_FLAGS: -fno-inline -fno-exceptions

// RUN: %{build}
// RUN: %{exec} %t.exe 2>&1 | FileCheck %s

// Tests use of the libunwind C API to step up from a context where the VAPI is
// active and to resume contexts where
// - the VAPI is active (and thus VAPI return glue is not called) and
// - where the VAPI is not active (and thus VAPI return glue _is_ called).
//
// In the latter case, which applies not just to the caller of the Virtual API
// but also to its ancestors, the return glue should always be called (i.e.,
// each time, without regard for whether the VAPI is currently active).

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

extern "C" void *returns_twice_bsearch
    [[gnu::returns_twice]] (const void *, const void *, size_t, size_t,
                            int (*)(const void *,
                                    const void *)) __asm__("bsearch");

extern "C" int cmp(const void *pa, const void *pb) {
  (void)pa;
  (void)pb;

  fprintf(
      stderr,
      "Populate global cursors for `bsearch`, `bsearch_caller`, and `main`.\n");
  // TODO

  // Test resuming context where VAPI is active.
  fprintf(stderr,
          "Return to `bsearch` with r3 set to 0 using the global cursor.\n");
  // TODO
}

char bsearch_caller_ret;
void *bsearch_caller(void) {
  volatile int state = 0;

  char c;
  char buf[3];
  assert(returns_twice_bsearch(&c, buf, 1, 1, cmp) == &buf[state]);

  // Test resuming context where VAPI is not active. The VAPI return glue should
  // be used each time without regard for whether the VAPI is currently active.
  if (++state < 3) {
    fprintf(stderr,
            "Return to `bsearch_caller` at the invocation of "
            "`returns_twice_bsearch` (really `bsearch`) with r3 set to "
            "&buf[%d] using the global cursor.\n",
            state);
    // TODO
  }

  // Test resuming context where VAPI is not active, one frame up from the VAPI
  // caller.
  fprintf(stderr, "Return to `main` at the invocation of `bsearch_caller` with "
                  "r3 set to `&bsearch_caller_ret` using the global cursor.\n");
  // TODO
}

int main(void) {
  if (setenv("LIBUNWIND_PRINT_UNWINDING", "1", true) != 0) {
    perror("setenv");
    abort();
  }
  assert(bsearch_caller() == &bsearch_caller_ret);
}
