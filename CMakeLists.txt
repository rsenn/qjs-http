project(quickjs-modules C)

cmake_minimum_required(VERSION 3.2)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindQuickJS.cmake)

make_shared_module(libhttputil http-util.c http_parser.c http_parser.h)
