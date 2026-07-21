set(LLVM_LINK_COMPONENTS
  Support
  TargetParser
  )

add_lld_tool(lld
  lld.cpp

  SUPPORT_PLUGINS
  GENERATE_DRIVER
  )
export_executable_symbols_for_plugins(lld)

function(lld_target_link_libraries target type)
  if (TARGET obj.${target})
    target_link_libraries(obj.${target} ${type} ${ARGN})
  endif()

  get_property(LLVM_DRIVER_TOOLS GLOBAL PROPERTY LLVM_DRIVER_TOOLS)
  if(LLVM_TOOL_LLVM_DRIVER_BUILD AND ${target} IN_LIST LLVM_DRIVER_TOOLS)
    set(target llvm-driver)
  endif()

  target_link_libraries(${target} ${type} ${ARGN})
endfunction()

lld_target_link_libraries(lld
  PRIVATE
  lldCommon
  )

if(LLD_ENABLE_COFF)
  lld_target_link_libraries(lld PRIVATE lldCOFF)
endif()
if(LLD_ENABLE_ELF)
  lld_target_link_libraries(lld PRIVATE lldELF)
endif()
if(LLD_ENABLE_MACHO)
  lld_target_link_libraries(lld PRIVATE lldMachO)
endif()
if(LLD_ENABLE_MINGW)
  lld_target_link_libraries(lld PRIVATE lldMinGW)
endif()
if(LLD_ENABLE_WASM)
  lld_target_link_libraries(lld PRIVATE lldWasm)
endif()

if(NOT LLD_SYMLINKS_TO_CREATE)
  set(LLD_SYMLINKS_TO_CREATE)
  if(LLD_ENABLE_COFF)
    list(APPEND LLD_SYMLINKS_TO_CREATE lld-link)
  endif()
  if(LLD_ENABLE_ELF OR
     (LLD_ENABLE_MINGW AND LLD_DEFAULT_LD_LLD_IS_MINGW))
    list(APPEND LLD_SYMLINKS_TO_CREATE ld.lld)
  endif()
  if(LLD_ENABLE_MACHO)
    list(APPEND LLD_SYMLINKS_TO_CREATE ld64.lld)
  endif()
  if(LLD_ENABLE_WASM)
    list(APPEND LLD_SYMLINKS_TO_CREATE wasm-ld)
  endif()
endif()

foreach(link ${LLD_SYMLINKS_TO_CREATE})
  add_lld_symlink(${link} lld)
endforeach()

if(LLVM_TOOL_LLVM_DRIVER_BUILD)
  set_property(GLOBAL APPEND PROPERTY LLVM_DRIVER_HIDDEN_TOOL_ALIASES_lld ld)
endif()
