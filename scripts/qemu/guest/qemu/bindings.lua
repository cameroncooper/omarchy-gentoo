-- QEMU Cocoa does not reliably forward Command as Super. Keep upstream
-- bindings and add host-keyboard fallbacks only in the disposable VM.
o.bind("ALT + SPACE", "Omarchy menu (QEMU)", "omarchy-menu toggle")
o.bind("ALT + RETURN", "Terminal (QEMU)", { omarchy = "terminal" })
