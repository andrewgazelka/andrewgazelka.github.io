---
layout: post
title: "Rust Named/Optional Parameters"
---

Rust doesn't support named or optional parameters. This blog post will explore alternate
ways to achieve similar functionality.

## Using raw `struct`s

Given
```rust
struct Request {
    url: String,
    method: String,
    body: Option<String>,
    headers: Option<HashMap<String, String>>,
}
```
We can quite easily create a `Request` using the `Request` struct directly:

```rust
let request = Request {
    url: "https://example.com".to_string(),
    method: "GET".to_string(),
    body: None,
    headers: None,
};
```

However, this is not very ergonomic. 
- We have to specify all fields, even if we don't want to
- We have to call `to_string()`, for `String` fields, adding unnecessary boilerplate

## Using a `Builder` pattern
```rust
struct Request {
    url: String,
    method: String,
    body: Option<String>,
    headers: Option<HashMap<String, String>>,
}

impl Request {
    fn new(url: impl Into<String>) -> Self {
        Self {
            url: url.into(),
            method: "GET".to_string(),
            body: None,
            headers: None,
        }
    }
    
    fn method(mut self, method: impl Into<String>) -> Self {
        self.method = method.into();
        self
    }
    
    fn body(mut self, body: impl Into<String>) -> Self {
        self.body = Some(body.into());
        self
    }
    
    fn header(mut self, key: impl Into<String>, value: impl Into<String>) -> Self {
        self.headers.get_or_insert_with(HashMap::new).insert(key.into(), value.into());
        self
    }
}
```
this allows us to create a `Request` in a more ergonomic way. However, this is still not great because
1. This is a lot of boilerplate
2. We still don't have named parameters for required fields

## Using a partial `struct`

```rust
struct PartialRequest {
    url: String,
}

struct Request {
    url: String,
    method: String,
    body: Option<String>,
    headers: Option<HashMap<String, String>>,
}

impl PartialRequest {
    fn combine_defaults(self) -> Request {
        Request {
            url: self.url,
            method: "GET".to_string(),
            body: None,
            headers: None,
        }
    }
}

impl Request {
    fn method(self, method: impl Into<String>) -> Request {
        Request {
            url: self.url,
            method: method.into(),
            body: None,
            headers: None,
        }
    }

    // ...
}
```
Yet doing this, we 
- have to chain methods more
- lose the ability to automatically use `Into<String` for the required fields

## `derive_builder`

- This includes methods to set all fields (optional and required)
- includes runtime error if a required field is not set.

## `rust-typed-builder`

- This includes methods to set all fields (optional and required)
- Compile time error if a required field is not set.



