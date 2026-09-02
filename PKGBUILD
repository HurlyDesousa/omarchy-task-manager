# Maintainer: Toby Swart
pkgname=omarchy-task-manager
pkgver=0.1.0
pkgrel=1
pkgdesc="GTK4 CPU, temperature, fan, and process monitor for Omarchy"
arch=('any')
url="https://github.com/HurlyDesousa/omarchy-task-manager"
license=('MIT')
depends=('python' 'python-gobject' 'gtk4')
source=("omarchy-task-manager" "omarchy-task-manager.desktop")
md5sums=('SKIP' 'SKIP')

package() {
  install -Dm755 "${srcdir}/omarchy-task-manager" "${pkgdir}/usr/bin/omarchy-task-manager"
  install -Dm644 "${srcdir}/omarchy-task-manager.desktop" \
    "${pkgdir}/usr/share/applications/omarchy-task-manager.desktop"
}
