FROM docker.io/i386/alpine:3.21.0

ENV KERNEL=virt

# Base system + dev tools
# quickjs: fast ES2020+ JS runtime (no JIT overhead — ideal for emulated CPU)
# git: version control (real binary, not just the browser fetch intercept)
RUN apk add --no-cache \
    openrc alpine-base agetty alpine-conf \
    linux-$KERNEL linux-firmware-none \
    quickjs git

# Auto-login on console and serial
RUN sed -i 's/getty 38400 tty1/agetty --autologin root tty1 linux/' /etc/inittab
RUN echo 'ttyS0::respawn:/sbin/agetty --autologin root -s ttyS0 115200 vt100' >> /etc/inittab
RUN echo "root:" | chpasswd

RUN setup-hostname localhost

# Networking helper
RUN printf 'rmmod ne2k-pci && modprobe ne2k-pci\nrmmod virtio-net && modprobe virtio-net\nhwclock -s\nsetup-interfaces -a -r\n' > /root/networking.sh && chmod +x /root/networking.sh

# Sample file
RUN echo 'console.log("Hello from QuickJS!");' > /root/hello.js

# OpenRC services
RUN for i in devfs dmesg mdev hwdrivers; do rc-update add $i sysinit; done
RUN for i in hwclock modules sysctl hostname syslog bootmisc; do rc-update add $i boot; done
RUN rc-update add killprocs shutdown

# Generate initramfs with 9p modules (critical for v86 filesystem)
RUN mkinitfs -F "base virtio 9p" $(cat /usr/share/kernel/$KERNEL/kernel.release)
