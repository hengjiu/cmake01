include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(cmake01_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(cmake01_setup_options)
  option(cmake01_ENABLE_HARDENING "Enable hardening" ON)
  option(cmake01_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cmake01_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cmake01_ENABLE_HARDENING
    OFF)

  cmake01_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cmake01_PACKAGING_MAINTAINER_MODE)
    option(cmake01_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cmake01_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cmake01_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cmake01_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cmake01_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cmake01_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cmake01_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cmake01_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cmake01_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cmake01_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cmake01_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cmake01_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cmake01_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cmake01_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cmake01_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cmake01_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cmake01_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cmake01_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cmake01_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cmake01_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cmake01_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cmake01_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cmake01_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cmake01_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cmake01_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cmake01_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cmake01_ENABLE_IPO
      cmake01_WARNINGS_AS_ERRORS
      cmake01_ENABLE_USER_LINKER
      cmake01_ENABLE_SANITIZER_ADDRESS
      cmake01_ENABLE_SANITIZER_LEAK
      cmake01_ENABLE_SANITIZER_UNDEFINED
      cmake01_ENABLE_SANITIZER_THREAD
      cmake01_ENABLE_SANITIZER_MEMORY
      cmake01_ENABLE_UNITY_BUILD
      cmake01_ENABLE_CLANG_TIDY
      cmake01_ENABLE_CPPCHECK
      cmake01_ENABLE_COVERAGE
      cmake01_ENABLE_PCH
      cmake01_ENABLE_CACHE)
  endif()

  cmake01_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cmake01_ENABLE_SANITIZER_ADDRESS OR cmake01_ENABLE_SANITIZER_THREAD OR cmake01_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cmake01_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cmake01_global_options)
  if(cmake01_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cmake01_enable_ipo()
  endif()

  cmake01_supports_sanitizers()

  if(cmake01_ENABLE_HARDENING AND cmake01_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cmake01_ENABLE_SANITIZER_UNDEFINED
       OR cmake01_ENABLE_SANITIZER_ADDRESS
       OR cmake01_ENABLE_SANITIZER_THREAD
       OR cmake01_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cmake01_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cmake01_ENABLE_SANITIZER_UNDEFINED}")
    cmake01_enable_hardening(cmake01_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cmake01_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cmake01_warnings INTERFACE)
  add_library(cmake01_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cmake01_set_project_warnings(
    cmake01_warnings
    ${cmake01_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cmake01_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    cmake01_configure_linker(cmake01_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cmake01_enable_sanitizers(
    cmake01_options
    ${cmake01_ENABLE_SANITIZER_ADDRESS}
    ${cmake01_ENABLE_SANITIZER_LEAK}
    ${cmake01_ENABLE_SANITIZER_UNDEFINED}
    ${cmake01_ENABLE_SANITIZER_THREAD}
    ${cmake01_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cmake01_options PROPERTIES UNITY_BUILD ${cmake01_ENABLE_UNITY_BUILD})

  if(cmake01_ENABLE_PCH)
    target_precompile_headers(
      cmake01_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cmake01_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cmake01_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cmake01_ENABLE_CLANG_TIDY)
    cmake01_enable_clang_tidy(cmake01_options ${cmake01_WARNINGS_AS_ERRORS})
  endif()

  if(cmake01_ENABLE_CPPCHECK)
    cmake01_enable_cppcheck(${cmake01_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cmake01_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cmake01_enable_coverage(cmake01_options)
  endif()

  if(cmake01_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cmake01_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cmake01_ENABLE_HARDENING AND NOT cmake01_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cmake01_ENABLE_SANITIZER_UNDEFINED
       OR cmake01_ENABLE_SANITIZER_ADDRESS
       OR cmake01_ENABLE_SANITIZER_THREAD
       OR cmake01_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cmake01_enable_hardening(cmake01_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
