# Omarchy-Gentoo harness shortcuts
.PHONY: fetch create seed phase-a desktop phase-b phase-b-fresh phase-c gui reset ssh stop status assert qa

fetch:
	./scripts/qemu/fetch-artifacts.sh

create:
	./scripts/qemu/create-vm.sh

seed:
	./scripts/qemu/build-seed.sh

phase-a:
	./scripts/qemu/phase-a.sh --skip-fetch

desktop:
	./scripts/qemu/desktop.sh

phase-b:
	./scripts/qemu/desktop.sh

phase-b-fresh:
	./scripts/qemu/desktop.sh --from-golden

phase-c:
	./scripts/qemu/desktop.sh

gui:
	./scripts/qemu/start-gui.sh

reset:
	./scripts/qemu/phase-a.sh --reset --skip-fetch

ssh:
	./scripts/qemu/vm.sh ssh

stop:
	./scripts/qemu/vm.sh stop

status:
	./scripts/qemu/vm.sh status

assert:
	./scripts/qemu/assert-phase-a.sh

qa:
	./scripts/tests/verify-overlay.sh
