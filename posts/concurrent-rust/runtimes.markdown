---
layout: page
title: Runtime Landscape
parent: Concurrent Rust Deep Dive
nav_order: 7
---

# Runtime Landscape
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>


## Popular runtimes

The two most popular async runtimes for Rust are [Tokio](https://tokio.rs/) and [async-std](https://async.rs/).

Tokio is a mature and feature-rich runtime that is designed to be the foundation of a modern, reliable, and scalable server-side application platform. It provides a high-level API for writing asynchronous I/O-driven applications.

Async-std is a newer runtime, but it is quickly gaining popularity and is becoming the de facto standard for Rust async programming. It provides a powerful API that makes it easy to work with asynchronous tasks and provides a rich set of features and capabilities. In addition, it is more lightweight than Tokio and offers better performance and scalability.

## Generic over runtime
TODO 

## `no_std!`
In addition to the popular runtimes, there are also a number of runtimes designed to run on systems without a standard library, such as embedded systems. These runtimes are often referred to as “no_std” runtimes.

The most popular no_std runtime is [smol](https://github.com/stjepang/smol). It is a lightweight and feature-rich async runtime designed for embedded systems and other resource-constrained environments. It provides a high-level API for writing asynchronous applications and offers better performance than Tokio and async-std.

Another popular no_std runtime is [futures-rs](https://github.com/rust-lang-nursery/futures-rs). It is a library for writing asynchronous applications and provides an API similar to Tokio and async-std. It is designed to be lightweight and provides better performance than Tokio and async-std.

### Microcontrollers 

#### Embassy (`nightly`)

One of the most popular runtimes for microcontrollers is [embassy](https://github.com/rust-embedded/embassy). It is designed to be a lightweight and efficient async runtime for embedded systems and microcontrollers. It provides a high-level API for writing asynchronous applications withouto the use of `heap`.

#### How to build an async runtime

[Ferrous Systems](https://ferrous-systems.com/blog/async-on-embedded/) has an article describing how to build a simple async runtime in Rust

## Low latency

TODO:
I'd imagine if we want to build a low latency executor, we would just have a FIFO queue. i.e., tasks that were put in first
should come out first (we always do the task that was put in last first). Is this not true? We would also need to yield 
frequently. Perhaps tasks that take a long time would need a separate thread. Maybe we could use priorities as well.

## How to handle blocking tasks

[Alice Ryhl eloquently describes when to use which schedule for which tasks](https://ryhl.io/blog/async-what-is-blocking/).
Generally, `async/await` runtimes assume that tasks yield often. If they do not yield often, a separate method should be used:

### Findings


|                               | CPU-bound computation | Synchronous IO | Running forever |
| ----------------------------- | --------------------- | -------------- | --------------- |
| **`spawn_blocking`**          | Suboptimal            | OK             | No              |
| **`rayon`** (thread pool lib) | OK                    | No             | No              |
| **Dedicated thread**          | OK                    | OK             | OK              |