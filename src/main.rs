mod boot;
mod disks;
mod screens;
mod tui;
mod utils;

use screens::main::BootOption;

use nix::{sys::stat, unistd};
use std::{fmt, panic, process::Command, time::Duration};

const VERSION: &str = "v2.0.0";

fn reset_colors() {
    tui::set_bold(false);
    tui::set_underline(false);
    tui::set_bg(16);
    tui::set_fg(189);
}

fn clamp(val: usize, low: usize, high: usize) -> usize {
    if val < low {
        low
    } else if val > high {
        high
    } else {
        val
    }
}

pub fn show_selector(topleft: tui::Point, size: usize, items: Vec<String>, selected: usize) {
    let numopts = items.len();
    let low = if selected < size { 0 } else { selected - size };
    let high = clamp(selected + size, 0, numopts);
    for (i, item) in items.iter().enumerate().take(high).skip(low) {
        if i == selected {
            tui::set_bold(true);
            tui::set_underline(true);
            tui::set_fg(171);
        }
        let offset: u16 = (i - low).try_into().expect("Failed to convert i32 to u16");
        tui::move_cursor(tui::Point {
            row: topleft.row + offset,
            col: topleft.col,
        });
        print!("{}{}", if i == selected { "-> " } else { "   " }, item);
        reset_colors();
    }
}

// this is a singlethreaded app and I properly initialize and check, it should be fineeee
static mut TERMIOS_BACKUP: Option<termios::Termios> = None;

fn main() {
    let mut dev = false;
    let mut should_autoboot = false;
    let mut autoboot_partition = 0;
    if let Some(arg) = std::env::args().nth(1) {
        match arg.as_str() {
            "disks" => {
                println!("disks: {:#?}", disks::scan_for_devices());
                return;
            }
            "devices" => {
                println!(
                    "devices: {:#?}",
                    disks::scan_for_usable_root_partitions_result()
                );
                return;
            }
            "help" => {
                println!("terraOS: Boot Linux-based operating systems from a RMA shim.");
                println!("usage: terraos [disks|devices|autoboot]");
                println!("no args: starts bootloader");
                println!("disks: prints scanned disks");
                println!("devices: prints scanned root devices w/ reason");
                println!("autoboot: pass a partition number to boot it automatically");
                return;
            }
            "dev" => dev = true,
            "autoboot" => {
                if let Some(arg) = std::env::args().nth(2) {
                    if let Ok(arg) = arg.parse::<usize>() {
                        should_autoboot = true;
                        autoboot_partition = arg;
                    } else {
                        println!("autoboot: failed to parse partition number");
                        return;
                    }
                } else {
                    println!("autoboot: you must pass a partition number");
                }
            }
            &_ => {}
        }
    }
    let mut termios = tui::setup_term().expect("Failed to set up terminal.");
    let termsize = tui::get_window_size().expect("Failed to get window size.");
    let center = tui::get_center(tui::Point { row: 0, col: 0 }, termsize);

    reset_colors();
    tui::clear();
    tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);

    tui::move_cursor(tui::Point {
        row: center.row,
        col: center.col - 8 / 2,
    });
    print!("Starting");

    screens::common::show_usb_disclaimer(termsize);

    tui::flush();

    unsafe { TERMIOS_BACKUP = Some(termios) };

    panic::set_hook(Box::new(|panic_info| {
        unsafe {
            if let Some(termios) = TERMIOS_BACKUP {
                let _ = tui::destroy_term(termios);
            }
        }
        tui::set_bold(false);
        tui::set_underline(false);
        tui::set_fg(211);
        println!("terraOS encountered an error.");
        tui::set_fg(189);
        println!("backtrace: {}\n", panic_info);
        println!("terraOS will attempt to start a shell in 3 seconds.");
        std::thread::sleep(std::time::Duration::from_secs(3));
        println!("terraOS will exit after this shell closes.");
        let child = Command::new("/bin/setsid")
            .args(["-c", "/bin/bash"])
            .spawn();
        if let Ok(mut shell) = child {
            let _ = shell.wait();
        }
    }));

    if !dev {
        let kern_guid = match disks::get_kernel_uuid_from_cmdline("/proc/cmdline")
            .expect("Failed to get kernel uuid from kernel commandline.")
        {
            Some(guid) => guid,
            None => panic!("Failed to get kernel uuid from kernel commandline."),
        };

        let kern_part =
            disks::search_for_tag("PARTUUID".into(), kern_guid.clone()).unwrap_or_else(|_| {
                panic!("Failed to find kernel partition from GUID: {:?}", kern_guid)
            });

        let usb_dev = disks::get_disk_from_part(&kern_part)
            .expect("Failed to get disk from kernel partition");
        let stateful_part =
            utils::get_partition(&usb_dev, 1).expect("Failed to get partition 1 of disk");

        utils::run_fsck(&stateful_part)
            .expect("Failed to check data partition for errors");

        unistd::mkdir("/data", stat::Mode::S_IRWXU)
            .expect("Failed to create data partition mountpoint");
        // we use /bin/mount and not nix::mount::* because /bin/mount has autodetection of fstype
        utils::run_cmd("/bin/mount", &[stateful_part, "/data".into()])
            .expect("Failed to mount data partition");

        utils::run_cmd("/sbin/modprobe", &["fuse"]).expect("Failed to modprobe fuse");

        match std::fs::write("/proc/sys/kernel/loadpin/enforce", "0") {
            Ok(x) => Ok(x),
            Err(_) => std::fs::write("/proc/sys/kernel/loadpin/enabled", "0"),
        }
        .expect("Failed to disable load pinning");

        if should_autoboot {
            tui::clear();
            tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);

            tui::move_cursor(tui::Point {
                row: center.row,
                col: center.col - 47 / 2,
            });
            print!("Autobooting in 5 seconds, press any key to exit");

            screens::common::show_usb_disclaimer(termsize);

            tui::flush();

            if tui::read_char_timeout(Duration::new(5, 0)).is_none() {
                boot::boot_from_partition(
                    utils::get_partition(&usb_dev, autoboot_partition)
                        .expect("Failed to get autoboot partition"),
                    termsize,
                    "/sbin/init",
                );
            }
        }
    }

    loop {
        reset_colors();
        tui::clear();

        tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);

        let option = screens::main::show_main_selector(termsize);

        match option {
            BootOption::BootSquashfs => screens::bootsquashfs::show_screen(termsize),
            BootOption::BootPartition => screens::bootpartition::show_screen(termsize),
            BootOption::OpenShell => {
                tui::destroy_term(termios).expect("Failed to destroy terminal.");
                let mut child = Command::new("/bin/setsid")
                    .args(["-c", "/bin/bash"])
                    .spawn()
                    .expect("Failed to start shell.");
                child.wait().expect("Failed to wait for shell to finish.");
                termios = tui::setup_term().expect("Failed to set up terminal.");
            }
            BootOption::OpenInfo => screens::info::show_info(termsize),
            BootOption::Shutdown => break,
        }
    }

    tui::destroy_term(termios).expect("Failed to destroy terminal.");
}
