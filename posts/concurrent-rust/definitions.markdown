---
layout: page
title: Definitions
date: 2023-01-01 04:20:44 -0700
categories: rust concurrency
parent: Concurrent Rust Deep Dive
nav_order: 1
---


# Definitions
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
1. TOC
{:toc}
</details>

## Asynchronous

The prefix "a—" denotes something which is not, so asynchronous should be equivalent to _not synchronous_.

## Synchronous

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/synchronous), synchronous means

> happening, existing, or arising at precisely the same time

---

From these definitions, we can deduce that _asynchronous_ means something that does not occur simultaneously.
[Merriam-Webster](https://www.merriam-webster.com/dictionary/asynchronous) defines _asynchronous_ is a task that is

> not simultaneous or concurrent in time

If you have learned about `async/await` before, this might contradict your beliefs of what asynchronous is. I know it did for me.

On StackExchange, [Mohammad Nazayer writes](https://softwareengineering.stackexchange.com/q/396585/306473):

> If you google the meaning of the words [asynchronous and synchronous] you will get the following:
>
> - Asynchronous: not existing or occurring at the same time
>
> - Synchronous: existing or occurring at the same time.
>
> But it seems like they are used to convey the opposite meaning in programming or computer science

[Doc Brown answers](https://softwareengineering.stackexchange.com/a/396590/306473):

> When one task T1 starts a second task T2, it can happen in the following manner:
>
> > Synchronous: existing or occurring at the same time.
>
> So T2 is guaranteed to be started and executed _inside the time slice of T1_. T1 "waits" for the ending of T2 and can continue processing afterwards. In this sense, T1 and T2 occur "at the same time" (not "in parallel", but in a contiguous time interval).
>
> > Asynchronous: not existing or occurring at the same time.
>
> So the execution time of T2 is now unrelated to T1. It may be executed in parallel, it may happen one second, one minute or several hours later, and T2 may still run when T1 has ended (so to process a result of T2, a new task T3 may be required). In this sense, T1 and T2 are not "occurring at the same time (interval)".
>
> Of course, I agree, the literal definitions appear to be ambiguous when seeing that asynchronous operations nowadays are often used for creating parallel executions.

## Concurrent

So even though a definition of asynchronous is _not concurrent_, it might be easier to use the term concurrency in
substitution for when we will normally use _asyncronous_. When using the modern term asyncronous in programming, we generally instead mean _concurrent_.

According to [Merriam-Webster](https://www.merriam-webster.com/dictionary/concurrence), concurrence is the:

- the simultaneous occurrence of events.
