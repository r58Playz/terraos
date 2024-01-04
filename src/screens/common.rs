use crate::*;

pub fn show_usb_disclaimer(termsize: tui::Point) {
    tui::move_cursor(tui::Point { row: termsize.row - 1, col: termsize.col - 41 });
    print!("Please keep the terraOS drive plugged in.");
}

pub fn show_keybinds(termsize: tui::Point) {
    tui::move_cursor(tui::Point {row: termsize.row - 1, col: 2});
    print!("Use the arrow keys to move, ENTER to select, and BACKSPACE to go back.");
}
