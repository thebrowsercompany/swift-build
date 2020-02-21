
cmake_policy(SET CMP0077 NEW)

set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE BOOL "")

# NOTE(compnerd) don't build curl tool as we don't use it
set(BUILD_CURL_EXE NO CACHE BOOL "")

# FIXME(compnerd) we should probably enable openssl support, but this is not
# universally available, and we do not yet build our own OpenSSL to build
# against
set(CMAKE_USE_OPENSSL NO CACHE BOOL "")
set(CURL_CA_PATH "none" CACHE STRING "")

# FIXME(compnerd) should we enable this?  I don't believe that ssh is a
# supported protocol for Foundation
set(CMAKE_USE_LIBSSH2 NO CACHE BOOL "")

# NOTE(compenrd) disable HAVE_POLL_FINE since the test fails when
# cross-compiling
set(HAVE_POLL_FINE NO CACHE BOOL "")

# NOTE(compnerd) disable ldap since Foundation does not use it
set(CURL_DISABLE_LDAP YES CACHE BOOL "")
set(CURL_DISABLE_LDAPS YES CACHE BOOL "")

# NOTE(compnerd) disable telnet since Foundation does not use it
set(CURL_DISABLE_TELNET YES CACHE BOOL "")

# XXX(compnerd) what is this?
set(CURL_DISABLE_DICT YES CACHE BOOL "")

# FIXME(compnerd) does Foundation use `file:///`?
set(CURL_DISABLE_FILE YES CACHE BOOL "")

# FIXME(compnerd) does Foundation use `tftp:///`?  It does support FTP
set(CURL_DISABLE_TFTP YES CACHE BOOL "")

# NOTE(compnerd) Foundation does not support streaming audio, disable RTSP
set(CURL_DISABLE_RTSP YES CACHE BOOL "")

# FIXME(compnerd) should we enable proxy support?  Does Foundation support it?
set(CURL_DISABLE_PROXY YES CACHE BOOL "")

# NOTE(compnerd) Foundation does not support email, disable email protocols
set(CURL_DISABLE_POP3 YES CACHE BOOL "")
set(CURL_DISABLE_IMAP YES CACHE BOOL "")
set(CURL_DISABLE_SMTP YES CACHE BOOL "")

# NOTE(compnerd) we don't use nor support gopher, does anyone these days?
set(CURL_DISABLE_GOPHER YES CACHE BOOL "")

# NOTE(compnerd) use zlib for zlib decompression of HTTP streams
set(CURL_ZLIB YES CACHE BOOL "")

# NOTE(compnerd) this isn't used and we don't have Unix sockets on Windows
set(ENABLE_UNIX_SOCKETS NO CACHE BOOL "")

set(ENABLE_THREADED_RESOLVER NO CACHE BOOL "")
