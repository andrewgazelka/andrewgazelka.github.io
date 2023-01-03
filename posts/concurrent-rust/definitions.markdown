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
- TOC
{:toc}
</details>

## Async ≠ Concurrent

**TLDR;** 

The programming meaning of the term "asynchronous" is easier to understand when you understand it as meaning "not simultaneously."

---

## Synchronous / Not Asynchronous

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/synchronous), _synchronous_ means

> happening, existing, or arising at precisely the same time

---

Therefore, **_asynchronous_ means something that does not occur at the same time**.

This means an asynchronous function can run _in parts_ and not necessarily at the same time. The process of the function pausing (since it is not executed all at once) and giving control back to the caller is called **yielding**.

---

Synchronous functions run at the same time.

```rust
use std::{thread, time};

fn do_a_sync() {
  thread::sleep(time::Duration::from_secs(3));
  println!("sync a");
}

fn do_b_sync() {
  thread::sleep(time::Duration::from_secs(2));
  println!("sync b");
}

fn do_c_sync() {
  thread::sleep(time::Duration::from_secs(1));
  println!("sync c");
}

// runs "synchronously", at "the same time." We have to call `run_sync` all at once.
fn run_sync() {
  do_a_sync();   
  do_b_sync();   
  do_c_sync();   
}
```

Running with `run_sync`, we get

```
sync a
sync b
sync c
```
with `time elapsed: 6s`.


## Asynchronous / Not Concurrent

```rust
use std::time;

fn do_a_sync() {
  utils::sleep(time::Duration::from_secs(3)).await;
  println!("async a");
}

fn do_b_sync() {
  utils::sleep(time::Duration::from_secs(2)).await;
  println!("async b");
}

fn do_c_sync() {
  utils::sleep(time::Duration::from_secs(1)).await;
  println!("async c");
}

// runs "asyncronously", not at "the same time." Allows yielding to the caller of `run_async` and doing tasks in between
async fn run_async() {
  do_a_async().await;
  do_b_async().await;   
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
  // progresses through the function the more times `poll` is called and returns `true` when we are done
  fn poll(&self) -> bool {
    // blackbox 
  }
}
```

Where each time we run `poll`, we are progressing through the function.

Suppose:

- `do_a_async` takes $A$ polls to finish 
- `do_b_async` takes $B$ polls to finish
- `do_c_async` takes $C$ polls to finish

The rust compiler will generate `BlackBox` as to complete after $A + B + C$ `poll`s.

We can see that we do not necessarily need to run all the tasks of `run_async` at once. However, the prints should still occur sequentially. Running `run_async`, we get

```
async a
async b
async c
```
with `time elapsed: 6s`.

## Concurrent

Remember: the Rust compiler compiles the `run_async` function into a struct which has a `poll` method. The `async` functions within `run_async` have a similar interface and are `poll`'d upon. 
This means the Rust compiler delegates `BlackBox#poll`

- to `do_a_async_BlackBox#poll` until it returns `true`
- ... then to `do_b_async_BlackBox#poll` until it returns `true`
- ... then to `do_c_async_BlackBox#poll` until it returns `true`
- ... then returns `true`

We can instead using a `join!` macro, where each call to `poll` on `run_concurrent` will call `poll` on both `a`, `b`, and `c`, progressing the function **concurrently**. This is not at odds with the definition of asynchronous.

In this scenario, we will only need to poll $\min\(A,B,C\)$ times.

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

Running `run_concurrent`, we get:
```
async c
async b
async a
```
with `time elapsed: 3s`.