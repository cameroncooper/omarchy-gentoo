-- QEMU test hardware only. This is a user monitor override, not an Omarchy
-- desktop fork.
hl.monitor({
  output = "Virtual-1",
  mode = "1280x768@60",
  position = "0x0",
  scale = 1,
})

hl.env("GDK_SCALE", "1")
