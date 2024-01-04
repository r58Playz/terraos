use crate::*;

fn show_license(topleft: tui::Point) {
    let license = [
        "r58Playz/terraos: Boot Linux-based operating systems from a RMA shim.",
        "",
        "Copyright (C) 2023 r58Playz",
        "",
        "This program is free software: you can redistribute it and/or modify",
        "it under the terms of the GNU General Public License as published by",
        "the Free Software Foundation, either version 3 of the License, or",
        "(at your option) any later version.",
        "",
        "This program is distributed in the hope that it will be useful,",
        "but WITHOUT ANY WARRANTY; without even the implied warranty of",
        "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the",
        "GNU General Public License for more details.",
        "",
        "You should have received a copy of the GNU General Public License",
        "along with this program.  If not, see <https://www.gnu.org/licenses/>.",
    ];
    for (offset, line) in license.iter().enumerate() {
        tui::move_cursor(tui::Point { row: topleft.row + (offset as u16), col: topleft.col });
        print!("{}", line);
    }
}

fn show_other_info(topleft: tui::Point) {
    let version = format!("This is terraOS version {VERSION}.");
    let other_info = [
        version.as_str(),
        "",
        "Press any key to exit."
    ];
    for (offset, line) in other_info.iter().enumerate() {
        tui::move_cursor(tui::Point { row: topleft.row + (offset as u16), col: topleft.col });
        print!("{}", line);
    }

}

pub fn show_info(termsize: tui::Point) {
    let center = tui::get_center(tui::Point { row: 0, col: 0 }, termsize);

    tui::clear();
    tui::draw_box(tui::Point { row: 0, col: 0 }, termsize);
    
    let license_center = tui::get_center(tui::Point { row: 0, col: 0 }, center);
    tui::move_cursor(tui::Point { row: 4, col: license_center.col - 3 });
    tui::set_bold(true);
    print!("License");
    tui::set_bold(false);
    show_license(tui::Point { row: 6, col: 4 });

    let other_center = tui::Point { row: 0, col: center.col + license_center.col };
    tui::move_cursor(tui::Point { row: 4, col: other_center.col - 2 });
    tui::set_bold(true);
    print!("Other");
    tui::set_bold(false);
    show_other_info(tui::Point { row: 6, col: center.col + 4 });

    screens::common::show_usb_disclaimer(termsize);

    tui::flush();
    tui::read_char();
}
