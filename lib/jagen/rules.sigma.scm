; host

(pkg 'make
     '(unpack)
     '(config host
              (build)
              (install)))

(pkg 'gdb
     '(unpack)
     '(prepare)
     '(config host
              (build)
              (install)))

; utils

(pkg 'utils
     '(clean)
     '(unpack)
     '(config host
              (build)
              (install))
     '(config target
              (build (gpgme install)
                     (dbus install))
              (install)))

; boot

(pkg 'xsdk
     '(unpack))

(pkg 'ucode
     '(unpack)
     '(install))

(pkg 'ezboot
     '(unpack)
     '(build after
             (xsdk unpack)
             (rootfs build))
     '(install))

(pkg 'yamon
     '(unpack)
     '(prepare)
     '(build after
             (xsdk unpack)
             (rootfs build))
     '(install))

; rootfs

(pkg 'rootfs
     '(clean)
     '(unpack)
     '(build after
             (make install host))
     '(install (kernel install)
               (loop-aes install)
               (mrua modules)
               (util-linux install)
               (e2fsprogs install)
               (gnupg install)
               (dbus install)
               (rsync install)
               (ntpclient install)
               (libuv install)
               (utils install target)
               (gdbserver install)
               (freetype install)
               (sqlite install)
               (strace install)
               (ralink install)
               (wpa_supplicant install)))

(pkg 'util-linux
     '(unpack)
     '(prepare)
     '(build (rootfs build))
     '(install))

(pkg 'e2fsprogs
     '(unpack)
     '(prepare)
     '(build (util-linux install))
     '(install))

(pkg 'libgpg-error
     '(unpack)
     '(build (rootfs build))
     '(install))

(pkg 'libassuan
     '(unpack)
     '(build (libgpg-error install))
     '(install))

(pkg 'gpgme
     '(unpack)
     '(build (libassuan install))
     '(install))

(pkg 'gnupg
     '(unpack)
     '(build (rootfs build))
     '(install))

(pkg 'expat
     '(unpack)
     '(build (rootfs build))
     '(install))

(pkg 'wpa_supplicant
     '(unpack)
     '(prepare)
     '(build (rootfs build)
             (dbus install))
     '(install))

; (pkg 'popt
;      '(unpack)
;      '(build (rootfs build))
;      '(install))
;
; (pkg 'device-mapper
;      '(unpack)
;      '(build (libgpg-error install))
;      '(install))
;
; (pkg 'libgcrypt
;      '(unpack)
;      '(prepare)
;      '(build (rootfs build))
;      '(install))
;
; (pkg 'cryptsetup
;      '(unpack)
;      '(prepare)
;      '(build (e2fsprogs install)
;              (popt install)
;              (device-mapper install)
;              (libgcrypt install))
;      '(install))

(pkg 'dbus
     '(unpack)
     '(build (expat install))
     '(install))

(pkg 'rsync
     '(unpack)
     '(build (rootfs build))
     '(install))

(pkg 'ntpclient
     '(unpack)
     '(build (rootfs build))
     '(install))

(pkg 'libuv
     '(unpack)
     '(prepare)
     '(build (rootfs build))
     '(install))

(pkg 'gdbserver
     '(unpack)
     '(build (rootfs build))
     '(install))

; (pkg 'oprofile
;      '(unpack)
;      '(prepare)
;      '(build (popt install))
;      '(install))

(pkg 'freetype
     '(unpack)
     '(prepare)
     '(build (rootfs build))
     '(install))

(pkg 'sqlite
     '(unpack)
     '(prepare)
     '(build (rootfs build))
     '(install))

(pkg 'strace
     '(unpack)
     '(build (rootfs build))
     '(install))

; (pkg 'chibi-scheme
;      '(config host
;               (unpack)
;               (build)
;               (install))
;      '(unpack)
;      '(patch)
;      '(build (chibi-scheme install host)
;              (rootfs build))
;      '(install))

(pkg 'linux
     '(unpack))

(pkg 'kernel
     '(unpack)
     '(build (linux unpack)
             (rootfs build)
             after (xsdk unpack))
     '(install)
     '(image))

(pkg 'ralink
     '(unpack)
     '(prepare)
     '(build (kernel build))
     '(install))

(pkg 'loop-aes
     '(unpack)
     '(build (kernel build))
     '(install))

(pkg 'mrua
     '(unpack)
     '(build (kernel build))
     '(modules)
     '(install (firmware unpack)))

(pkg 'chicken
     '(clean)
     '(unpack)
     '(config host
              (build)
              (install))
     '(config cross
              (build after (chicken install host))
              (install))
     '(config target
              (build after (rootfs build) (chicken install cross))
              (install (firmware unpack))))

(pkg 'chicken-eggs
     '(clean)
     '(unpack)
     '(config host
              (install (chicken install host)))
     '(config cross
              (install (chicken install cross)
                       after (chicken-eggs install host)))
     '(config target
              (install (chicken install target)
                       after
                       (chicken-eggs install cross)
                       (dbus install))))

(pkg 'ffmpeg
     '(unpack)
     '(config host
              (build)
              (install))
     '(config target
              (build after (rootfs build))
              (install (firmware unpack))))

(pkg 'soundtouch
     '(unpack)
     '(prepare)
     '(build after (rootfs build))
     '(install (firmware unpack)))

(pkg 'astindex
     '(unpack (karaoke-player unpack)))

(pkg 'karaoke-player
     '(clean)
     '(unpack)
     '(config host
              (build (astindex unpack)
                     (ffmpeg build host)
                     (chicken-eggs install host))
              (install))
     '(config target
              (build (astindex unpack)
                     (mrua build)
                     (ffmpeg install target)
                     (soundtouch install)
                     (chicken install target)
                     (chicken-eggs install cross))
              (install after (chicken-eggs install target))))

(pkg 'firmware
     '(unpack)
     '(material (mrua build))
     '(install (karaoke-player install target)) ; files/firmware/fwversion.sexp
     '(clean (firmware material)
             (mrua install)))
