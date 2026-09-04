EAPI=8

DESCRIPTION="Gentoo integration for the Omarchy desktop runtime"
HOMEPAGE="https://github.com/omacom/omarchy"

OMARCHY_COMMIT="4d017913d06f715da9d960021861cf535e4f15aa"
SRC_URI="https://github.com/omacom/omarchy/archive/${OMARCHY_COMMIT}.tar.gz
	-> omarchy-4.0.0_alpha_p20260901.tar.gz"
S="${WORKDIR}/omarchy-${OMARCHY_COMMIT}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

RDEPEND="
	~gui-apps/omarchy-${PV}
	app-portage/portage-utils
	app-shells/bash
	sys-apps/coreutils
	sys-apps/systemd
	sys-apps/util-linux
"

src_install() {
	local name

	# The integration package owns the public command surface. Portable
	# upstream commands remain symlinks to the immutable upstream tree.
	while IFS= read -r name; do
		[[ -n ${name} ]] || continue
		grep -qxF "${name}" "${FILESDIR}/adapted-commands.list" && continue
		grep -qxF "${name}" "${FILESDIR}/unsupported-commands.list" && continue
		dosym "../share/omarchy/bin/${name}" "/usr/bin/${name}"
	done < <(find "${S}/bin" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)

	for name in \
		omarchy-pkg-list \
		omarchy-pkg-present \
		omarchy-pkg-missing \
		omarchy-update-available \
		omarchy-version \
		omarchy-provision-first-run \
		omarchy-remove-launcher-entry \
		uwsm-app \
		xdg-terminal-exec; do
		dobin "${FILESDIR}/${name}"
	done

	exeinto /usr/libexec/omarchy-gentoo
	doexe "${FILESDIR}/omarchy-unsupported"

	while IFS= read -r name; do
		[[ -n ${name} ]] || continue
		dosym "../libexec/omarchy-gentoo/omarchy-unsupported" "/usr/bin/${name}"
	done < "${FILESDIR}/unsupported-commands.list"

	dobin "${FILESDIR}/omarchy-user-init"
	dobin "${FILESDIR}/omarchy-gentoo-session"

	insinto /usr/share/omarchy-gentoo
	doins "${FILESDIR}/package-aliases.tsv"
	doins "${FILESDIR}/unsupported-commands.list"

	insinto /etc/profile.d
	newins "${S}/etc/profile.d/omarchy.sh" omarchy.sh

	insinto /usr/share/wayland-sessions
	doins "${FILESDIR}/omarchy.desktop"
}

pkg_postinst() {
	elog "Omarchy is installed system-wide under /usr/share/omarchy."
	elog "Each user is initialized without overwriting existing files when"
	elog "they first launch the Omarchy session, or by running:"
	elog "  omarchy-user-init"
	elog
	elog "Arch package/install/update commands intentionally return a clear"
	elog "unsupported error. Portable desktop and CLI commands remain upstream."
}
