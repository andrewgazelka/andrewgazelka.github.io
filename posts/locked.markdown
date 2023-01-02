---
layout: post
title:  "Locked Crate"
date:   2022-10-26 05:31:01 -0700
categories: rust crate
---

# `#[derive(Locked)]`: Up-to-Date Structures

When working with other developers, maintaining invariants can be complicated. Of course, documentation and good comments can help, but it is easy for a developer to miss one word in a block of several. 

To alleviate this issue, I have created `locked`. Adding `#[derive(Locked)]` to a struct locks it to a particular hash. When the struct is updated, developers must correct the hash. This procedure informs developers to be extra careful to uphold invariants.

```rust
#[derive(locked::Locked)]
#[locked("e3b0c44")]
struct Example {}
```