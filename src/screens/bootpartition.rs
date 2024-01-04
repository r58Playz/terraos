use crate::*;

pub fn show_screen(termsize: tui::Point) {
    let center = tui::get_center(tui::Point { row: 0, col: 0 }, termsize);

    tui::clear();
    tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);

    tui::move_cursor(tui::Point {
        row: center.row,
        col: center.col - 31 / 2,
    });
    print!("Searching for rootfs partitions");

    screens::common::show_usb_disclaimer(termsize);
    screens::common::show_keybinds(termsize);

    tui::flush();

    let parts = disks::scan_for_usable_root_partitions();
    let parts_readable: Vec<String> = parts
        .clone()
        .into_iter()
        .map(|d| format!("{}: {}", d.partition, d.label))
        .collect();
    let parts_len = parts.len();

    tui::clear();
    tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);

    tui::move_cursor(tui::Point {
        row: 4,
        col: center.col - 21 / 2,
    });
    print!("Boot from a partition");

    let mut selected: usize = 0;
    let mut selected_option = false;
    loop {
        tui::draw_box(
            tui::Point { row: 6, col: 4 },
            tui::Point {
                row: termsize.row - 4,
                col: termsize.col - 3,
            },
        );

        screens::common::show_usb_disclaimer(termsize);

        show_selector(
            tui::Point { row: 7, col: 5 },
            ((termsize.row - 6 - 2) / 2).into(),
            parts_readable.clone(),
            selected,
        );

        tui::flush();

        match tui::read_char() {
            '\x1b' => {
                tui::read_char();
                selected = match tui::read_char() {
                    'A' => clamp(selected - 1, 0, parts_len - 1),
                    'B' => clamp(selected + 1, 0, parts_len - 1),
                    _ => selected,
                };
            }
            '\n' => {
                selected_option = true;
                break;
            }
            '\u{7f}' => break,
            '\x08' => break,
            _ => {}
        }
    }

    if selected_option {
        boot::boot_from_partition(parts[selected].partition.clone(), termsize);
    }
}
