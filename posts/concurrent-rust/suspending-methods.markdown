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
        });

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

- [iou](https://boats.gitlab.io/blog/post/iou/)
<!-- - [io_uring](https://kernel.dk/io_uring.pdf) -->

In completion-based concurrency the user submits IO events to the kernel, which returns for the user when those events have completed. This can be helpful in light of [Spectre and Meltdown](https://www.cloudflare.com/learning/security/threats/meltdown-spectre/) as the patches to fix Spectre/Meltdown cause performance hits when rapidly switching between user and kernel space due to the decreased cache locality between kernel and user
memory spaces. Completion-based concurrency allows increasing cache locality by staying in a user or kernel space and not
alternating between them. Note this is very similar to threads in the sense that the operating system acts as the runtime and resumes execution. However, yielding occurs by the program.

### Completion Cancellation Problem

Completion based APIs are inherently difficult to make memory safe because they involve sharing memory between the user program and the kernel. In particular bounds are difficult to check because of `core::mem::forget` on `Future`s. This is known as 
the **completion cancellation problem**.

#### DMA (Direct Memory Access)

Suppose we are using [Direct Memory Access](https://en.wikipedia.org/wiki/Direct_memory_access) to transfer data between a `u8` slice shared between the kernel and the user space. Suppose the kernel operation is somewhat simple—reading data from a hard drive.

Ideally we would have a function

```rust
async fn read_from_device(identifier: u32, buffer: &mut [u8]) {
    kernel_read_device(identifier, unsafe { buffer.as_raw_buffer() });
    wait_for_interrupt(DMA_FINISHED).await;
}
```

Which is just syntactic sugar for

```rust
fn read_from_device(identifier: u32, buffer: &mut [u8]) -> impl Future<Output = ()> {
   kernel_read_device(identifier, unsafe { buffer.as_raw_buffer() });
    async {
        wait_for_interrupt(DMA_FINISHED).await;
    }
}
```

If we use the [**safe** `core::mem::forget`](https://github.com/rust-lang/rust/issues/24456) in client code we can have

```rust
async fn main(){
    let mut buffer = [0; 4096];
    let fut = read_device(DEVICE, &mut); // [A]
    core::mem::forget(fut);
    buffer[0] = 123; // [B]
}
```

We are disobeying [Rust borrowing rules](https://doc.rust-lang.org/book/ch04-02-references-and-borrowing.html). Namely, 
in **[A]**, there is a kernel read operation that is mutating the buffer while we are mutating the buffer in **[B]**.

#### Solution: `'static` Ownership

If we rewrite the function such that we take ownership of the buffer

```rust
async fn read_from_device(identifier: u32, buffer: &'static mut [u8]) -> 'static mut [u8] {
    kernel_read_device(identifier, unsafe { buffer.as_raw_buffer() });
    wait_for_interrupt(DMA_FINISHED).await;
    Some(buffer)
}
```

This is implemented slightly differently in [embedded-dma](https://github.com/rust-embedded/embedded-dma) in order to allow
for buffer slices to work (as splitting buffers and reconstructing them is UB = Undefined Behavior in Rust).

#### When there is a non `'static` lifetime

TODO: what is the solution around non-static slices

## readiness-based

- https://cfsamson.github.io/book-exploring-async-basics/6_epoll_kqueue_iocp.html

Like `epoll`. Tell us when a socket is ready to be read from, but does not transfer data (i.e., do reading for us).

## Informed polling

This is the model that Rust uses. It has somewhat famously been criticized in
the [Hacker News](https://news.ycombinator.com/item?id=26406989) response to [Why asynchronous Rust doesn't work](https://eta.st/2021/03/08/async-rust-2.html). In the Hacker News thread,
[newpavlov](https://news.ycombinator.com/user?id=newpavlov) mentions

> A bigger problem in my opinion is that Rust has chosen to follow the poll-based model (you can say that it was effectively designed around epoll), while the completion-based one (e.g. io-uring and IOCP) with high probability will be the way of doing async in future (especially in the light of Spectre and Meltdown).

Completion based API is [discussed later in the article](#completion-based).

Zamalek replies

> This [(newpavlov's response)] is an inaccurate simplification that, admittedly, their own literature has perpetuated. Rust uses informed polling: the resource can wake the scheduler at any time and tell it to poll. When this occurs it is virtually identical to completion-based async (sans some small implementation details).

It even enables **stateless informed polling** which cannot be accomplished by the normal means.

> Normally only the executor would provide the waker implementation, so you only learn which top-level future (task) needs to be re-polled, but not what specific future within that task is ready to proceed. However, some future combinators also use a custom waker, so they can be more precise about which specific future within the task should be re-polled.

For instance, a future which selects between multiple tasks might include a custom waker (more concrete example)

(TODO LINK) for being worse than
completion-based, but when digging in further, it is effectively equivalent to completion-based and potentially better
in some scenarios (TODO evidence)
