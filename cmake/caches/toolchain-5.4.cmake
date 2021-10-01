# Set CMAKE_MT for runtimes. Required for CMake 3.20+. As CMake external project, 
# runtimes doesn't derive CMAKE_MT from toochain caches. We have to pass it 
# explicitly as additional argument.
set(RUNTIMES_CMAKE_ARGS "-DCMAKE_MT=mt" CACHE STRING "")
