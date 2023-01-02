---
layout: page
title: Concrete Future Impl
parent: Concurrent Rust Deep Dive
nav_order: 5
---

# Concrete Future Implementation
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

The _actual_ Rust implementation of `Future` is such

```rust
pub trait Future {
    type Output;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}
```

There are a lot of concepts to take in here.

## Memory Pinning

The notion of `Pin<&mut Self>` is equivalent to `&mut self` where
the memory location of self is static over its lifetime (TODO). This is important as the state machines produced by

```rust
async fn foo(&self) -> T
```

return a `Future` which self-referenced (TODO: provide example)

## Context

The parameter `cx: &mut Context<'_>` also deserves attention.

Currently, [`Context`](https://doc.rust-lang.org/std/task/struct.Context.html) serves as a wrapper around a `Waker`—it only has methods:

```rust
pub fn from_waker(waker: &'a Waker) -> Context<'a>
pub fn waker(&self) -> &'a Waker
```

### Waker

Again the [Waker](https://doc.rust-lang.org/std/task/struct.Waker.html) struct serves as a wrapper around a
`RawWaker` struct and most importantly contains

```rust
pub unsafe fn from_raw(waker: RawWaker) -> Waker
```

> The behavior of the returned Waker is undefined if the contract defined in `RawWaker`’s and `RawWakerVTable`’s
> documentation is not upheld. Therefore this method is unsafe.

### RawWaker

The [`RawWaker`](https://doc.rust-lang.org/std/task/struct.RawWaker.html) struct is a wrapper aronud a pointer
to data and a virtual function pointer table (vtable) that customizes the behavior of the RawWaker.

```rust
pub const fn new(data: *const (), vtable: &'static RawWakerVTable) -> RawWaker
```

The [`RawWakerVTable`](https://doc.rust-lang.org/std/task/struct.RawWakerVTable.html) requires pointers to functions
with signatures:

```rust
unsafe fn clone(data: *const ()) -> RawWaker,
unsafe fn wake(data: *const ()),
unsafe fn wake_by_ref(data: *const ()),
unsafe fn drop(data: *const ())
```

- `clone` is called to clone a `RawWaker`
- `wake` is called by the [Waker](#waker) to indicate to the runtime the function should be awoken
- `wake_by_ref` similar to `wake` but does not consume the data pointer
- `drop` called when the [RawWaker](#rawwaker) is dropped.

Realize that the `Waker` is provided by the runtime and by default is propagated down to children. However,
