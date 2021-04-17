include(CheckIncludeFile)

if(NOT QUICKJS_PREFIX)
  set(QUICKJS_PREFIX "${CMAKE_INSTALL_PREFIX}" CACHE PATH "QuickJS install directory")
else(NOT QUICKJS_PREFIX)
  set(QUICKJS_PREFIX "${QUICKJS_PREFIX}" CACHE PATH "QuickJS install directory")
endif(NOT QUICKJS_PREFIX)

set(CMAKE_INSTALL_PREFIX "${QUICKJS_PREFIX}" CACHE PATH "Install directory" FORCE)
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release MinSizeRel RelWithDebInfo)

message("QuickJS install directory: ${QUICKJS_PREFIX}")

set(CMAKE_REQUIRED_QUIET TRUE)

set(QUICKJS_INCLUDE_DIRS "")

if(EXISTS "${CMAKE_CURRENT_BINARY_DIR}/../quickjs-config.h")
  list(APPEND QUICKJS_INCLUDE_DIRS ..)
  list(APPEND QUICKJS_INCLUDE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/..")
endif(EXISTS "${CMAKE_CURRENT_BINARY_DIR}/../quickjs-config.h")

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../quickjs.h")
  file(RELATIVE_PATH QUICKJS_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}/..")
  list(APPEND QUICKJS_INCLUDE_DIRS "${QUICKJS_INCLUDE_DIR}")
  list(APPEND QUICKJS_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/..")
endif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../quickjs.h")

if(EXISTS "${QUICKJS_PREFIX}/include/quickjs")
  list(APPEND QUICKJS_INCLUDE_DIRS "${QUICKJS_PREFIX}/include/quickjs")
endif(EXISTS "${QUICKJS_PREFIX}/include/quickjs")

set(QUICKJS_INCLUDE_DIRS "${QUICKJS_INCLUDE_DIRS}" CACHE STRING "QuickJS include dirs" FORCE)

set(CMAKE_REQUIRED_INCLUDES "${QUICKJS_INCLUDE_DIRS}")

check_include_file(quickjs.h HAVE_QUICKJS_H)
check_include_file(quickjs-config.h HAVE_QUICKJS_CONFIG_H)

if(NOT HAVE_QUICKJS_H)
  message(FATAL_ERROR "QuickJS headers not found")
endif(NOT HAVE_QUICKJS_H)

include_directories(${QUICKJS_INCLUDE_DIRS})

if(HAVE_QUICKJS_CONFIG_H)
  add_definitions(-DHAVE_QUICKJS_CONFIG_H=1)
endif(HAVE_QUICKJS_CONFIG_H)

find_program(QJS qjs PATHS "${CMAKE_CURRENT_BINARY_DIR}/.." "${QUICKJS_PREFIX}/bin" ENV PATH NO_DEFAULT_PATH)
find_program(QJSC qjsc PATHS "${CMAKE_CURRENT_BINARY_DIR}/.." "${QUICKJS_PREFIX}/bin" ENV PATH NO_DEFAULT_PATH)

message(STATUS "QuickJS interpreter: ${QJS}")
message(STATUS "QuickJS compiler: ${QJSC}")

set(CUTILS_H ${CMAKE_CURRENT_SOURCE_DIR}/../cutils.h)
set(QUICKJS_H ${CMAKE_CURRENT_SOURCE_DIR}/../quickjs.h)
include(CheckCCompilerFlag)

macro(append_vars STR)
  # message("append_vars(${STR} ${ARGN})")
  foreach(L ${ARGN})
    set(LIST "${${L}}")
    if(NOT LIST MATCHES ".*${STR}.*")
      if("${LIST}" STREQUAL "")
        set(LIST "${STR}")
      else("${LIST}" STREQUAL "")
        set(LIST "${LIST} ${STR}")
      endif("${LIST}" STREQUAL "")

    endif(NOT LIST MATCHES ".*${STR}.*")
    string(REPLACE ";" " " LIST "${LIST}")
    # message("New value for ${L}: ${LIST}")
    set("${L}" "${LIST}" PARENT_SCOPE)
  endforeach(L ${ARGN})
endmacro(append_vars STR)

function(check_flag FLAG VAR)
  if(NOT VAR OR VAR STREQUAL "")
    string(TOUPPER "${FLAG}" TMP)
    string(REGEX REPLACE "[^0-9A-Za-z]" _ VAR "${TMP}")
  endif(NOT VAR OR VAR STREQUAL "")
  set(CMAKE_REQUIRED_QUIET ON)
  check_c_compiler_flag("${FLAG}" "${VAR}")
  set(CMAKE_REQUIRED_QUIET OFF)

  set(RESULT "${${VAR}}")
  if(RESULT)
    append_vars(${FLAG} ${ARGN})
    # message(STATUS "Compiler flag ${FLAG} ... supported [${VAR}] [${ARGN}]") message("append_vars(${FLAG} ${ARGN})")
  endif(RESULT)
endfunction(check_flag FLAG VAR)

function(config_shared_module TARGET_NAME)
  if(QUICKJS_LIBRARY_DIR)
    set_target_properties(${TARGET_NAME} PROPERTIES LINK_DIRECTORIES "${QUICKJS_LIBRARY_DIR}")
  endif(QUICKJS_LIBRARY_DIR)
  if(QUICKJS_MODULE_DEPENDENCIES)
    target_link_libraries(${TARGET_NAME} ${QUICKJS_MODULE_DEPENDENCIES})
  endif(QUICKJS_MODULE_DEPENDENCIES)
  if(QUICKJS_MODULE_CFLAGS)
    target_compile_options(${TARGET_NAME} PRIVATE "${QUICKJS_MODULE_CFLAGS}")
  endif(QUICKJS_MODULE_CFLAGS)
endfunction(config_shared_module TARGET_NAME)

function(make_shared_module FNAME)
  string(REGEX REPLACE "_" "-" NAME "${FNAME}")
  string(REGEX REPLACE "^lib" "" NAME "${NAME}")
  string(REGEX REPLACE "-" "_" VNAME "${FNAME}")
  string(TOUPPER "${FNAME}" UUNAME)
  string(REGEX REPLACE "-" "_" UNAME "${UUNAME}")

  if(NOT ARGN)
    set(SOURCES quickjs-${NAME}.c ${${VNAME}_SOURCES})

  else(NOT ARGN)
    set(SOURCES ${ARGN} ${${VNAME}_SOURCES})

  endif(NOT ARGN)

  set(TARGET_NAME quickjs-${NAME})
  add_library(${TARGET_NAME} SHARED ${SOURCES})

  target_link_libraries(${TARGET_NAME} ${OpenCV_LIBS})
  set_target_properties(${TARGET_NAME} PROPERTIES PREFIX "" RPATH "${OPENCV_LIBRARY_DIRS}:${QUICKJS_PREFIX}/lib:${QUICKJS_PREFIX}/lib/quickjs" OUTPUT_NAME "${FNAME}" BUILD_RPATH "${CMAKE_BINARY_DIR}:${CMAKE_CURRENT_BINARY_DIR}:${CMAKE_BINARY_DIR}/quickjs:${CMAKE_CURRENT_BINARY_DIR}/quickjs" COMPILE_FLAGS "${MODULE_COMPILE_FLAGS}")
  target_compile_definitions(${TARGET_NAME} PRIVATE JS_SHARED_LIBRARY=1 JS_${UNAME}_MODULE=1 CONFIG_PREFIX="${QUICKJS_PREFIX}")
  install(TARGETS ${TARGET_NAME} DESTINATION lib/quickjs PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

  config_shared_module(${TARGET_NAME})
endfunction()
check_flag("-fvisibility=hidden" VISIBILITY_HIDDEN MODULE_COMPILE_FLAGS)
