---
layout: post
title:  "Async Rust Deep Dive"
date:   2022-12-3 05:31:01 -0700
categories: rust concurrency
---

# What is Asynchronous
It is crucial to correctly understand exactly what asynchronous means before investing time in learning its complexities. 

The prefix "a—"  denotes something which is not, so asynchronous should be equivalent to *not synchronous*.

## *synchronous*

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/synchronous), synchronous means

> happening, existing, or arising at precisely the same time

---


From these definitions, we can deduce that _asynchronous_ means something that does not occur simultaneously. 
Indeed, according to [Merriam-Webster](https://www.merriam-webster.com/dictionary/asynchronous), asynchronous is a task that

> not simultaneous or concurrent in time

If you have learned about `async/await` before, this might contradict your beliefs of what asynchronous is. I know it did for me. 

On StackExchange, [Mohammad Nazayer writes](https://softwareengineering.stackexchange.com/q/396585/306473):

> If you google the meaning of the words you will get the following: 
> 
> - Asynchronous: [not existing or occurring at the same time][1].
> 
> - Synchronous: [existing or occurring at the same time][2].
>  
> But it seems like they are used to convey the opposite meaning in programming or computer science

[Doc Brown answers](https://softwareengineering.stackexchange.com/a/396590/306473):

> When one task T1 starts a second task T2, it can happen in the following manner:
> 
> > Synchronous: existing or occurring at the same time.
> 
> So T2 is guaranteed to be started and executed *inside the time slice of T1*. T1 "waits" for the ending of T2 and can continue processing afterwards. In this sense, T1 and T2 occur "at the same time" (not "in parallel", but in a contiguous time interval).
> 
> > Asynchronous: not existing or occurring at the same time.
> 
> So the execution time of T2 is now unrelated to T1. It may be executed in parallel, it may happen one second, one minute or several hours later, and T2 may still run when T1 has ended (so to process a result of T2, a new task T3 may be required). In this sense, T1 and T2 are not "occuring at the same time (interval)".
> 
> Of course, I agree, the literal definitions appear to be ambiguous when seeing that asynchronous operations nowadays are often used for creating parallel executions.

# Concurrency

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/concurrence), conccurence is the:
- the simultaneous occurrence of events.


Citing the [Rust Aync Book](https://rust-lang.github.io/async-book/01_getting_started/02_why_async.html):

> - **OS threads** don't require any changes to the programming model, which makes it very easy to express concurrency. However, synchronizing between threads can be difficult, and the performance overhead is large. Thread pools can mitigate some of these costs, but not enough to support massive IO-bound workloads.
> - **Event-driven programming**, in conjunction with callbacks, can be very performant, but tends to result in a verbose, "non-linear" control flow. Data flow and error propagation is often hard to follow.
> - **Coroutines**, like threads, don't require changes to the programming model, which makes them easy to use. Like async, they can also support a large number of tasks. However, they abstract away low-level details that are important for systems programming and custom runtime implementors.
> - **The actor model** divides all concurrent computation into units called actors, which communicate through fallible message passing, much like in distributed systems. The actor model can be efficiently implemented, but it leaves many practical issues unanswered, such as flow control and retry logic.

Suppose we want to get data about SpaceX using the [SpaceX Data API](https://docs.spacexdata.com/).

## OS Threads

![Rockets](/assets/rockets.png)

## Event-driven programming

- Uses callbacks
- [GeeksForGeeks](https://www.geeksforgeeks.org/explain-event-driven-programming-in-node-js)

## Coroutines
- https://en.cppreference.com/w/cpp/language/coroutines
- Kotlin

- TODO https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-deferred/
- custom reified async heapified
- async runtime in Pure Kotlin and a library
- suspend deeply primitive

# Future Design

## Completion-based

## Informed polling vs Not

# Structured Concurrency

## Kotlin

## Rust

## AsyncDrop (structured concurrency)

### [Tokio #1879](https://github.com/tokio-rs/tokio/issues/1879).
> Rusts `async/await` mechanism already provides structured concurrency inside a particular task: By utilizing tools like `select!` or `join!` we can run multiple child-tasks which are constrained to the same lifetime - which is the current scope. This is not possible in Go or Kotlin - which require an explicit child-task to be spawned to achieve the behavior. Therefore the benefits might be lower.

- [Async Fundamentals AsyncDrop](https://rust-lang.github.io/async-fundamentals-initiative/roadmap/async_drop.html)
- [Asynchronous Destructors](https://boats.gitlab.io/blog/post/poll-drop/)
- [iou](https://boats.gitlab.io/blog/post/iou/)
- [need AsyncDrop](https://github.com/tokio-rs/tokio/issues/2596#issuecomment-663349217)

- https://eta.st/2021/03/08/async-rust-2.html (https://news.ycombinator.com/item?id=26406989)

> some future combinators also use a custom waker so they can be more precise about which specific future within the task should be re-polled. 

>  This is an inaccurate simplification that, admittedly, their own literature has perpetuated. Rust uses informed polling: the resource can wake the scheduler at any time and tell it to poll. When this occurs it is virtually identical to completion-based async (sans some small implementation details).
> 
> What informed polling brings to the picture is opportunistic sync: a scheduler may choose to poll before suspending a task. This helps when e.g. there is data already in IO buffers (there often is).
> 
> There's also some fancy stuff you can do with informed polling, that you can't with completion (such as stateless informed polling).
> 
> Everything else I agree with, especially Pin, but informed polling is really elegant.   

- https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/
- 

# Green threads

[Wikipedia mentions](https://en.wikipedia.org/wiki/Green_thread):

> In computer programming, a green thread or virtual thread[disputed – discuss] is a thread that is scheduled by a runtime library or virtual machine (VM) instead of natively by the underlying operating system (OS). Green threads emulate multithreaded environments without relying on any native OS abilities, and they are managed in user space instead of kernel space, enabling them to work in environments that do not have native thread support.

- [Writing green threads](https://cfsamson.gitbook.io/green-threads-explained-in-200-lines-of-rust/)
    
- https://ferrous-systems.com/blog/async-on-embedded/
- https://github.com/embassy-rs/embassy
- https://github.com/embassy-rs/embassy

    
# Scheduling

# Future Definitions C++ vs Rust

# Primitives

# Kotlin Model


asdasdasd

# Model

TODO: how async works informed polling architecture how it differs from C++

# Runtimes

## Popular runtimes

## Generic over runtime

## no_std

## Low latency

## Async-std

- https://github.com/async-rs/async-std
- https://ryhl.io/blog/async-what-is-blocking/


# Primitives

The `async` keyword is a powerful way to write state machines using code that 