use std::ffi::OsStr;
use std::io::Error;
use std::process::{Command, Stdio};

pub fn run_cmd<S: AsRef<OsStr>>(cmd: &str, args: &[S]) -> std::io::Result<()> {
    let status = Command::new(cmd)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;
    if status.success() {
        Ok(())
    } else {
        Err(Error::other(format!(
            "Failed - exitcode: {:?}",
            status.code()
        )))
    }
}
