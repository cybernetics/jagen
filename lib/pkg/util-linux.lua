package {
    name   = 'util-linux',
    source = 'util-linux-2.23.2.tar.xz',
    patches = {
        { 'util-linux-2.23.2', 1 }
    },
    build = {
        type = 'GNU',
        autoreconf = true,
        options = {
            '--enable-shared',
            '--disable-static',
            '--disable-rpath',
            '--disable-most-builds',
            '--disable-libuuid',
            '--enable-libblkid',
            '--enable-libmount',
            '--disable-mount',
            '--enable-losetup',
            '--disable-cytune',
            '--disable-fsck',
            '--disable-partx',
            '--disable-uuidd',
            '--disable-mountpoint',
            '--disable-fallocate',
            '--disable-unshare',
            '--disable-nsenter',
            '--disable-setpriv',
            '--disable-eject',
            '--disable-agetty',
            '--disable-cramfs',
            '--disable-bfs',
            '--disable-fdformat',
            '--disable-hwclock',
            '--disable-wdctl',
            '--disable-switch_root',
            '--disable-pivot_root',
            '--disable-elvtune',
            '--disable-tunelp',
            '--disable-kill',
            '--disable-last',
            '--disable-utmpdump',
            '--disable-line',
            '--disable-mesg',
            '--disable-raw',
            '--disable-rename',
            '--disable-reset',
            '--disable-vipw',
            '--disable-newgrp',
            '--disable-chfn-chsh',
            '--disable-login',
            '--disable-sulogin',
            '--disable-su',
            '--disable-runuser',
            '--disable-ul',
            '--disable-more',
            '--disable-pg',
            '--disable-setterm',
            '--disable-schedutils',
            '--disable-wall',
            '--disable-write',
            '--disable-socket-activation',
            '--disable-bash-completion',
            '--disable-pg-bell',
            '--disable-makeinstall-chown',
            '--disable-makeinstall-setuid',
            '--without-selinux',
            '--without-audit',
            '--without-udev',
            '--without-ncurses',
            '--without-slang',
            '--without-utempter'
        }
    }
}
