//! Native Continue config/query entrypoint.

use lps_tools::continue_tools::{execute, parse};

/// Parse arguments and delegate all configuration/query work.
/// Parameters: none; command tokens come from process arguments.
/// Returns: None; exits with operation status, one on failure, two for usage.
fn main() {
    let args = std::env::args().skip(1).collect::<Vec<_>>();
    let status = match parse(&args) {
        Ok(command) => match execute(command) {
            Ok((text, status)) => {
                print!("{text}");
                status
            }
            Err(error) => {
                eprintln!("continue-tools: {error}");
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
