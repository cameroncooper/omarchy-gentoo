EAPI=8

DESCRIPTION="Optional upstream-like application set for Omarchy on Gentoo"
HOMEPAGE="https://omarchy.org"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="development media office"

RDEPEND="
	~gui-apps/omarchy-desktop-${PV}
	development? (
		app-editors/neovim
		app-misc/tmux
		app-shells/fzf
		dev-vcs/git
		sys-apps/fd
		sys-apps/ripgrep
	)
	media? (
		media-gfx/imv
		media-video/mpv
	)
	office? ( app-office/libreoffice )
"
