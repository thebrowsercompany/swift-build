
# NOTE(compnerd) disable iconv as we do not have this on Windows
set(LIBXML2_WITH_ICONV NO CACHE BOOL "")

# NOTE(compnerd) disable the python bindings, we do not use them
set(LIBXML2_WITH_PYTHON NO CACHE BOOL "")

# NOTE(compnerd) disable lzma/xz support as we do not use that
set(LIBXML2_WITH_LZMA NO CACHE BOOL "")

# NOTE(compnerd) disable zlib support as we do not have this on Windows
set(LIBXML2_WITH_ZLIB NO CACHE BOOL "")
