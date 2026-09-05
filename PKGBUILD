# Maintainer: Toby Swart <toby@s-w.art>
pkgname=omarchy-task-manager
pkgver=0.5.5
pkgrel=29
pkgdesc='Omarchy Task Manager Quickshell KeyboardPanel with stats backend'
arch=('any')
url='https://github.com/HurlyDesousa/omarchy-task-manager'
license=('MIT')
depends=('python')
source=("omarchy-task-manager"
        "omarchy-task-manager-toggle"
        "omarchy-task-manager-waybar"
        "omarchy-task-manager.desktop"
        "shell/sw.art.task-manager/manifest.json"
        "shell/sw.art.task-manager/BarWidget.qml"
        "shell/sw.art.task-manager/Panel.qml"
        "LICENSE")
md5sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')

package() {
  install -Dm755 "$srcdir/omarchy-task-manager"        "$pkgdir/usr/bin/omarchy-task-manager"
  install -Dm755 "$srcdir/omarchy-task-manager-toggle"  "$pkgdir/usr/bin/omarchy-task-manager-toggle"
  install -Dm755 "$srcdir/omarchy-task-manager-waybar"  "$pkgdir/usr/bin/omarchy-task-manager-waybar"
  install -Dm644 "$srcdir/omarchy-task-manager.desktop" \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  sed -i 's|^Exec=.*|Exec=/usr/bin/omarchy-task-manager-toggle|' \
    "$pkgdir/usr/share/applications/omarchy-task-manager.desktop"
  install -Dm644 "$srcdir/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.task-manager/manifest.json"
  install -Dm644 "$srcdir/BarWidget.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.task-manager/BarWidget.qml"
  install -Dm644 "$srcdir/Panel.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.task-manager/Panel.qml"
  install -Dm644 "$startdir/shell/sw.art.kbd-backlight/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.kbd-backlight/manifest.json"
  install -Dm644 "$startdir/shell/sw.art.kbd-backlight/KbdBacklight.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.kbd-backlight/KbdBacklight.qml"
  # AI tray plugins — installed from $startdir (manifest.json basename collision).
  install -Dm644 "$startdir/shell/sw.art.cursor/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.cursor/manifest.json"
  install -Dm644 "$startdir/shell/sw.art.cursor/BarWidget.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.cursor/BarWidget.qml"
  install -Dm644 "$startdir/shell/sw.art.pi-local/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.pi-local/manifest.json"
  install -Dm644 "$startdir/shell/sw.art.pi-local/BarWidget.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.pi-local/BarWidget.qml"
  install -Dm644 "$startdir/shell/sw.art.grok/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.grok/manifest.json"
  install -Dm644 "$startdir/shell/sw.art.grok/BarWidget.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.grok/BarWidget.qml"
  install -Dm644 "$startdir/shell/sw.art.ai-usage/manifest.json" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.ai-usage/manifest.json"
  install -Dm644 "$startdir/shell/sw.art.ai-usage/BarWidget.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.ai-usage/BarWidget.qml"
  install -Dm644 "$startdir/shell/sw.art.ai-usage/Panel.qml" \
    "$pkgdir/usr/share/omarchy/plugins/sw.art.ai-usage/Panel.qml"
  install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
