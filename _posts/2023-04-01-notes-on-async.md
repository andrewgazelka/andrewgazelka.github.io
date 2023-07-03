---
layout: post
title: "Notes on Async"
---

# Don\'t pre-emptively optimize (enjoy `Box`)

## Using `async-trait`

- Don't go leagues to avoid `Box`ing futures unless timings say otherwise
- `#[async-trait]` probably won't slow down your code _that_ much.
  - non-`Box`\'d Futures can be returned from traits with [GATs](https://blog.rust-lang.org/2022/10/28/gats-stabilization.html), but it's a lot of work
    - You have to manually implement `Future` as concrete types are needed
  - when [`async_fn_in_trait`](https://blog.rust-lang.org/inside-rust/2022/11/17/async-fn-in-trait-nightly.html)
    is stabilized, you will be able to remove the `#[async-trait]` macro.

## The Power of `dyn`

Generally, I love using `impl` / concrete types. However, as of the publishing of this article, my IDE (IntelliJ) doesn't
perform type inference on `impl` types.

An easy around this is having a helper function
```rust
trait StreamExt: Stream {
  fn ide(self) -> BoxStream<Self::Item> {
    Box::pin(self)
  }
}
```

and then replacing it with the identity function when you're done with the IDE.
```rust
trait StreamExt: Stream {
  fn ide(self) -> Self {
    self
  }
}
```
