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
  - [Brotli](https://github.com/google/ngx_brotli) compression
  - Supporting PCRE2 versions higher than officially supported
  - Including hardened TLS configuration
- MariaDB **TODO**
- PHP-FPM **TODO**

# Other optimizations
- OpenSSL/[BoringSSL](https://boringssl.googlesource.com/boringssl) (**BoringSSL** is not currently supported)
- [Jemalloc](https://github.com/jemalloc/jemalloc) (optimized memory allocator preventing heap fragmentation typically observed on long-running software)
- Cloudflare's [optimized fork](https://github.com/cloudflare/zlib) of zlib
- Libatomic
- Leveraging GCC optimization features

# Optional software
- Redis