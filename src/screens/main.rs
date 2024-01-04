use crate::*;

#[derive(Debug, PartialEq)]
pub enum BootOption {
    BootSquashfs = 0,
    BootPartition,
    OpenShell,
    OpenInfo,
    Shutdown,
}

impl BootOption {
    fn up(&self) -> Self {
        use BootOption::*;
        match *self {
            BootSquashfs => Shutdown,
            OpenShell => BootSquashfs,
            Shutdown => OpenShell,
            BootPartition => OpenInfo,
            OpenInfo => BootPartition,
        }
    }
    fn down(&self) -> Self {
        use BootOption::*;
        match *self {
            BootSquashfs => OpenShell,
            OpenShell => Shutdown,
            Shutdown => BootSquashfs,
            BootPartition => OpenInfo,
            OpenInfo => BootPartition,
        }
    }
    fn left(&self) -> Self {
        use BootOption::*;
        match *self {
            BootSquashfs => BootPartition,
            BootPartition => BootSquashfs,
            OpenShell => OpenInfo,
            OpenInfo => OpenShell,
            Shutdown => Shutdown,
        }
    }
    fn right(&self) -> Self {
        use BootOption::*;
        match *self {
            BootSquashfs => BootPartition,
            BootPartition => BootSquashfs,
            OpenShell => OpenInfo,
            OpenInfo => OpenShell,
            Shutdown => Shutdown,
        }
    }
}

impl fmt::Display for BootOption {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        use BootOption::*;
        match self {
            BootSquashfs => write!(f, "Boot a squashfs file"),
            BootPartition => write!(f, "Boot a partition"),
            OpenShell => write!(f, "Start a shell"),
            OpenInfo => write!(f, "View licensing, version, and other info"),
            Shutdown => write!(f, "Shut down"),
        }
    }
}

fn draw_main_left_box(
    center: tui::Point,
    row: u16,
    col: u16,
    height: u16,
    text: String,
    selected: bool,
) {
    reset_colors();
    if selected {
        tui::set_fg(171);
    }
    tui::draw_box(
        tui::Point { row, col },
        tui::Point {
            row: row + height,
            col: center.col - col,
        },
    );

    tui::move_cursor(tui::Point {
        row: row + height / 2,
        col: col + 2,
    });

    print!("{}", text);

    reset_colors();
}

fn draw_main_right_box(
    center: tui::Point,
    termsize: tui::Point,
    row: u16,
    col: u16,
    height: u16,
    text: String,
    selected: bool,
) {
    reset_colors();
    if selected {
        tui::set_fg(171);
    }

    tui::draw_box(
        tui::Point {
            row,
            col: center.col + col,
        },
        tui::Point {
            row: row + height,
            col: termsize.col - col,
        },
    );

    tui::move_cursor(tui::Point {
        row: row + height / 2,
        col: center.col + col + 2,
    });

    print!("{}", text);

    reset_colors();
}

pub fn show_main_selector(termsize: tui::Point) -> BootOption {
    let center = tui::get_center(tui::Point { row: 0, col: 0 }, termsize);

    let mut selected = BootOption::BootSquashfs;

    loop {
        tui::move_cursor(tui::Point {
            row: 4,
            col: center.col - 8,
        });
        print!("terraOS bootloader");

        draw_main_left_box(
            center,
            8,
            8,
            4,
            BootOption::BootSquashfs.to_string(),
            selected == BootOption::BootSquashfs,
        );
        draw_main_right_box(
            center,
            termsize,
            8,
            8,
            4,
            BootOption::BootPartition.to_string(),
            selected == BootOption::BootPartition,
        );
        draw_main_left_box(
            center,
            14,
            8,
            4,
            BootOption::OpenShell.to_string(),
            selected == BootOption::OpenShell,
        );
        draw_main_right_box(
            center,
            termsize,
            14,
            8,
            4,
            BootOption::OpenInfo.to_string(),
            selected == BootOption::OpenInfo,
        );
        draw_main_left_box(
            center,
            20,
            8,
            4,
            BootOption::Shutdown.to_string(),
            selected == BootOption::Shutdown,
        );

        screens::common::show_usb_disclaimer(termsize);
        screens::common::show_keybinds(termsize);

        tui::flush();

        match tui::read_char() {
            '\x1b' => {
                tui::read_char();
                selected = match tui::read_char() {
                    'A' => selected.up(),
                    'B' => selected.down(),
                    'C' => selected.left(),
                    'D' => selected.right(),
                    _ => selected,
                };
            }
            '\n' => break,
            '\x08' => break,
            _ => {}
        }
    }

    selected
}
