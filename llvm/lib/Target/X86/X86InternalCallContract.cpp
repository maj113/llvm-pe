//===-- X86InternalCallContract.cpp - Internal call contract on Win64 -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// llvm-pe: on x86-64 Windows, a function that only its own module calls, and
// only directly, need not follow the Win64 convention. This pass gives such
// functions (and their call sites) X86::InternalCC: no 32-byte shadow space,
// six or eight argument registers of each kind and the callee-saved set
// chosen by -x86-internal-cc-csr. Together with -enable-ipra, callers then
// treat only what the callee's subtree really clobbers as clobbered.
//
// A function qualifies when it has local linkage, a C-like convention, no
// varargs, no address taken (no indirect, callback, cast or llvm.used use),
// no special argument attributes, no musttail call on either side, only call
// (not invoke) callers, and neither it nor any caller has an unwind table
// (-x86-internal-cc-with-unwind-tables lifts that for measurements; unwind
// data still describes every frame, but registers a Win64 unwind would
// restore may not be preserved). A function whose return-position tail call
// goes to code that stays Win64 keeps Win64 too, so that its sibcall
// survives (-x86-internal-cc-keep-sibcalls).
//
//===----------------------------------------------------------------------===//

#include "X86.h"
#include "X86CallingConv.h"
#include "llvm/ADT/SetVector.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

#define DEBUG_TYPE "x86-internal-call-contract"

STATISTIC(NumInternal, "Functions given the internal call contract");
STATISTIC(NumKeptForSibcall,
          "Candidates kept on Win64 for a sibcall to Win64 code");

static cl::opt<bool> EnableInternalCC(
    "x86-internal-cc", cl::init(false),
    cl::desc("Give functions only called directly from their module the "
             "internal call contract on x86-64 Windows (llvm-pe)"));

static cl::opt<bool> InternalCCWithUnwindTables(
    "x86-internal-cc-with-unwind-tables", cl::init(false), cl::Hidden,
    cl::desc("Also give it to functions with unwind tables (measurements)"));

static cl::opt<bool> KeepSibcalls(
    "x86-internal-cc-keep-sibcalls", cl::init(true), cl::Hidden,
    cl::desc("Keep Win64 on functions whose tail call goes to Win64 code"));


namespace {

class X86InternalCallContract : public ModulePass {
public:
  static char ID;
  X86InternalCallContract() : ModulePass(ID) {}

  StringRef getPassName() const override {
    return "X86 internal call contract";
  }
  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
  }
  bool runOnModule(Module &M) override;
};

} // namespace

char X86InternalCallContract::ID = 0;

INITIALIZE_PASS(X86InternalCallContract, DEBUG_TYPE,
                "X86 internal call contract", false, false)

ModulePass *llvm::createX86InternalCallContractPass() {
  return new X86InternalCallContract();
}

static bool hasUnwindTable(const Function &F) {
  return !InternalCCWithUnwindTables && F.hasUWTable();
}

static bool isCandidate(const Function &F) {
  if (F.isDeclaration() || !F.hasLocalLinkage() || F.isVarArg())
    return false;
  switch (F.getCallingConv()) {
  case CallingConv::C:
  case CallingConv::Fast:
  case CallingConv::X86_ThisCall:
    break;
  default:
    return false;
  }
  if (F.hasFnAttribute(Attribute::Naked) || F.hasPersonalityFn() ||
      F.hasPrefixData() || F.hasPrologueData() || hasUnwindTable(F) ||
      F.hasAddressTaken())
    return false;
  for (const Argument &A : F.args())
    if (A.hasByValAttr() || A.hasInAllocaAttr() || A.hasPreallocatedAttr() ||
        A.hasNestAttr() || A.hasSwiftSelfAttr() || A.hasSwiftErrorAttr() ||
        A.hasAttribute(Attribute::SwiftAsync))
      return false;
  for (const User *U : F.users()) {
    // hasAddressTaken() leaves only direct calls of the exact type.
    const auto *CI = dyn_cast<CallInst>(U);
    if (!CI || CI->isMustTailCall() || hasUnwindTable(*CI->getFunction()))
      return false;
  }
  for (const BasicBlock &BB : F)
    if (BB.getTerminatingMustTailCall())
      return false;
  return true;
}

/// Whether \p F returns the result of a tail call (a sibcall candidate) to
/// something that is not a candidate, so must stay Win64 to keep it.
static bool tailCallsWin64Code(const Function &F,
                               const SetVector<Function *> &Cands) {
  for (const BasicBlock &BB : F) {
    const auto *Ret = dyn_cast<ReturnInst>(BB.getTerminator());
    if (!Ret)
      continue;
    for (const Instruction *I = Ret->getPrevNode(); I; I = I->getPrevNode()) {
      if (isa<DbgInfoIntrinsic>(I) || isa<PseudoProbeInst>(I) ||
          I->isLifetimeStartOrEnd())
        continue;
      const auto *CI = dyn_cast<CallInst>(I);
      if (!CI || !CI->isTailCall() || isa<IntrinsicInst>(CI))
        break;
      if (Ret->getReturnValue() && Ret->getReturnValue() != CI)
        break;
      const Function *Callee = CI->getCalledFunction();
      if (!Callee || !Cands.contains(const_cast<Function *>(Callee)))
        return true;
      break;
    }
  }
  return false;
}

static bool assignInternalCC(Module &M) {
  SetVector<Function *> Cands;
  for (Function &F : M)
    if (isCandidate(F))
      Cands.insert(&F);

  // Dropping one candidate can turn another's tail call into one to Win64
  // code: iterate until nothing changes.
  if (KeepSibcalls) {
    SmallVector<Function *, 16> Drop;
    do {
      Drop.clear();
      for (Function *F : Cands)
        if (tailCallsWin64Code(*F, Cands))
          Drop.push_back(F);
      for (Function *F : Drop)
        Cands.remove(F);
      NumKeptForSibcall += Drop.size();
    } while (!Drop.empty());
  }

  for (Function *F : Cands) {
    F->setCallingConv(X86::InternalCC);
    for (User *U : F->users())
      cast<CallInst>(U)->setCallingConv(X86::InternalCC);
    ++NumInternal;
  }
  return !Cands.empty();
}

bool X86InternalCallContract::runOnModule(Module &M) {
  if (!EnableInternalCC || skipModule(M))
    return false;
  const Triple &TT = M.getTargetTriple();
  if (!TT.isOSWindows() || !TT.isX86_64())
    return false;
  return assignInternalCC(M);
}
