use std::ffi::OsStr;
use std::io::{Error, Result};
use std::process::{Command, Stdio};
use std::str::from_utf8;

pub fn run_cmd<S: AsRef<OsStr>>(cmd: &str, args: &[S]) -> Result<()> {
    let output = Command::new(cmd)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()?;
    if output.status.success() {
        Ok(())
    } else {
        Err(Error::other(format!(
            "Failed to execute process. code {:?} stdout: `{}` stderr: `{}`",
            output.status.code(),
            from_utf8(&output.stdout).unwrap_or("not valid utf8"),
            from_utf8(&output.stderr).unwrap_or("not valid utf8"),
        )))
    }
}

pub fn run_fsck(part: &str) -> Result<()> {
    let output = Command::new("/sbin/fsck")
        .args(["-p", part])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()?;
    let exit_code = output.status.code().unwrap_or(255);
    if exit_code == 0 || exit_code == 1 {
        // 0 = no errors
        // 1 = errors fixed
        Ok(())
    } else {
        Err(Error::other(format!(
            "Failed to execute process. code {:?} stdout: `{}` stderr: `{}`",
            output.status.code(),
            from_utf8(&output.stdout).unwrap_or("not valid utf8"),
            from_utf8(&output.stderr).unwrap_or("not valid utf8"),
        )))
    }
}

pub fn get_partition(disk: &str, num: usize) -> Option<String> {
    if disk.chars().last()?.is_ascii_digit() {
        Some(format!("{}p{}", disk, num))
    } else {
        Some(format!("{}{}", disk, num))
    }
}
