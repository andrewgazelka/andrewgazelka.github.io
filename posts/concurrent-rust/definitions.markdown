---
layout: page
title: Definitions
date: 2023-01-01 04:20:44 -0700
categories: rust concurrency
parent: Concurrent Rust Deep Dive
nav_order: 1
---


# Definitions
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Async is not Necessarily Concurrent

**TLDR;** 

The programming meaning of the term "asynchronous" is easier to understand when you understand it as meaning "not synchronized."

---

### Synchronous

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/synchronous), synchronous means

> happening, existing, or arising at precisely the same time

---

Therefore, **_asynchronous_ means something that does not occur simultaneously**.

This means,

1. An asynchronous function does _not_ run at once.
2. An asynchronous function can _yield_ across execution.

---

## Examples

### Synchronous / Not Asynchronous

```rust
// runs "synchronously", at "the same time." We have to run these all at the same time
fn run_sync() {
  do_a_sync();   
  do_b_sync();   
  do_c_sync();   
}
```

### Asynchronous / Not Concurrent

```rust
// runs "asyncronously", not at "the same time." Allows yielding.
async fn run_async() {
  // first A polls runs a
  do_a_async().await;
  
  // then next B polls runs b
  do_b_async().await;   
  
  // then next C polls runs c
  do_c_async().await;   
}
```

We can desugar `run_async` to
```rust
fn run_async() -> BlackBox {
  // blackbox  
}

struct BlackBox;

impl BlackBox {
  fn poll(&self) {
    // blackbox 
  }
}
```

Where to get through the function we will need to call poll $A + B + C$ times.

We can see that we do not necessarily need to run all the tasks of `run_async` at once.

### Concurrent

Note that `run_async` just combines other async functions that are themselves poll'd.

We can combine these using a `join` macro, where each call to `poll` on `run_concurrent` will call `poll` on both `a`, `b`, and `c` at the same time, progressing the function **concurrently**. This is not at odds with the definition of asyncronous.

```rust
// runs "concurrently", at "the same time."
async fn run_concurrent() {
  // run all a, b and c at once
  let a = do_a_async()
  let b = do_b_async();
  let c = do_c_async();
  
  // await all of them at once
  futures::join!(a, b, c);
}
```