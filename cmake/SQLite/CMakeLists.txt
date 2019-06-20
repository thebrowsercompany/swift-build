
cmake_minimum_required(VERSION 3.12.3)

project(SQLite LANGUAGES C)

add_library(SQLite3
  sqlite3.c)
if(CMAKE_SYSTEM_NAME STREQUAL Windows)
  target_compile_definitions(SQLite3
    SQLITE_API=__declspec(dllexport))
endif()

install(TARGETS SQLite3
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)
install(FILES sqlite3.h sqlite3ext.h
  DESTINATION include)

