---
layout: post
title: "VSCode for Rust"
date: 2022-12-3 05:31:01 -0700
categories: ide vs-code rust
---

# History

I am primarily a Rust developer, and every time I have tried to transition to VSCode, I have found VSC features
inferior to CLion. However, VSC has progressed, and I am finally (attempting) to remove CLion/IntelliJ from my professional workflow altogether.

## Rust Developer Experience

I was told on Discord several months ago that the primary developer of the [IntelliJ Rust Plugin](https://github.com/intellij-rust/intellij-rust)
moved over to developing [rust-analyzer](https://github.com/rust-lang/rust-analyzer). This switch makes sense from a lot of standpoints:

- `rust-analyzer` is IDE/editor-agnostic. Because of this, it has a much wider use case than IntelliJ Rust: VSC, [vim-coc](https://github.com/neoclide/coc.nvim), and emacs all use it. Even JetBrain's new IDE [Fleet](https://www.jetbrains.com/fleet/) uses it.
- `rust-analyzer` is programmed in Rust and tends to be much faster than IntelliJ Rust's inspections
- `rust-analyzer` deeply integrates with clippy, unlike IntelliJ Rust.
- `rust-analyzer` now supports expanding macros (a primary reason I didn't use it over IntelliJ)

I generally see more interest from the community in `rust-analyzer`, and I think a `rust-analyzer` IDE is currently the way to go for Rust developers.

## `vim`

In addition, `vim` usage in VSC was quite bad last time I tried, but [VSCode Neovim](https://marketplace.visualstudio.com/items?itemName=asvetliakov.vscode-neovim) works just as well or even better than JetBrain's vim emulator—[IdeaVim](https://github.com/JetBrains/ideavim).

## terminal
For some reason, the IntelliJ/CLion terminal is *very* slow, whereas, in VSC, it works just fine... odd.

# Reasons I prefer IntelliJ/CLion

- auto-completion is **much** better
- It feels more like a complete IDE.