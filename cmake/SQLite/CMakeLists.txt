
cmake_minimum_required(VERSION 3.12.3)

project(SQLite LANGUAGES C)

set(CMAKE_POSITION_INDEPENDENT_CODE YES)

add_library(SQLite3
  sqlite3.c)
if(CMAKE_SYSTEM_NAME STREQUAL Windows AND BUILD_SHARED_LIBS)
  target_compile_definitions(SQLite3 PRIVATE
    "SQLITE_API=__declspec(dllexport)")
endif()

install(TARGETS SQLite3
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)
install(FILES sqlite3.h sqlite3ext.h
  DESTINATION include)

