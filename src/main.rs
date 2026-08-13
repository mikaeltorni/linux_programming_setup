//! `lps-tools` — installer-facing helpers for linux-programming-setup.
//!
//! Usage (matches the former `lib/gsettings_strv.py` contract):
//!
//! ```text
//! CURRENT="@as ['one']" lps-tools two
//! # -> ['one', 'two']
//! ```

mod gsettings_strv;
mod logging;

fn main() {
    std::process::exit(gsettings_strv::run_cli());
}
