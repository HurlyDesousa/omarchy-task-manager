# Maintainer: Toby Swart <toby@s-w.art>
pkgname=omarchy-task-manager
pkgver=0.1.1
pkgrel=2
pkgdesc='Omarchy-themed GTK4 task manager'
arch=('any')
url='https://github.com/HurlyDesousa/omarchy-task-manager'
license=('MIT')
depends=('python' 'python-gobject' 'gtk4')
# Local files so `git clone && makepkg -si` works with no tag.
source=("omarchy-task-manager"
        "omarchy-task-manager.desktop"
        "LICENSE")
md5sums=('SKIP' 'SKIP' 'SKIP')

package() {
  install -Dm755 "$srcdir/omarchy-task-manager" "$pkgdir/usr/bin/omarchy-task-manager"
  install -Dm644 "$srcdir/omarchy-task-manager.desktop" \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  sed -i 's|^Exec=.*|Exec=/usr/bin/omarchy-task-manager|' \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
