cmake_minimum_required(VERSION 2.8)
project(osx-dictionary)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -Wall -Wextra -pedantic-errors")
set(CMAKE_CXX_FLAGS_DEBUG "-g3 -D_DEBUG -O0 -pg")
set(CMAKE_CXX_FLAGS_RELEASE "-O2 -DNDEBUG -march=native")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-O2 -g3 -pg -march=native")
set(CMAKE_CXX_FLAGS_MINSIZEREL "-Os -DNDEBUG -march=native")

set(SOURCE_FILES
  osx-dictionary.mm
)

add_executable(osx-dictionary
  ${SOURCE_FILES})

find_library(COCOA_LIBRARY Cocoa)
find_library(CORE_FOUNDATION_LIBRARY CoreFoundation)

target_link_libraries(osx-dictionary
  ${COCOA_LIBRARY}
  ${CORE_FOUNDATION_LIBRARY})

install(TARGETS osx-dictionary DESTINATION bin)
