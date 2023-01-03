---
layout: page
title: Tokio Runtime Implementation
parent: Concurrent Rust Deep Dive
nav_order: 7
---

# Tokio Runtime Implementation
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

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

---

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
- 

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

