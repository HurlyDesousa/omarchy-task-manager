# Maintainer: Toby Swart <toby@s-w.art>
pkgname=omarchy-task-manager
pkgver=0.5.5
pkgrel=1
pkgdesc='Omarchy-themed GTK4 task manager with Quickshell bar widget'
arch=('any')
url='https://github.com/HurlyDesousa/omarchy-task-manager'
license=('MIT')
depends=('python' 'python-gobject' 'gtk4')
# Local files so `git clone && makepkg -si` works with no tag.
source=("omarchy-task-manager"
        "omarchy-task-manager-toggle"
        "omarchy-task-manager-waybar"
        "omarchy-task-manager.desktop"
        "shell/sw.art.task-manager/manifest.json"
        "shell/sw.art.task-manager/BarWidget.qml"
        "LICENSE")
# kbd-backlight QML files share the basename "manifest.json" with the task-manager
# plugin, so they are NOT listed in source[] (which copies by basename into $srcdir).
# They are installed directly from $startdir (the repo root) in package() instead.
md5sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')

package() {
  install -Dm755 "$srcdir/omarchy-task-manager"        "$pkgdir/usr/bin/omarchy-task-manager"
  install -Dm755 "$srcdir/omarchy-task-manager-toggle"  "$pkgdir/usr/bin/omarchy-task-manager-toggle"
  install -Dm755 "$srcdir/omarchy-task-manager-waybar"  "$pkgdir/usr/bin/omarchy-task-manager-waybar"
  install -Dm644 "$srcdir/omarchy-task-manager.desktop" \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  sed -i 's|^Exec=.*|Exec=/usr/bin/omarchy-task-manager|' \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  install -Dm644 "$srcdir/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.task-manager/manifest.json"
  install -Dm644 "$srcdir/BarWidget.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.task-manager/BarWidget.qml"
  # kbd-backlight plugin — installed from $startdir to avoid basename collision in $srcdir.
  install -Dm644 "$startdir/shell/sw.art.kbd-backlight/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.kbd-backlight/manifest.json"
  install -Dm644 "$startdir/shell/sw.art.kbd-backlight/KbdBacklight.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.kbd-backlight/KbdBacklight.qml"
  install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
