#!/usr/bin/env expect
# Drive the Gentoo livecd serial console through autoinstall, then exit when QEMU ends.
# Usage: phase-a-expect.tcl <qemu-argfile> <serial-log> <http-port>

set timeout -1
set argfile [lindex $argv 0]
set seriallog [lindex $argv 1]

if {![file exists $argfile]} {
  puts "missing qemu argfile: $argfile"
  exit 1
}

# Read NUL-separated qemu args
set fh [open $argfile r]
fconfigure $fh -translation binary
set data [read $fh]
close $fh
set qemu_args [split $data "\0"]
# drop trailing empty from final NUL
if {[lindex $qemu_args end] eq ""} {
  set qemu_args [lrange $qemu_args 0 end-1]
}

log_file -noappend $seriallog
puts "spawning qemu with [llength $qemu_args] args"
set cmd [lindex $qemu_args 0]
set args [lrange $qemu_args 1 end]
spawn $cmd {*}$args

proc mount_seed {} {
  # Try common seed device nodes / ISO label
  send "mkdir -p /mnt/seed\r"
  expect -re {# ?$}
  send "for d in /dev/disk/by-label/OMGSEED /dev/sr1 /dev/sr0 /dev/vdb /dev/vdc; do if \[ -e \"\$d\" \]; then mount \"\$d\" /mnt/seed && break; fi; done; ls /mnt/seed; cat /mnt/seed/install.env\r"
  expect -re {# ?$}
}

# Wait for a live shell. Avoid matching the word "login" in the MOTD.
expect {
  -re {livecd login:} {
    send "root\r"
    exp_continue
  }
  -re {Password:} {
    send "\r"
    exp_continue
  }
  -re {root@livecd[^\r\n]*# ?$} {}
  -re {livecd[^\r\n]*# ?$} {}
  timeout {
    puts "TIMEOUT waiting for livecd shell"
    exit 2
  }
  eof {
    puts "QEMU exited before livecd shell"
    exit 3
  }
}

puts "got livecd shell; mounting seed and starting autoinstall"
mount_seed

send "bash /mnt/seed/autoinstall.sh\r"

expect {
  -re {PHASE_A_INSTALL_COMPLETE} {
    puts "autoinstall signaled completion"
  }
  -re {PHASE_A_INSTALL_FAILED} {
    puts "autoinstall FAILED"
    exit 5
  }
  eof {
    puts "QEMU exited during autoinstall (may be poweroff)"
  }
  timeout {
    puts "TIMEOUT during autoinstall"
    exit 4
  }
}

# Wait for qemu process to leave
catch {expect eof}
puts "expect done"
exit 0
