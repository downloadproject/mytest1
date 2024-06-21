include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(mytest1_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(mytest1_setup_options)
  option(mytest1_ENABLE_HARDENING "Enable hardening" ON)
  option(mytest1_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    mytest1_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    mytest1_ENABLE_HARDENING
    OFF)

  mytest1_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR mytest1_PACKAGING_MAINTAINER_MODE)
    option(mytest1_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(mytest1_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(mytest1_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(mytest1_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(mytest1_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(mytest1_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(mytest1_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(mytest1_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(mytest1_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(mytest1_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(mytest1_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(mytest1_ENABLE_PCH "Enable precompiled headers" OFF)
    option(mytest1_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(mytest1_ENABLE_IPO "Enable IPO/LTO" ON)
    option(mytest1_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(mytest1_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(mytest1_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(mytest1_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(mytest1_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(mytest1_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(mytest1_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(mytest1_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(mytest1_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(mytest1_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(mytest1_ENABLE_PCH "Enable precompiled headers" OFF)
    option(mytest1_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      mytest1_ENABLE_IPO
      mytest1_WARNINGS_AS_ERRORS
      mytest1_ENABLE_USER_LINKER
      mytest1_ENABLE_SANITIZER_ADDRESS
      mytest1_ENABLE_SANITIZER_LEAK
      mytest1_ENABLE_SANITIZER_UNDEFINED
      mytest1_ENABLE_SANITIZER_THREAD
      mytest1_ENABLE_SANITIZER_MEMORY
      mytest1_ENABLE_UNITY_BUILD
      mytest1_ENABLE_CLANG_TIDY
      mytest1_ENABLE_CPPCHECK
      mytest1_ENABLE_COVERAGE
      mytest1_ENABLE_PCH
      mytest1_ENABLE_CACHE)
  endif()

  mytest1_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (mytest1_ENABLE_SANITIZER_ADDRESS OR mytest1_ENABLE_SANITIZER_THREAD OR mytest1_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(mytest1_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(mytest1_global_options)
  if(mytest1_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    mytest1_enable_ipo()
  endif()

  mytest1_supports_sanitizers()

  if(mytest1_ENABLE_HARDENING AND mytest1_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR mytest1_ENABLE_SANITIZER_UNDEFINED
       OR mytest1_ENABLE_SANITIZER_ADDRESS
       OR mytest1_ENABLE_SANITIZER_THREAD
       OR mytest1_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${mytest1_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${mytest1_ENABLE_SANITIZER_UNDEFINED}")
    mytest1_enable_hardening(mytest1_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(mytest1_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(mytest1_warnings INTERFACE)
  add_library(mytest1_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  mytest1_set_project_warnings(
    mytest1_warnings
    ${mytest1_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(mytest1_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    mytest1_configure_linker(mytest1_options)
  endif()

  include(cmake/Sanitizers.cmake)
  mytest1_enable_sanitizers(
    mytest1_options
    ${mytest1_ENABLE_SANITIZER_ADDRESS}
    ${mytest1_ENABLE_SANITIZER_LEAK}
    ${mytest1_ENABLE_SANITIZER_UNDEFINED}
    ${mytest1_ENABLE_SANITIZER_THREAD}
    ${mytest1_ENABLE_SANITIZER_MEMORY})

  set_target_properties(mytest1_options PROPERTIES UNITY_BUILD ${mytest1_ENABLE_UNITY_BUILD})

  if(mytest1_ENABLE_PCH)
    target_precompile_headers(
      mytest1_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(mytest1_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    mytest1_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(mytest1_ENABLE_CLANG_TIDY)
    mytest1_enable_clang_tidy(mytest1_options ${mytest1_WARNINGS_AS_ERRORS})
  endif()

  if(mytest1_ENABLE_CPPCHECK)
    mytest1_enable_cppcheck(${mytest1_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(mytest1_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    mytest1_enable_coverage(mytest1_options)
  endif()

  if(mytest1_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(mytest1_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(mytest1_ENABLE_HARDENING AND NOT mytest1_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR mytest1_ENABLE_SANITIZER_UNDEFINED
       OR mytest1_ENABLE_SANITIZER_ADDRESS
       OR mytest1_ENABLE_SANITIZER_THREAD
       OR mytest1_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    mytest1_enable_hardening(mytest1_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
