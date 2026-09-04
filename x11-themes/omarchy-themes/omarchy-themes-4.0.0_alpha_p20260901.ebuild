EAPI=8

DESCRIPTION="Official themes and wallpapers for Omarchy"
HOMEPAGE="https://omarchy.org https://github.com/omacom/omarchy"

OMARCHY_COMMIT="4d017913d06f715da9d960021861cf535e4f15aa"
SRC_URI="https://github.com/omacom/omarchy/archive/${OMARCHY_COMMIT}.tar.gz
	-> omarchy-4.0.0_alpha_p20260901.tar.gz"
S="${WORKDIR}/omarchy-${OMARCHY_COMMIT}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="~gui-apps/omarchy-${PV}"

src_install() {
	insinto /usr/share/omarchy
	doins -r themes
}
