function(add_lld_unittests test_dirname)
  add_unittest(LLDUnitTests ${test_dirname} ${ARGN})
endfunction()

if(LLD_ENABLE_COFF AND LLD_ENABLE_ELF AND LLD_ENABLE_MACHO AND
   LLD_ENABLE_MINGW AND LLD_ENABLE_WASM)
  add_subdirectory(AsLibAll)
endif()
if(LLD_ENABLE_ELF)
  add_subdirectory(AsLibELF)
endif()
