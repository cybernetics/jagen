package { 'make', 'host',
    source = 'make-3.81.tar.bz2'
}

package { 'android',
    { 'build',
        { 'make', 'build', 'host' }
    }
}