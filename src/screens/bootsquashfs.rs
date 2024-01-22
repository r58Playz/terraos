use crate::*;

pub fn show_screen(termsize: tui::Point) {
    let center = tui::get_center(tui::Point { row: 0, col: 0 }, termsize);

    tui::clear();
    tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);

    tui::move_cursor(tui::Point {
        row: center.row,
        col: center.col - 28 / 2,
    });
    print!("Searching for squashfs files");

    screens::common::show_usb_disclaimer(termsize);
    screens::common::show_boot_keybinds(termsize);

    tui::flush();

    let files = disks::get_squashfs_files_in_directory("/data/").expect("Failed to get files in data directory");
    let files_len = files.len();

    tui::clear();
    tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);

    tui::move_cursor(tui::Point {
        row: 4,
        col: center.col - 20 / 2,
    });
    print!("Boot from a squashfs");

    let mut selected: usize = 0;
    let mut selected_option = false;
    let mut init_cmd = "/sbin/init";
    loop {
        tui::draw_box(
            tui::Point { row: 6, col: 4 },
            tui::Point {
                row: termsize.row - 4,
                col: termsize.col - 3,
            },
        );

        screens::common::show_usb_disclaimer(termsize);
        screens::common::show_boot_keybinds(termsize);

        show_selector(
            tui::Point { row: 7, col: 5 },
            ((termsize.row - 6 - 2) / 2).into(),
            files.clone(),
            selected,
        );

        tui::flush();

        match tui::read_char() {
            '\x1b' => {
                tui::read_char();
                selected = match tui::read_char() {
                    'A' => clamp(selected - 1, 0, files_len - 1),
                    'B' => clamp(selected + 1, 0, files_len - 1),
                    _ => selected,
                };
            }
            '\n' => {
                selected_option = true;
                break;
            },
            'd' => {
                selected_option = true;
                init_cmd = "/bin/bash";
                break;
            }
            '\u{7f}' => break,
            '\x08' => break,
            _ => {}
        }
    }

    if selected_option {
        boot::boot_from_squashfs(format!("/data/{}", files[selected]), termsize, init_cmd);
    }
}
