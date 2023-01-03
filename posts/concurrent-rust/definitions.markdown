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

**The programming meaning of the term "asynchronous" is easier to understand when you understand it as meaning "not synchronized."**

## Synchronous

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/synchronous), synchronous means

> happening, existing, or arising at precisely the same time

---

Therefore, **_asynchronous_ means something that does not occur simultaneously**. 
If you have learned about `async/await` before, this might contradict your beliefs of what asynchronous is. I know it did for me.
This is because `async` often is used in tandem with schedulers _to_ achieve parallelism. However, this is not part of the core definition of `async`.

```rust
// runs "synchronously", at "the same time." We have to run these all at the same time or not
fn run_sync() {
  do_a() 
  do_b()   
  do_c()   
}
```

```rust
// runs "asyncronously", not at "the same time." Allows yielding.
async fn run_async() {
  // first poll runs a
  do_a().await;
  
  // second poll runs b
  do_b().await;   
  
  // third poll runs c
  do_c().await;   
}
```

When we can desugar `run_async` to
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

## Concurrent

So even though a definition of asynchronous is _not concurrent_, it might be easier to use the term concurrency in
substitution for when we will normally use _asyncronous_. When using the modern term asyncronous in programming, we generally instead mean _concurrent_.

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/concurrence), concurrence is the:

- the simultaneous occurrence of events.
