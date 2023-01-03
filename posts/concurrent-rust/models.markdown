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

- **OS threads** don't require any changes to the programming model, which makes it very easy to express concurrency. However, synchronizing between threads can be difficult, and the performance overhead is large. Thread pools can mitigate some of these costs, but not enough to support massive IO-bound workloads.
- **Event-driven programming**, in conjunction with callbacks, can be very performant, but tends to result in a verbose, "non-linear" control flow. Data flow and error propagation is often hard to follow.
- **Coroutines**, like threads, don't require changes to the programming model, which makes them easy to use. Like async, they can also support a large number of tasks. However, they abstract away low-level details that are important for systems programming and custom runtime implementors.
- **The actor model** divides all concurrent computation into units called actors, which communicate through fallible message passing, much like in distributed systems. The actor model can be efficiently implemented, but it leaves many practical issues unanswered, such as flow control and retry logic.

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

## Event-driven programming / callbacks

Event-driven programming is an asynchronous model of programming which relies on **callbacks** or listeners to provide
asynchronous control flow. For example, `NodeJS` uses listeners to get the response of a http request and then
calls a callback. The same idea applies to database operations which use a listener to report when a query is done.

A very simple example of event-driven programming in JavaScript is

```javascript
setTimeout(() => {
  console.log("Hello World!");
}, 1000);
```

In this code, the 
* **callback** is the function inside of the `setTimeout` call. This function is called when the timeout is complete, and
it's the job of the callback to do the work required after the delay is complete—in this case, printing `"Hello World!"`.

Event-driven programming is often seen as a more performant than OS threads because of the nature of
how computation is done. Instead of context switching to a new thread, the process stays in one thread
and is only interrupted when the event needs to be triggered such as a database query being done. This process
creates less overhead.

### Callback Hell

However, this type of programming can be very verbose, difficult to understand, and hard to debug.
The flow of control and control flow errors can be hard to track and errors can propagate in difficult to understand
ways.

For instance, you might have heard of [**callback hell**](http://callbackhell.com/)

```javascript
fs.readdir(source, function (err, files) {
  if (err) {
    console.log('Error finding files: ' + err)
  } else {
    files.forEach(function (filename, fileIndex) {
      console.log(filename)
      gm(source + filename).size(function (err, values) {
        if (err) {
          console.log('Error identifying file size: ' + err)
        } else {
          console.log(filename + ' : ' + values)
          aspect = (values.width / values.height)
          widths.forEach(function (width, widthIndex) {
            height = Math.round(width / aspect)
            console.log('resizing ' + filename + 'to ' + height + 'x' + height)
            this.resize(width, height).write(dest + 'w' + width + '_' + filename, function(err) {
              if (err) console.log('Error writing file: ' + err)
            })
          }.bind(this))
        }
      })
    })
  }
})
```

Yikes. This is complicated. And handling errors is not straight forward either. Ideally, this _should_ be able to be done linearly rather than making a 
code pyramid.

### Linear Flow

In JavaScript one can use the [async/await syntax](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function) to allow for a more lienar flow.

An example is the code below,

```javascript
async function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function logHi() {
  await delay(1000);
  console.log("Hi!");
}

logHi();
```

The `async` keyword allows us to pause execution until the promise is resolved. This makes the control flow much easier
to read, as we don't have to think about callbacks and can just focus on the code inside of the `logHi()` function.

At a lower level, however, code like this is generally compiler-generated code that uses a technique called [continuation passing style](https://en.wikipedia.org/wiki/Continuation-passing_style).

## Actor model

The [actor model](https://en.wikipedia.org/wiki/Actor_model) has been around since the 1970s when [Hewitt, Bishop and
Steiger](https://dl.acm.org/doi/10.5555/1624775.1624804) wrote about it.
It has since been popularized by languages like Erlang, Concurnas and Akka
which offer actors as a part of their standard library.
It is different from other concurrency models as it follows a
[message-passing](https://doc.rust-lang.org/book/ch16-02-message-passing.html) approach. Actors are autonomous entities, meaning they are independent of each other and have no shared memory or state. Therefore, actors can be distributed across multiple computers, allowing for more efficient parallelism. 

### Rust

In Rust, the actor model is implemented through the `actix` crate. Actors are implemented as asynchronous units of work called `tasks`, which communicate asynchronously through message passing. The messages are sent through a Mailbox, which are thread-safe queues shared between tasks. This allows tasks to send messages to each other without having to block or wait.

For example, a simple "ping-pong" program using actix might look like:

```rust
use actix::prelude::*;

struct PingActor;

impl Actor for PingActor {
    type Context = Context<Self>;

    fn started(&mut self, ctx: &mut Context<Self>) {
        println!("PingActor started");
        ctx.notify(PongActor);
    }
}

struct PongActor;

impl Actor for PongActor {
    type Context = Context<Self>;

    fn started(&mut self, ctx: &mut Context<Self>) {
        println!("PongActor started");
        ctx.notify(PingActor);
    }
}

fn main() {
    let system = System::new("ping_pong");
    let ping_actor = PingActor.start();
    let pong_actor = PongActor.start();
}
```

In this example, the `PingActor` sends a message to the `PongActor` when it's started, and the `PongActor` sends a message to the `PingActor` when it's started.

## Green threads


Green threads, also known as lightweight threads, are user-level threads that are scheduled by the application, instead of by the operating system. Green threads are implemented within the application, and do not usually require any support from the underlying operating system. Instead of relying on the operating system's scheduler to handle thread scheduling, green threads rely on a system with a thread scheduler written in software.

Green threads are more lightweight than traditional OS threads since they are created and managed by the application, rather than the OS. This means that switching between green threads is much faster, since the context switch only involves operations within the application, instead of involving operations within the operating system.

Although green threads can provide many benefits, they are not suitable for all types of applications. Green threads can be inefficient when used with multiple processors (in this case they need to be built on top of OS threads), or when performing blocking operations such as waiting for I/O or communication with other processes. In such cases, an application will benefit more from using traditional OS threads. TODO: is this true? 

- [Writing green threads](https://cfsamson.gitbook.io/green-threads-explained-in-200-lines-of-rust/)

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