---
layout: page
title: Naïve Async Function Implementation
date: 2023-01-01 04:20:44 -0700
parent: Concurrent Rust Deep Dive
nav_order: 3
---

# Naïve Async Function Implementation
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

Take an asynchronous Rust function

```rust
async fn foo(&self) -> T
```

This is actually syntactic sugar for

```rust
fn foo<'a>(&'a self) -> impl Future<Output = T> + 'a
```

which means we are returning a struct which implements the `Future` trait and has at most the lifetime of `'a` (the lifetime of `&self`).

The [`Future`](https://doc.rust-lang.org/std/future/trait.Future.html) trait allows us to define tasks which
can be executed asynchronously—not occurring at the same time. Therefore, we would
expect to be able to do portions of work in `foo` at given intervals.

## Future Implementation

The simplified definition of `Future` is:

```rust
pub enum Poll<T> {
    Ready(T),
    Pending,
}

pub trait Future {
    type Output;

    fn poll(&mut self) -> Poll<Self::Output>;
}
```

Every single time `poll` is called, a portion of work is done. Once `poll` returns `Poll::Ready(Self::Output)`, we have finished our task.

## `Future` State Machine

`Future` can be thought of a [finite-state machine](https://en.wikipedia.org/wiki/Finite-state_machine)
which progresses with each call to `poll` and stops when `Poll::Ready` is returned

### Manual `Future` Implementation

Suppose we want to write a naïve function which performs a `get` request without [blocking](#blocking). A task
which does not block is colloquially defined as **non-blocking**.

```rust
enum State {
    Init,
    Pending,
    Complete,
}

struct NonBlockingGet {
    tcp_socket: Tcp,
    recv_buffer: Vec<u8>,
    state: State
}

impl Future for NonBlockingGet {
    type Output = String

    fn poll(&mut self) -> Poll<Self::Output> {
       match self.state {
           State::Init => {
                let get_req_bytes = todo!();
                self.tcp_socket.write(get_req_bytes)
                self.state = State::Pending;
           }
            State::Pending => {
                if self.tcp_socket.try_read_into(self.recv_buffer).is_finished() &&
                    is_complete(self.recv_buffer) {
                    return into_body(self.recv_buffer)
                }
            }
       }
    }
}
```

## Automatic `Future` Implementation

```rust
async fn non_blocking_get(&self) -> String {
    let get_req_bytes = todo!();
    self.tcp_socket.write(get_req_bytes);
    loop {
        self.read_into(&mut self.recv_buffer).await;
        if self.is_complete(&mut self.recv_buffer) {
            return into_body(self.recv_buffer);
        }
    }

}
```
