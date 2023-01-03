---
layout: page
title: Suspending Methods
parent: Concurrent Rust Deep Dive
nav_order: 4
---

# Suspending Methods
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

The actual definition of a `Future` in Rust is more complex. If we just had a normal `poll` method, we would need
to constantly poll `Future`s to see if they have progressed. A **runtime** for these would normally just use
a busy loop.

## Naïve Busy Loop Runtime

```rust
struct Runtime {
    tx: Receiver<Box<dyn Future + Sync>>
}

impl Runtime {

    fn schedule(&self, task: impl Future + Sync) {
        self.tx.send(task);
    }

    fn new() -> Self {

        let (rx,tx) = channel();

        std::thread::spawn(|| move {
            let futures = Vec::new();

            loop {
                for future in rx {
                    futures.push(future);
                }

                futures.drain( |fut| fut.poll().is_finished());
            }
        })

        Self {
            tx
        }
    }
}

```

This can be sufficient (although usually not ideal) for `no_std` environments,
where busy loops are not abnormal in production code.

However, ideally there should be a way for a task to notify the runtime that is about to be run so we can run tasks
that are actively progressing before tasks that are waiting for a response. The way Rust accomplishes this is using **informed polling**.


## Completion-based

- [io_uring](https://kernel.dk/io_uring.pdf)

In completion-based concurrency the user submits IO events to the kernel, which returns for the user when those events have completed. This can be helpful in light of [Spectre and Meltdown](https://www.cloudflare.com/learning/security/threats/meltdown-spectre/) as performance hits in kernel patches are due to the decreased cache locality between kernel and user
memory spaces. Completion-based concurrency allows increasing cache locality by staying in a user or kernel space and not
alternating between them. Note this is very similar to threads in the sense that the operating system acts as the runtime and resumes execution. However, yielding occurs by the program.

### Completion Cancellation Problem

> statically typecheck that the borrow is not mutated until the completion completes. In particular, you cannot be guaranteed that a future will be held until the kernel completes because it could be dropped before the completion resolves.

### DMA

A similar issue occurs for DMA. Look at [embedded-dma](https://github.com/rust-embedded/embedded-dma).
Ideally we would have an interface

An example program which uses this is

- [iou](https://boats.gitlab.io/blog/post/iou/)

  > Completion based APIs are inherently difficult to make memory safe because they involve sharing memory between the user program and the kernel.

> This has been called the “completion/cancellation problem”

### Completion Cancellation Problem

TODO

> This is because you are responsible for guaranteeing that the kernel’s borrow of the buffer and file descriptor in these IO events is respected by your program.


## readiness-based

Like `epoll`.

## Informed polling

This is the model that Rust uses. It has somewhat famously been criticized in
the [Hacker News](https://news.ycombinator.com/item?id=26406989) response to [Why asynchronous Rust doesn't work](https://eta.st/2021/03/08/async-rust-2.html). In the Hacker News thread,
[newpavlov](https://news.ycombinator.com/user?id=newpavlov) mentions

> A bigger problem in my opinion is that Rust has chosen to follow the poll-based model (you can say that it was effectively designed around epoll), while the completion-based one (e.g. io-uring and IOCP) with high probability will be the way of doing async in future (especially in the light of Spectre and Meltdown).

Completion based API is [discussed later in the article](#completion-based).

Zamalek replies

> This [(newpavlov's response)] is an inaccurate simplification that, admittedly, their own literature has perpetuated. Rust uses informed polling: the resource can wake the scheduler at any time and tell it to poll. When this occurs it is virtually identical to completion-based async (sans some small implementation details).

It even enables **stateless informed polling** which cannot be accomplsihed by the normal means.

> Normally only the executor would provide the waker implementation, so you only learn which top-level future (task) needs to be re-polled, but not what specific future within that task is ready to proceed. However, some future combinators also use a custom waker so they can be more precise about which specific future within the task should be re-polled.

For instance, a future which selects between multiple tasks might include a custom waker (more concrete example)

(TODO LINK) for being worse than
completion-based, but when digging in further, it is effectively equivalent to completion-based and potentially better
in some scenarios (TODO evidence)