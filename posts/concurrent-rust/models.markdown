---
layout: page
title: Concurency Models
date: 2023-01-01 04:20:44 -0700
categories: rust concurrency
parent: Concurrent Rust Deep Dive
nav_order: 2
---


# Concurrency Models
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

Citing the [Rust Async Book](https://rust-lang.github.io/async-book/01_getting_started/02_why_async.html), there are
several concurrency models:

> - **OS threads** don't require any changes to the programming model, which makes it very easy to express concurrency. However, synchronizing between threads can be difficult, and the performance overhead is large. Thread pools can mitigate some of these costs, but not enough to support massive IO-bound workloads.
> - **Event-driven programming**, in conjunction with callbacks, can be very performant, but tends to result in a verbose, "non-linear" control flow. Data flow and error propagation is often hard to follow.
> - **Coroutines**, like threads, don't require changes to the programming model, which makes them easy to use. Like async, they can also support a large number of tasks. However, they abstract away low-level details that are important for systems programming and custom runtime implementors.
> - **The actor model** divides all concurrent computation into units called actors, which communicate through fallible message passing, much like in distributed systems. The actor model can be efficiently implemented, but it leaves many practical issues unanswered, such as flow control and retry logic.

In addition, there is also **green threads** which are like OS threads but implemented at the program level not the kernel (TOOD: correct?) level.

## OS Threads

Operating System threads are generally the first way programmers are taught to deal with concurrency.
The operating system already has to deal with processing scheduling. This is important because even if your
CPU has one or two cores, you will want to be able to run hundreds of programs and this is impossible without
some type of scheduling process. On top of this, mainstream operating systems generally provides an abstraction
for a _thread_, which is just a process with shared memory.

The programming model is the same as with normal synchronous code, but there tends to be a lot of overhead due to
context switching which [according to Microsoft](https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/system/overviews/finding-threading-issues/high-context-switches) is

> the process of storing the state of a thread so that it can be restored to resume execution at a later point in time

Rapid context switching is already expensive because registers need to be stored into memory and resumed. However,
what makes cases even worse is cache locality and CPU misses.

<!-- ## Event-driven programming -->

<!-- TODO -->

<!-- - Uses callbacks -->
<!-- - [GeeksForGeeks](https://www.geeksforgeeks.org/explain-event-driven-programming-in-node-js) -->

## Green threads

Sometimes we do not want to rely on an operating system to schedule our tasks. For instance, it might have
significant overhead or might not be as fine-tuned as we want. Perhaps we want to have certainty about how our
code will run on separate platforms, or we want to have threads on a bare-metal environment where there is no
Operating System to provide a definition of a thread. In this instance, we can use something called a [**Green Thread**](https://en.wikipedia.org/wiki/Green_thread).

Instead of relying on an operating system, we can provide our own scheduling runtime for our custom non-OS threads—green threads. It is important to note that even though _green_ threads can be thought of "eco-friendly", lightweight threads, [the term "green" comes from the team that designed green threads](https://web.archive.org/web/20080530073139/http://java.sun.com/features/1998/05/birthday.html) at Sun Microsystems.

- [Writing green threads](https://cfsamson.gitbook.io/green-threads-explained-in-200-lines-of-rust/)
- https://ferrous-systems.com/blog/async-on-embedded/
- https://github.com/embassy-rs/embassy

## Coroutines

[According to C++ reference](https://en.cppreference.com/w/cpp/language/coroutines)

> a coroutine is a function that can suspend execution to be resumed later

The [difference between coroutine and threads](https://en.wikipedia.org/wiki/Coroutine#Threads) is that

- coroutines are [cooperatively multitasked](https://en.wikipedia.org/wiki/Cooperative_multitasking) meaning they
  **voluntarily yield control**
- threads are typically [preemptively multitasked](<https://en.wikipedia.org/wiki/Preemption_(computing)>) meaning they are
  **forced to yield control by an external scheduler**

This allows us to launch many more coroutines than we would threads as the coroutine yielding performance penalty is minimal.

[Kotlin is one of the main languages that started the coroutine hype train](https://kotlinlang.org/docs/coroutines-guide.html).

They take a unique approach to `async/await` where the `.await` keyword is assumed so sequential code
can be almost a literal copy and paste of suspending code. In Rust,
the `.await` keyword must be appended as running of suspending code is lazy.

```kotlin
suspend fun doSomethingUsefulOne(): Int {
    delay(1000L) // pretend we are doing something useful here
    return 13
}

suspend fun doSomethingUsefulTwo(): Int {
    delay(1000L) // pretend we are doing something useful here, too
    return 29
}

val execute_sequentially = measureTimeMillis {
    val one = doSomethingUsefulOne()
    val two = doSomethingUsefulTwo()
    println("The answer is ${one + two}")
}

val execute_concurrently = measureTimeMillis {
    val one = async { doSomethingUsefulOne() }
    val two = async { doSomethingUsefulTwo() }
    println("The answer is ${one.await() + two.await()}")
}
```

In Rust this would look like

```rust
async fn do_something_useful_one() -> i32 {
    delay(1000).await // pretend we are doing something useful here
    return 13
}

async fn doSomethingUsefulTwo(): Int {
    delay(1000).await // pretend we are doing something useful here, too
    return 29
}

async fn execute_sequentially() {
    let one = doSomethingUsefulOne().await;
    let two = doSomethingUsefulTwo().await;
    let answer = one + two;
    println!("The answer is {answer}")
}

async fn execute_concurrently() {

    let one = executor::spawn(doSomethingUsefulOne);
    let two = executor::spawn(doSomethingUsefulTwo);

    let answer = one.await + two.await;
    println!("The answer is {answer}")
}
```

More languages are picking up coroutines. For instance, Go is deeply integrated with coroutines and uses their own ["Go-routine"](https://gobyexample.com/goroutines) runtime which relies heavily on [message passing](https://doc.rust-lang.org/book/ch16-02-message-passing.html).

```go
package main

import (
    "fmt"
    "time"
)

func f(from string) {
    for i := 0; i < 3; i++ {
        fmt.Println(from, ":", i)
    }
}

func main() {

    f("direct")

    go f("goroutine")

    go func(msg string) {
        fmt.Println(msg)
    }("going")

    time.Sleep(time.Second)
    fmt.Println("done")
}
```

```bash
$ go run goroutines.go
direct : 0
direct : 1
direct : 2
goroutine : 0
going
goroutine : 1
goroutine : 2
done
```

<!-- - Kotlin -->
<!-- - TODO https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-deferred/ -->
<!-- - custom reified asynchronous heapified -->
<!-- - async runtime in Pure Kotlin and a library -->
<!-- - suspend deeply primitive -->
