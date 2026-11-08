//=== X86CallingConv.h - X86 Custom Calling Convention Routines -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the custom routines for the X86 Calling Convention that
// aren't done by tablegen.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_X86_X86CALLINGCONV_H
#define LLVM_LIB_TARGET_X86_X86CALLINGCONV_H

#include "MCTargetDesc/X86MCTargetDesc.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/IR/CallingConv.h"

namespace llvm {

bool RetCC_X86(unsigned ValNo, MVT ValVT, MVT LocVT,
               CCValAssign::LocInfo LocInfo, ISD::ArgFlagsTy ArgFlags,
               Type *OrigTy, CCState &State);

bool CC_X86(unsigned ValNo, MVT ValVT, MVT LocVT, CCValAssign::LocInfo LocInfo,
            ISD::ArgFlagsTy ArgFlags, Type *OrigTy, CCState &State);

namespace X86 {

/// llvm-pe: the calling convention X86InternalCallContract gives functions
/// that are only ever called directly from their own module on x86-64
/// Windows. Fork-private, far above upstream's range.
constexpr CallingConv::ID InternalCC = 1000;

/// The callee-saved set of InternalCC (-x86-internal-cc-csr).
enum class InternalCSR {
  /// RBX, RBP, RDI, RSI, R12-R15, XMM6-15 (Win64): six argument registers of
  /// each kind.
  Win64,
  /// RBX, RBP, R12-R15 (SysV): eight of each.
  SysV,
  /// RBX, RBP, R12-R15, XMM8-15: eight of each.
  SysVXMM,
};
InternalCSR getInternalCCCSR();
inline bool internalCCPreservesWin64Set() {
  return getInternalCCCSR() == InternalCSR::Win64;
}

} // namespace X86

} // End llvm namespace

#endif

