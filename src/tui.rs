use libc::{c_ushort, ioctl, STDOUT_FILENO, TIOCGWINSZ};
use std::{
    io::{stdin, stdout, Error, Read, Write},
    os::fd::AsRawFd,
};
use termios::*;
use timeout_readwrite::reader::TimeoutReader;

const BOX_TOPLEFT: &str = "┌";
const BOX_BTMLEFT: &str = "└";
const BOX_TOPRIGHT: &str = "┐";
const BOX_BTMRIGHT: &str = "┘";
const BOX_HORIZLINE: &str = "─";
const BOX_VERTLINE: &str = "│";
const PROGRESS_CHARS: &[&str] = &["▎", "▌", "▊", "█"];

pub fn setup_term() -> Result<Termios, Error> {
    let stdin_fd = stdin().as_raw_fd();
    let termios_backup = Termios::from_fd(stdin_fd)?;

    let mut termios = termios_backup;
    termios.c_lflag &= !(ECHO | ICANON);

    tcsetattr(stdin_fd, TCSANOW, &termios)?;

    print!("\x1b[?1049h"); // enter alt screen
    print!("\x1b[?25l"); // hide cursor
    clear();
    print!("\x1b[H"); // move cursor to home position
    flush();

    Ok(termios_backup)
}

pub fn destroy_term(termios: Termios) -> Result<(), Error> {
    tcsetattr(stdin().as_raw_fd(), TCSANOW, &termios)?;
    print!("\x1b[?1049l"); // leave alt screen
    print!("\x1b[?25h"); // show cursor
    clear();
    print!("\x1b[H"); // move cursor to home position
    flush();

    Ok(())
}

#[repr(C)]
struct Winsize {
    ws_row: c_ushort,
    ws_col: c_ushort,
    ws_xpixel: c_ushort,
    ws_ypixel: c_ushort,
}

#[derive(Copy, Clone, Debug)]
pub struct Point {
    pub row: u16,
    pub col: u16,
}

pub fn get_window_size() -> Result<Point, i32> {
    let winsize = Winsize {
        ws_row: 0,
        ws_col: 0,
        ws_xpixel: 0,
        ws_ypixel: 0,
    };
    let ret = unsafe { ioctl(STDOUT_FILENO, TIOCGWINSZ, &winsize) };
    match ret {
        0 => Ok(Point {
            row: winsize.ws_row,
            col: winsize.ws_col,
        }),
        _ => Err(-1),
    }
}

pub fn flush() {
    let _ = stdout().flush();
}

pub fn clear() {
    print!("\x1b[2J");
}

pub fn set_fg(color: u8) {
    print!("\x1b[38;5;{}m", color);
}

pub fn set_bg(color: u8) {
    print!("\x1b[48;5;{}m", color);
}

pub fn set_bold(bold: bool) {
    print!("\x1b[{}m", if bold { 1 } else { 22 });
}

pub fn set_underline(underline: bool) {
    print!("\x1b[{}m", if underline { 4 } else { 24 });
}

pub fn move_cursor(point: Point) {
    print!("\x1b[{};{}f", point.row, point.col);
}

pub fn draw_box(topleft: Point, bottomright: Point) {
    // 4 corners: (row, col), (row,col+cols), (row+rows,col) (row+rows,col+cols)
    // draw lines between them
    for r in topleft.row..bottomright.row {
        move_cursor(Point {
            row: r,
            col: topleft.col,
        });
        print!("{}", BOX_VERTLINE);
        move_cursor(Point {
            row: r,
            col: bottomright.col,
        });
        print!("{}", BOX_VERTLINE);
    }
    for c in topleft.col..bottomright.col {
        move_cursor(Point {
            row: topleft.row,
            col: c,
        });
        print!("{}", BOX_HORIZLINE);
        move_cursor(Point {
            row: bottomright.row,
            col: c,
        });
        print!("{}", BOX_HORIZLINE);
    }
    move_cursor(topleft);
    print!("{}", BOX_TOPLEFT);
    move_cursor(Point {
        row: topleft.row,
        col: bottomright.col,
    });
    print!("{}", BOX_TOPRIGHT);
    move_cursor(Point {
        row: bottomright.row,
        col: topleft.col,
    });
    print!("{}", BOX_BTMLEFT);
    move_cursor(bottomright);
    print!("{}", BOX_BTMRIGHT);
}

pub fn draw_progress(topleft: Point, progress: usize) {
    draw_box(
        topleft,
        Point {
            row: topleft.row + 2,
            col: topleft.col + 27,
        },
    );
    let mut bar = String::new();
    bar.push_str(&PROGRESS_CHARS[3].repeat(progress / 4));
    if progress % 4 != 0 {
        bar.push_str(PROGRESS_CHARS[progress % 4]);
    }
    move_cursor(Point {
        row: topleft.row + 1,
        col: topleft.col + 1,
    });
    print!("{}", bar);
}

pub fn get_center(p1: Point, p2: Point) -> Point {
    Point {
        row: (p2.row - p1.row) / 2,
        col: (p2.col - p1.col) / 2,
    }
}

pub fn read_char() -> char {
    stdin().bytes().next().unwrap().unwrap() as char
}

pub fn read_char_timeout(duration: std::time::Duration) -> Option<char> {
    TimeoutReader::new(stdin(), duration)
        .bytes()
        .next()
        .and_then(|x| x.ok())
        .map(char::from)
}
