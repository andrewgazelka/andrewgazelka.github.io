---
layout: page
title: Structured Concurrency
parent: Concurrent Rust Deep Dive
nav_order: 6
---

# Structured Concurrency
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

Structured concurrency was popularized by [Notes on structured concurrency, or: Go statement considered harmful](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/), which argues that the go statement (which launch `goroutines`—Go's implementation of coroutines) is harmful due first and foremost to the fact that 

## Kotlin

## Rust

### `AsyncDrop` (structured concurrency)

- [Tokio #1879](https://github.com/tokio-rs/tokio/issues/1879).

> Rusts `async/await` mechanism already provides structured concurrency inside a particular task: By utilizing tools like `select!` or `join!` we can run multiple child-tasks which are constrained to the same lifetime - which is the current scope. This is not possible in Go or Kotlin - which require an explicit child-task to be spawned to achieve the behavior. Therefore, the benefits might be lower.

- [Async Fundamentals AsyncDrop](https://rust-lang.github.io/async-fundamentals-initiative/roadmap/async_drop.html)
- [Asynchronous Destructors](https://boats.gitlab.io/blog/post/poll-drop/)
- [iou](https://boats.gitlab.io/blog/post/iou/)
- [need AsyncDrop](https://github.com/tokio-rs/tokio/issues/2596#issuecomment-663349217)

- https://eta.st/2021/03/08/async-rust-2.html (https://news.ycombinator.com/item?id=26406989)

> Some future combinators also use a custom waker, so they can be more precise about which specific future within the task should be re-polled.

> This is an inaccurate simplification that, admittedly, their own literature has perpetuated. Rust uses informed polling: the resource can wake the scheduler at any time and tell it to poll. When this occurs it is virtually identical to completion-based async (sans some small implementation details).
>
> What informed polling brings to the picture is opportunistic sync: a scheduler may choose to poll before suspending a task. This helps when e.g. there is data already in IO buffers (there often is).
>
> There's also some fancy stuff you can do with informed polling, that you can't with completion (such as stateless informed polling).
>
> Everything else I agree with, especially Pin, but informed polling is really elegant.

- https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/
-
