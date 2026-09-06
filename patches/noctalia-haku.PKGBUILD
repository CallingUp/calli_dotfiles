pkgname=noctalia-haku
pkgver=5.0.0_beta.10.haku1
pkgrel=10
pkgdesc='Noctalia beta 10 with centered compact media panel'
arch=('x86_64')
url='https://github.com/noctalia-dev/noctalia'
license=('MIT')
depends=(
  bash cairo curl fontconfig freetype2 glib2 harfbuzz libical libjxl
  libpipewire libqalculate librsvg libsecret libsndfile libsodium libwebp
  libwireplumber libxkbcommon libxml2 md4c pam pango polkit sdbus-cpp
  tomlplusplus wayland
)
provides=('noctalia=5.0.0_beta.10')
conflicts=('noctalia')
options=('!debug' '!strip')

package() {
  DESTDIR="$pkgdir" meson install \
    -C /home/calli/build/noctalia-haku/build-release \
    --no-rebuild
}
