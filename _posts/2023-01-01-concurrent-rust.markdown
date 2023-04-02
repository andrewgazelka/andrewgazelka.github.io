---
layout: post
title: Concurrent Rust Deep Dive
date: 2023-01-01 04:20:44 -0700
categories: rust concurrency
has_children: true
has_toc: true
---

[//]: # ({:.warning})

[//]: # (This article is currently a WIP. Certain pages are not finished and often contain many TODOs.)

[//]: # ()
[//]: # ({:.warning})

[//]: # (I have played around with OpenAI [edit]&#40;https://beta.openai.com/docs/guides/completion/editing-text&#41; and [insert]&#40;https://beta.openai.com/docs/guides/completion/inserting-text&#41; )

[//]: # (APIs for small but significant portions of the article. I have edited and reviewed the information, but it is totally possible I have missed a few things which are not entirely correct.)

[//]: # ()
[//]: # ({:.todo})

[//]: # (👀 [optimizing-await-1]&#40;https://tmandry.gitlab.io/blog/posts/optimizing-await-1/&#41;)

[//]: # ()
[//]: # ({:.todo})

[//]: # (👀  [optimizing-await-2]&#40;https://tmandry.gitlab.io/blog/posts/optimizing-await-2/&#41;)

[//]: # ()
[//]: # ({:.todo})

[//]: # (👀  [may]&#40;https://github.com/Xudong-Huang/may&#41;)

[//]: # ()
[//]: # ({:.todo})

[//]: # (👀  [xitca-web]&#40;https://github.com/HFQR/xitca-web&#41;)

[//]: # ()
[//]: # ({:.todo})

[//]: # (👀  [tock]&#40;https://www.tockos.org/&#41;)

[//]: # ()
[//]: # ({:.todo})

[//]: # (👀  RTOS)

[//]: # ()
[//]: # ({:.todo})

[//]: # (https://blog.yoshuawuyts.com/futures-concurrency-3/)

[//]: # ()
[//]: # ({:.todo})

[//]: # (https://www.drone-os.com/)

# Definitions

## Async != Concurrent
The programming meaning of the term "asynchronous" is easier to understand when you understand it as meaning "not synchronously."


## Synchronous / Not Asynchronous

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/synchronous), _synchronous_ means

> happening, existing, or arising at precisely the same time

Therefore, **_asynchronous_ means something that does not occur at the same time**.

This means an asynchronous function can run _in parts_ and not necessarily at the same time. The process of the function pausing (since it is not executed all at once) and giving control back to the caller is called **yielding**.

Synchronous functions run at the same time.

```rust
use std::{thread, time};

fn do_a_sync() {
  thread::sleep(time::Duration::from_secs(3));
  println!("sync a");
}

fn do_b_sync() {
  thread::sleep(time::Duration::from_secs(2));
  println!("sync b");
}

fn do_c_sync() {
  thread::sleep(time::Duration::from_secs(1));
  println!("sync c");
}

// runs "synchronously", at "the same time." We have to call `run_sync` all at once.
fn run_sync() {
  do_a_sync();   
  do_b_sync();   
  do_c_sync();   
}
```

Running with `run_sync`, we get

```
sync a
sync b
sync c
```
with `time elapsed: 6s`.


## Asynchronous / Not Concurrent

```rust
use std::time;

fn do_a_sync() {
  utils::sleep(time::Duration::from_secs(3)).await;
  println!("async a");
}

fn do_b_sync() {
  utils::sleep(time::Duration::from_secs(2)).await;
  println!("async b");
}

fn do_c_sync() {
  utils::sleep(time::Duration::from_secs(1)).await;
  println!("async c");
}

// runs "asyncronously", not at "the same time." Allows yielding to the caller of `run_async` and doing tasks in between
async fn run_async() {
  do_a_async().await;
  do_b_async().await;   
  do_c_async().await;   
}
```

We can desugar `run_async` to
```rust
fn run_async() -> BlackBox {
  // blackbox
}

struct BlackBox;

impl BlackBox {
  // progresses through the function the more times `poll` is called and returns `true` when we are done
  fn poll(&self) -> bool {
    // blackbox 
  }
}
```

Where each time we run `poll`, we are progressing through the function.

Suppose:

- `do_a_async` takes $A$ polls to finish
- `do_b_async` takes $B$ polls to finish
- `do_c_async` takes $C$ polls to finish

The rust compiler will generate `BlackBox` as to complete after $A + B + C$ `poll`s.

We can see that we do not necessarily need to run all the tasks of `run_async` at once. However, the prints should still occur sequentially. Running `run_async`, we get

```
async a
async b
async c
```
with `time elapsed: 6s`.

## Concurrent

Remember: the Rust compiler compiles the `run_async` function into a struct which has a `poll` method. The `async` functions within `run_async` have a similar interface and are `poll`'d upon.
This means the Rust compiler delegates `BlackBox#poll`

- to `do_a_async_BlackBox#poll` until it returns `true`
- ... then to `do_b_async_BlackBox#poll` until it returns `true`
- ... then to `do_c_async_BlackBox#poll` until it returns `true`
- ... then returns `true`

We can instead using a `join!` macro, where each call to `poll` on `run_concurrent` will call `poll` on both `a`, `b`, and `c`, progressing the function **concurrently**. This is not at odds with the definition of asynchronous.

In this scenario, we will only need to poll $\min\(A,B,C\)$ times.

```rust
// runs "concurrently", at "the same time."
async fn run_concurrent() {
  // run all a, b and c at once
  let a = do_a_async()
  let b = do_b_async();
  let c = do_c_async();
  
  // await all of them at once
  futures::join!(a, b, c);
}
```

Running `run_concurrent`, we get:
```
async c
async b
async a
```
with `time elapsed: 3s`.

# Concurrency Models
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

Although green threads can provide many benefits, they are not suitable for all types of applications. Green threads can be inefficient when used with multiple processors (in this case they need to be built on top of OS threads), or when performing blocking operations such as waiting for I/O or communication with other processes. In such cases, an application will benefit more from using traditional OS threads.

The language runtime does not have a way to detect if you use OS-level thread blocking APIs, and so you'll block all your green threads and the language can't put other green threads to run while waiting, because only the OS can play with scheduling around OS blocking calls

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

[Kotlin a languages which embraces coroutines](https://kotlinlang.org/docs/coroutines-guide.html). They take a unique approach to `async/await` where the `.await` keyword is assumed so sequential code
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

# Naïve `async fn` Impl
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

# Suspending Methods

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

TODO: As far as I am aware there is no good solution if there is no `'static` lifetime in async-world. I am going to look into this and try to design my own API.

- One can the recommendation by [`@nagisa`](https://blog.japaric.io/safe-dma) for a non-async workaround (it is jank)

## readiness-based

- https://cfsamson.github.io/book-exploring-async-basics/6_epoll_kqueue_iocp.html

Like `epoll`. Tell us when a socket is ready to be read from, but does not transfer data (i.e., do reading for us).

## Informed polling

This is the model that Rust uses. It has somewhat famously been criticized in
the [Hacker News](https://news.ycombinator.com/item?id=26406989) response to ["Why asynchronous Rust doesn't work](https://eta.st/2021/03/08/async-rust-2.html)."
In the Hacker News thread, [newpavlov](https://news.ycombinator.com/user?id=newpavlov) mentions

> A bigger problem in my opinion is that Rust has chosen to follow the poll-based model (you can say that it was effectively designed around epoll),
> while the completion-based one (e.g. io-uring and IOCP) with high probability will be the way of doing async in future
> (especially in the light of Spectre and Meltdown).

Zamalek replies:

> This [(newpavlov's response)] is an inaccurate simplification that, admittedly, their own literature has perpetuated.
> Rust uses **informed polling**: the resource can wake the scheduler at any time and tell it to poll.
> When this occurs it is virtually identical to completion-based async (sans some small implementation details).

It even enables **stateless informed polling** which cannot be accomplished by the normal means. TODO: describe state less informed polling

> Normally only the executor would provide the waker implementation, so you only learn which top-level future (task) needs to be re-polled,
> but not what specific future within that task is ready to proceed.
> However, some future combinators also use a custom waker,
> so they can be more precise about which specific future within the task should be re-polled.

For instance, a future which selects between multiple tasks might include a custom waker (TODO: more concrete example)

# Concrete Future Implementation
The _actual_ Rust implementation of `Future` is such

```rust
pub trait Future {
    type Output;

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}
```

There are a lot of concepts to take in here.

## Memory Pinning

The trait requires the first parameter to be `Pin<&mut Self>`. This is a concept called [memory pinning](https://doc.rust-lang.org/std/pin/index.html).

Memory pinning is a way to provide mutable references to data that can never be moved in memory. This allows us to have self-references, which `async fn` are built upon.

## Context

- `Context` is what makes informed polling _informed_.

{:.note}
Mainly designed by [Taylor Cramer](https://github.com/cramertj)

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

## Poll

Finally, the last piece of the puzzle is the `poll` method.

This method is called by the runtime to check if the future is ready. The `poll` method takes the `Pin<&mut Self>`
and the `Context` and returns a [`Poll`](https://doc.rust-lang.org/std/task/enum.Poll.html) enum.

The `Poll` enum is an enum with two variants:

- `Poll::Pending` means the future is not ready yet.
- `Poll::Ready` means the future is ready and contains a value of the type `Future::Output`.

The `poll` method should be called in a loop by the runtime until it returns `Poll::Ready`.

## Conclusion

The Rust implementation of `Future` is a powerful tool for writing asynchronous code. We can see how it uses
pinning, contexts, and raw pointers to achieve its functionality. This implementation is also extensible, allowing
runtimes to customize behavior by providing custom `Waker`s.

# Structured Concurrency
Structured concurrency was popularized by [Notes on structured concurrency, or: Go statement considered harmful](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/), which argues that the go statement (which launch `goroutines`—Go's implementation of coroutines) is harmful due first and foremost to the fact that

[//]: # (## Kotlin)

[//]: # ()
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

- [What color is your function](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/)

# Runtime Landscape

## Popular runtimes

The two most popular async runtimes for Rust are [Tokio](https://tokio.rs/) and [async-std](https://async.rs/).

Tokio is a mature and feature-rich runtime that is designed to be the foundation of a modern, reliable, and scalable server-side application platform. It provides a high-level API for writing asynchronous I/O-driven applications.

Async-std is a newer runtime, but it is quickly gaining popularity and is becoming the de facto standard for Rust async programming. It provides a powerful API that makes it easy to work with asynchronous tasks and provides a rich set of features and capabilities. In addition, it is more lightweight than Tokio and offers better performance and scalability.

## Generic over runtime

[//]: # (TODO)

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
|-------------------------------|-----------------------|----------------|-----------------|
| **`spawn_blocking`**          | Suboptimal            | OK             | No              |
| **`rayon`** (thread pool lib) | OK                    | No             | No              |
| **Dedicated thread**          | OK                    | OK             | OK              |

# Tokio Runtime Implementation

It can be useful to understand the inner minutia of an async runtime by examining the important components of the
[tokio](https://github.com/tokio-rs/tokio) runtime.

<!-- ## [The Internals of Deno 🦕](https://choubey.gitbook.io/internals-of-deno/architecture/tokio) -->
<!-- - Tokio tasks are asynchronous green-threads. -->

<!-- ## [Tokio blog 📝](https://tokio.rs/blog) -->

## [Making the Tokio scheduler 10x faster](https://tokio.rs/blog/2019-10-scheduler)

- Uses the [**M:N threading pattern**](https://en.wikipedia.org/wiki/Thread_(computing)#M:N_(hybrid_threading)) where many user land tasks are multiplexed on a few operating system threads.
- At the most basic level, the scheduler can be modeled as
    - **run queue**
    - **processor** that drains the queue.
        - A processor is a bit of code that runs on a thread. In pseudocode, it does:

### Processor
```rust
while let Some(task) = self.queue.pop() {
    task.run();
}
```

When a task becomes runnable, it is inserted into the _run queue_.

**Tokio chooses to use multiple threads** (although it is possible to design a system where resources, tasks, and the processor all exist on a single thread)

### Designing Multi-Threaded Scheduler

There are two ways:
- One global run queue, many processors.
- Many processors, each with their own run queue.

#### One queue, many processors

- Each processor pops from the head of the queue, blocking the thread if no task is available.
- Run queue must support both _multiple producers and multiple consumer_
- Uses [intrusive](https://stackoverflow.com/a/5004391/4889030) linked list
    - task structure includes a pointer to the next task in the run queue instead of wrapping the task with a linked list node
- Can use [lock-free push](https://www.1024cores.net/home/lock-free-algorithms/queues/intrusive-mpsc-node-based-queue)
    - popping generally requires a mutex (it is technically possible to implement a lock-free multi-consumer queue. However, in practice the overhead needed to correctly avoid locks is greater than just using a mutex.)

{: .warning }
All processors contend on the head of the queue, making this method inefficient.

#### Concurrency and mechanical sympathy.

- Must take advantage of [**Mechanical Symphony**](https://mechanical-sympathy.blogspot.com/)—the way hardware operates.
    - Maximize the amount of CPU instructions per memory access
    - Concurrent threads similar to single threads until concurrent mutations happen to the same cache line or [**sequential consistency**](https://en.cppreference.com/w/cpp/atomic/memory_order#Sequentially-consistent_ordering) is requested.
        - then the [CPU's cache coherence protocol](https://en.wikipedia.org/wiki/MESI_protocol) will have to start working to ensure that each CPU's cache stays up to date.
    -

{: .important}
TL;DR: avoid cross thread synchronization as much as possible because it is slow.

#### Many processors, each with their own run queue

- multiple single-threaded schedulers
- tasks are pinned to a specific processor
- avoids the problem of synchronization
- still needs to be thread-safe way to inject tasks into the scheduler (since we can queue a task from any thread)
    - **each processor has two run queues**
        - an unsynchronized queue
        - thread-safe queue
            - this strategy used by [SeaStar](https://seastar.io/)

Unless the workload is entirely uniform, some processors will become idle while other processors are under load
- because tasks are pinned to a specific processor

{: .warning}
general purpose schedulers tend to avoid this model

#### Work-stealing scheduler

- Each processor maintains its own run queue
- processors drain their local run queue
- when a processor becomes idle, it checks sibling processor run queues and attempts to steal from them
- A processor will go to sleep only once it fails to find work from sibling run queues.

{: .note}
choice of Go, Erlang, Java

{: .warning}
If not done correctly, the synchronization overhead to implement the work-stealing model can be greater than the benefits gained.

### Next generation Tokio scheduler

#### A better run queue
- original Tokio scheduler used [crossbeam](https://github.com/crossbeam-rs/crossbeam) deque implementation, which is single-producer, multi-consumer deque
    - ability for the deque to grow comes at a complexity and overhead cost
    - **Fix: use a fixed size per-process queue**
        - When the queue is full, instead of growing the local queue, the task is pushed into a global, multi-consumer, multi-producer, queue
            - Processors will need to occasionally check this global queue, but at a much less frequent rate than the local queue.

{:.note}
A key thing to remember about the work-stealing use case is that, under load, there is almost no contention on the queues since each processor only accesses its own queue

#### Golang-inspired fixed size single-producer, multi-consumer queue


```rust
struct Queue {
    /// Concurrently updated by many threads.
    head: AtomicU32,

    /// Only updated by producer thread but read by many threads.
    tail: AtomicU32,

    /// Masks the head / tail position value to obtain the index in the buffer.
    mask: usize,

    /// Stores the tasks.
    buffer: Box<[MaybeUninit<Task>]>,
}
```

Pushing into the queue is done by a single thread:

```rust
loop {
    let head = self.head.load(Acquire);

    // safety: this is the **only** thread that updates this cell.
    let tail = self.tail.unsync_load();

    if tail.wrapping_sub(head) < self.buffer.len() as u32 {
        // Map the position to a slot index.
        let idx = tail as usize & self.mask;

        // Don't drop the previous value in `buffer[idx]` because
        // it is uninitialized memory.
        self.buffer[idx].as_mut_ptr().write(task);

        // Make the task available
        self.tail.store(tail.wrapping_add(1), Release);

        return;
    }

    // The local buffer is full. Push a batch of work to the global
    // queue.
    match self.push_overflow(task, head, tail, global) {
        Ok(_) => return,
        // Lost the race, try again
        Err(v) => task = v,
    }
}
```


{:.important}
No sequential consistency required in implementation (read-modify-write operations)

- on x86 chips, all loads / stores are already "atomic" (so no syncronization)
- Acquire ordering is pretty weak. It may return stale values
    - a stale load will result in seeing the run queue as more full than it actually is.


The local pop (from processor that owns queue)
```rust
loop {
    let head = self.head.load(Acquire);

    // safety: this is the **only** thread that updates this cell.
    let tail = self.tail.unsync_load();

    if head == tail {
        // queue is empty
        return None;
    }

    // Map the head position to a slot index.
    let idx = head as usize & self.mask;

    let task = self.buffer[idx].as_ptr().read();

    // Attempt to claim the task read above.
    let actual = self
        .head
        .compare_and_swap(head, head.wrapping_add(1), Release);

    if actual == head {
        return Some(task.assume_init());
    }
}
```
- primary overhead comes from the `compare_and_swap`.

### Optimizing for message passing patterns

- suppose `task_a` is sending messages to `task_b`
- there can be significant latency between the time the message is sent and `task_b` gets executed.
- Further, "hot" data, such as the message, is stored in the CPUs cache when it is sent but by the time `task_b` gets scheduled, there is a high probability that the relevant caches have gotten purged.

{:.important}
Solution is to use optimization (also found in Go's and Kotlin's schedulers)

- When a task transitions to the runnable state, instead of pushing it to the back of the run queue, it is stored in a special "next task" slot.
- The processor will always check this slot before checking the run queue. When inserting a task into this slot, if a task is already stored in it, the old task is removed from the slot and pushed to the back of the run queue.
- In the message passing case, this will result in the receiver of the message to be scheduled to run next.

### Search State: Throttle stealing

- work-stealing scheduler steals from random process
- However, **it is common for many processors to finish processing their run queue around the same time**
    - Randomly picking the starting point helps reduce contention, but it can still be pretty bad.
- new scheduler limits the number of concurrent processors performing steal operation
    - max number of searchers (max number of `search_state` is half the total number of processors

{:.note}
**searching state** is the number of threads which are currently searching for new tasks

- Once in the searching state, the processor attempts to steal from sibling workers and checks the global queue.

- TODO: explaining how searching works
- TODO asdasd

### Sibling Notifications & Reducing cross thread synchronization
- **sibling notification**: a processor notifies a sibling when it observes new tasks
    - If the sibling is sleeping, it
        - wakes up
        - steals tasks
    - action also is responsible for establishing the necessary synchronization for the sibling processor
    - notification only happens if there are no workers in the searching state (if there are searching workers, then there's no need to wake them up. They're already awake.)
        - When a worker is notified, it is immediately transitioned to the searching state.
        - When a processor in the searching state finds new tasks, it will first transition out of the searching state, then notify another processor.

#### Example: `epoll`

TODO: look into this

- Suppose we use `epoll` to schedule a batch of tasks at once
- first one will result in notifying a processor
- processor is now in the searching state
- rest of the scheduled tasks in the batch will not notify a processor as there is at least one in the searching state
- notified processor will steal half the tasks in the batch
    - notify another processor
    - find tasks from one of the first two processors and steal half of those
    - smooth ramp up of processors as well as rapid load balancing of tasks.

#### Waker implementation

### Reducing Allocations
- Tokio scheduler only requires a single allocation per task

#### Naïve Allocator

```rust
struct Task {
    /// All state needed to manage the task
    state: TaskState,

    /// The logic to run is represented as a future trait object.
    future: Box<dyn Future<Output = ()>>,
}
```





- https://choubey.gitbook.io/internals-of-deno/architecture/tokio
-
- https://tokio.rs/blog/2021-07-tokio-uring

TODO

