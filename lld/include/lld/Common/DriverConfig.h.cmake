//===- DriverConfig.h - LLD driver configuration ----------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_COMMON_DRIVERCONFIG_H
#define LLD_COMMON_DRIVERCONFIG_H

#cmakedefine01 LLD_ENABLE_COFF
#cmakedefine01 LLD_ENABLE_ELF
#cmakedefine01 LLD_ENABLE_MACHO
#cmakedefine01 LLD_ENABLE_MINGW
#cmakedefine01 LLD_ENABLE_WASM

#endif
