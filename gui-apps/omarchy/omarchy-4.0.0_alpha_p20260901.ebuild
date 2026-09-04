EAPI=8

DESCRIPTION="Pinned upstream Omarchy desktop runtime"
HOMEPAGE="https://omarchy.org https://github.com/omacom/omarchy"

OMARCHY_COMMIT="4d017913d06f715da9d960021861cf535e4f15aa"
SRC_URI="https://github.com/omacom/omarchy/archive/${OMARCHY_COMMIT}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/omarchy-${OMARCHY_COMMIT}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="
	app-misc/jq
	app-shells/bash
"

PATCHES=(
	"${FILESDIR}/${P}-distro-package-guards.patch"
)

src_install() {
	local runtime_entries=(
		agents
		applications
		bin
		config
		default
		docs
		etc
		icon.png
		icon.txt
		install
		LICENSE
		logo.svg
		logo.txt
		manual
		migrations
		plans
		shell
		version
	)

	dodir /usr/share/omarchy
	cp -a "${runtime_entries[@]}" "${ED}/usr/share/omarchy/" || die

	# Themes are split so administrators can install or replace the runtime
	# independently without creating file ownership collisions.
	dodoc README.md
}
