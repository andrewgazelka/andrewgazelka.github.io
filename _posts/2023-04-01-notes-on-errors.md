---
layout: post
title: "Notes on Errors and Flow in Rust"
---

I am a big fan
of [Go Considered Harmful](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/).
One of the biggest takeaways I got is how important it is to have a well-defined control flow.
Ideally, someone calling your function can just look at the signature of the function and know
it will probably not do something absolutely crazy beyond well-understood and broad rules.
If this is the case, we can then treat the function as a black box and our code will be much easier to reason about.

# Errors

## `.unwrap` is harmful

If a function code calls `.unwrap()`, `.expect()`, or anything panic-related, it is breaking the contract of the
function.
This is because instead of a function just returning a result, it is now returning a result _or panicking_.
Panicking is not part of the function signature, so it is not part of the contract of the function.
However, even if it were, it is nice to allow the callee of the function to decide how to handle the error.
If code panics, to prevent the program from crashing, the caller of the function will have to wrap the function call in
a [`catch_unwind` block](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html),
which is not very ergonomic.

## `Result<T,E>` where `E` is concrete can be harmful

Generally, the first thing I see Rust beginners do after being told to avoid `panic!` is to replace all of their code
with `Result`s. However, this comes with several problems:

### 1. No backtrace

If an unexpected error occurs, the error will propagate all the way up to the top of the call stack before it is
printed out or the code panics. This is an issue because it makes it hard/(nearly possible) to debug the error.

### 2. Complicated Types and boilerplate

There are no anonymous enums in Rust you have to create a new enum for every error type. This is a lot of
boilerplate. For instance if function `foo` returns error `FooError` which has variants `A` and
`B`, and function `bar` returns error `BarError` which has variants `B` and `C`,
then the function `foobar` which calls `foo` and `bar` will have to define a new enum `FooBarError` which has
variants `A`, `B`, and `C`. In addition, to be able to use the `?` operator, the error type must implement
`From<FooError>` and `From<BarError>`. This is a lot of boilerplate.

In a perfect world with anonymous enums, however, this would be an advantage—we could easily `match` over all
error types.

## `Box<dyn Error>` is _better_ but still not great

We can solve the second problem by using `Box<dyn Error>` as the error type.
However, this is still not great because it is still not clear what errors can be returned from a function.
We can also use `io::Error` as the error type, but this is not great because we cannot `match` over the only types
of errors that can be returned from a function.

## Manual, Global Error Types

A perhaps better (but still meh) solution is to define a global error type that can be used in all functions.
This is a good solution because it allows us to easily `match` over all errors that can be returned from a function,
and we do not have to define a new error type for every function. For instance, suppose we are using the libraries

- `serde`
- `reqwest`
- `tokio`

we can define a global error type as follows:

```rust
type Result<T> = std::result::Result<T, Error>;

enum Error {
    Serde(serde::Error),
    Reqwest(reqwest::Error),
    Tokio(tokio::Error),
}

impl From<serde::Error> for Error {
    fn from(e: serde::Error) -> Self {
        Self::Serde(e)
    }
}

impl From<reqwest::Error> for Error {
    fn from(e: reqwest::Error) -> Self {
        Self::Reqwest(e)
    }
}

impl From<tokio::Error> for Error {
    fn from(e: tokio::Error) -> Self {
        Self::Tokio(e)
    }
}
```

Suppose we have a function `foo` that does some serde stuff, a function `bar` that does some `reqwest` stuff, and a
function `foobar` that calls `foo` and `bar`. We can easily `match` over all errors that can be returned
from `foo`, `bar`, and `foobar`:

```rust
fn foo() -> Result<()> {
    // do some serde stuff
}

fn bar() -> Result<()> {
    // do some reqwest stuff
}

fn foobar() -> Result<()> {
    foo()?;
    bar()?;
    Ok(())
}
```

In addition, suppose we are calling `foobar`. We can easily decide how to handle errors as we know the type of error.

```rust
fn main() {
    loop {
        match foobar() {
            Err(Error::Serde(e)) => {
                // perhaps this is an internal error
                return;
            }
            Err(Error::Reqwest(e)) => {
                // perhaps this is just a network error and we can retry
            }
            _ => {}
        }
    }
}
```

Yet we still have the first problem: no backtrace. And furthermore, often the exact context of the error is not
apparent. For instance, if we are calling `foobar` in a loop, we do not know which iteration of the loop the error
occurred on.

## `anyhow`

`anyhow` is a crate that solves both of these problems. It is a library that provides a global error type
and a macro that allows you to easily add context to errors.
In addition, it also provides the ability to downcast errors to their original type. For instance, suppose we are
using the libraries `serde`, `reqwest`, and `tokio` and we have a function `foobar` that calls `foo` and `bar`.

```rust
use anyhow::Result;

fn foo() -> Result<()> {
    // do some serde stuff
}

fn bar() -> Result<()> {
    // do some reqwest stuff
}

fn foobar() -> Result<()> {
    foo()?;
    bar()?;
    Ok(())
}
```

### Matching over errors

We can easily `match` over all errors that can be returned from `foo`, `bar`, and `foobar`:

```rust
fn main() {
    loop {
        match foobar() {
            Err(e) if e.downcast_ref::<serde::Error>().is_some() => {
                // perhaps this is an internal error
                return;
            }
            Err(e) if e.downcast_ref::<reqwest::Error>().is_some() => {
                // perhaps this is just a network error and we can retry
            }
            _ => {}
        }
    }
}
```

### Backtraces

Perhaps one of the most useful features of `anyhow` is that it records the backtrace of the error.
This allows us to easily debug the error. For instance, suppose we are calling `foobar` in a loop, we can easily
determine which iteration of the loop the error occurred on.

```rust
fn main() {
    loop {
        match foobar() {
            Err(e) => {
                eprintln!("error: {}", e);
                eprintln!("backtrace: {}", e.backtrace());
                return;
            }
            _ => {}
        }
    }
}
```

the backtrace is automatically printed out if the error is passed to `panic!` further up the call stack.

### Adding context

`anyhow` also provides utilities for adding context to errors. For instance, suppose we are calling `foobar` in a loop,
and we want to know which iteration of the loop the error occurred on.

```rust
fn run() -> Result<()> {
    for i in 0.. {
        foobar().with_context(|| format!("iteration {}", i))?;
    }
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {}", e);
        eprintln!("backtrace: {}", e.backtrace());
        return;
    }
}
```

## Different approach for public libraries

`anyhow` is great for applications, but it is not great for libraries that specifically
**are not managed by your team**.
If you are confident, the library is sound all errors produced by the library will not be _internal_ errors that need
to be debugged, but instead will be _external_ errors that need to be handled. Therefore, having a backtrace and context
string will not be very useful.

Note, I specifically am talking about libraries that are not managed by your team. If you are managing the library,
then you can just use `anyhow` and be done with it. The errors produced by the library are much more likely to be
_internal_ errors that need to be debugged.

### `tracing`

However, few libraries are perfect. To help debug errors, it can be useful to instead use `tracing` to provide
error log messages in the instance there truly is an error. In addition, the `tracing` library is increadibly helpful
for reasoning about the flow of your program. Often for `async` programs, it is difficult to reason about the flow
because of the `async` nature of the program. `tracing` (even when used with correctly programmed libraries) can
still help the consumers of that library reason about the flow of the program.




