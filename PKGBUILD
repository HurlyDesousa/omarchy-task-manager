# Maintainer: Toby Swart <toby@s-w.art>
pkgname=omarchy-task-manager
pkgver=0.5.2
pkgrel=1
pkgdesc='Omarchy-themed GTK4 task manager'
arch=('any')
url='https://github.com/HurlyDesousa/omarchy-task-manager'
license=('MIT')
depends=('python' 'python-gobject' 'gtk4')
# Local files so `git clone && makepkg -si` works with no tag.
source=("omarchy-task-manager"
        "omarchy-task-manager-toggle"
        "omarchy-task-manager-waybar"
        "omarchy-task-manager.desktop"
        "LICENSE")
md5sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')

package() {
  install -Dm755 "$srcdir/omarchy-task-manager"        "$pkgdir/usr/bin/omarchy-task-manager"
  install -Dm755 "$srcdir/omarchy-task-manager-toggle"  "$pkgdir/usr/bin/omarchy-task-manager-toggle"
  install -Dm755 "$srcdir/omarchy-task-manager-waybar"  "$pkgdir/usr/bin/omarchy-task-manager-waybar"
  install -Dm644 "$srcdir/omarchy-task-manager.desktop" \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  sed -i 's|^Exec=.*|Exec=/usr/bin/omarchy-task-manager|' \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
