// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

use std::env;
use std::path::PathBuf;

fn main() {
    let crate_dir =
        env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set - required for build");
    let output_dir = PathBuf::from(&crate_dir).join("..").join("include");

    // Create output directory if it doesn't exist
    std::fs::create_dir_all(&output_dir).expect("Failed to create output directory for C headers");

    // Generate C header
    let config =
        cbindgen::Config::from_file("cbindgen.toml").expect("Failed to read cbindgen.toml");

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_config(config)
        .generate()
        .expect("Failed to generate bindings")
        .write_to_file(output_dir.join("osxcore.h"));

    println!("cargo:rerun-if-changed=src/");
    println!("cargo:rerun-if-changed=cbindgen.toml");
}
