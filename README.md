# Optimized LEMP stack build stack
This script is intended to ease building optimized LEMP stack **and more** using the newest software and libraries.

Versions of each stack part/library can be tuned in the script header.

The script mostly consists of me experimenting with more advanced scripting concepts, please be kind :)

**Architecture/CPU specific optimizations are tuned for Raspberry Pi 4B**

**The script is written in zsh**

# Software installed
- NGINX
  - Removing unnecessary modules and focusing strictly on the HTTP part
  - Enabling thread pools
  - Enabling file-aio
  - Prioritizing HTTP3/QUIC
  - (https://github.com/google/ngx_brotli)[Brotli] compression
  - Supporting PCRE2 versions higher than officially supported
  - Including hardened TLS configuration
- MariaDB **TODO**
- PHP-FPM **TODO**

# Other optimizations
- OpenSSL/(https://boringssl.googlesource.com/boringssl)[BoringSSL] (**BoringSSL** is not currently supported)
- (https://github.com/jemalloc/jemalloc)[Jemalloc] (optimized memory allocator preventing heap fragmentation typically observed on long-running software)
- Cloudflare's (https://github.com/cloudflare/zlib)[optimized fork] of zlib
- Libatomic
- Leveraging GCC optimization features

# Optional software
- Redis