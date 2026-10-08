//! Native Cursor skill deployment entrypoint.

use lps_tools::cursor_skills::{execute, parse};

/// Parse process arguments and delegate filesystem operations.
/// Parameters: none; raw tokens come from process arguments.
/// Returns: None; exits with operation status or two for invalid arguments.
fn main() {
    let args = std::env::args().skip(1).collect::<Vec<_>>();
    let status = match parse(&args) {
        Ok(options) => match execute(options) {
            Ok(status) => status,
            Err(error) => {
                eprintln!("cursor-skills: {error}");
                1
            }
        },
        Err(error) => {
            eprintln!("{error}");
            2
        }
    };
    std::process::exit(status);
}
