# Optimized NGINX build script
This script is intended to ease building optimized NGINX with the newest libraries automatically.

Versions of all software being built including NGINX itself can be changed in the configuration section of the script. All actions are going to be handled automatically.

This script consists of me learning more advanced shell scripting concepts. Excuse the mess :)

**Did not bother handling missing dependencies, maybe later ;)**

**Architecture/CPU specific optimizations are tuned for Raspberry Pi 4B**

**The script is supposed to be ran using zsh**

# Additional software
- Redis

# Libraries
- OpenSSL/BoringSSL (**BoringSSL** does not work at the moment, being worked on)
- Jemalloc (optimized malloc preventing heap fragmentation typically observed on permanently running software)
- ZLib (Cloudflare's optimized fork)
- Libatomic
- PCRE2 (supporting versions above range stated by NGINX)
- NGX_Brotli (for better compression than gzip in certain cases)

# Other optimizations
- Removing unnecessary NGINX modules and focusing on HTTP part only
- Leveraging GCC optimization features
- Enabling NGINX thread pools
- Enabling NGNIX file-aio
- Focusing on HTTP3/QUIC (currently using OpenSSL's compatibility layer as it only supports client-side)

# TODO:
- BoringSSL
- Automatically include hardened TLS configuration
