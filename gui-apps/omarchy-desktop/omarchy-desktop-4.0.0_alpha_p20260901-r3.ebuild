EAPI=8

DESCRIPTION="Minimal Omarchy desktop environment for Gentoo"
HOMEPAGE="https://omarchy.org"

LICENSE="metapackage"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="+bluetooth +networkmanager +notifications +policykit +screencast"

RDEPEND="
	~gui-apps/omarchy-${PV}
	~gui-apps/omarchy-gentoo-${PV}
	~x11-themes/omarchy-themes-${PV}
	app-misc/jq
	<dev-libs/hyprgraphics-9999
	<dev-libs/hyprlang-9999
	dev-qt/qtimageformats:6
	gui-apps/foot
	>=gui-apps/quickshell-0.3[policykit?]
	<gui-apps/quickshell-0.4
	gui-apps/wl-clipboard
	<gui-libs/aquamarine-9999
	<gui-libs/hyprcursor-9999
	<gui-libs/hyprland-guiutils-9999
	<gui-libs/hyprtoolkit-9999
	<gui-libs/hyprutils-9999
	<gui-libs/hyprwire-9999
	<gui-libs/xdg-desktop-portal-hyprland-9999
	>=gui-wm/hyprland-0.56
	<gui-wm/hyprland-0.57
	media-fonts/jetbrains-mono
	media-fonts/noto
	media-fonts/symbols-nerd-font
	media-video/pipewire
	media-video/wireplumber
	>=dev-libs/wayland-1.25
	sys-apps/dbus
	sys-apps/xdg-desktop-portal
	sys-apps/xdg-desktop-portal-gtk
	x11-themes/adwaita-icon-theme
	bluetooth? ( net-wireless/bluez )
	networkmanager? ( net-misc/networkmanager )
	notifications? ( x11-libs/libnotify )
	policykit? ( sys-auth/polkit )
	screencast? (
		gui-apps/grim
		gui-apps/slurp
	)
"

BDEPEND="
	<dev-libs/hyprland-protocols-9999
	<dev-util/hyprwayland-scanner-9999
"
