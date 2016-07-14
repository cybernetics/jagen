return {
    source = {
        type = 'dist',
        location = 'https://www.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.43.1/e2fsprogs-1.43.1.tar.xz',
        sha256sum = '97e36a029224e2606baa6e9ea693b04a4d192ccd714572a1b50a2df9c687b23d'
    },
    patches = {
        -- borrowed from Gentoo
        { 'e2fsprogs-1.41.8-makefile', 1 },
        { 'e2fsprogs-1.42.13-fix-build-cflags', 1 },
        { 'e2fsprogs-1.43-sysmacros', 1 },
    },
    build = {
        type    = 'GNU',
        options = {
            '--enable-symlink-install',
            '--enable-relative-symlinks',
            '--disable-testio-debug',
            '--disable-backtrace',
            '--disable-debugfs',
            '--disable-imager',
            '--disable-resizer',
            '--disable-defrag',
            '--disable-fsck',
            '--disable-e2initrd-helper',
            '--disable-uuidd',
            '--disable-rpath',
            '--disable-fuse2fs',
        }
    }
}
