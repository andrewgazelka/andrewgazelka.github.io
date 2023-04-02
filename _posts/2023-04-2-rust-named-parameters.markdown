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
fn main() {
    let request = Request {
        url: "https://example.com".to_string(),
        method: "GET".to_string(),
        body: None,
        headers: None,
    };
}
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

This allows us to create a `Request` in a more ergonomic way. However, this is still not great because

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
- lose the ability to automatically use `Into<String>` for the required fields

## Libraries

### `derive_builder`

- This includes methods to set all fields (optional and required)
- includes runtime error if a required field is not set.
    - This is quite unfortunate. 😞

### `rust-typed-builder`

- This includes methods to set all fields (optional and required)
- Compile time error if a required field is not set.
    - Unfortunately, it is hard to tell which methods are required versus optional

## My custom `#[derive(Build)]`

I combine the more traditional Java approach of having a separate method for required parameters.
It is ergonomic, but for me personally not too hacky like `rust-typed-builder`.

Unfortunately, required fields are not named, but I think this is a good tradeoff for not having
decently-hacky code.

```rust
#[derive(Debug, Build, Serialize)]
pub struct ChatRequest {
    #[required]
    pub model: ChatModel,
    pub messages: Vec<Msg>,

    #[serde(skip_serializing_if = "real_is_one")]
    #[default = 1.0]
    pub temperature: f64,

    #[serde(skip_serializing_if = "real_is_one")]
    #[default = 1.0]
    pub top_p: f64,

    #[serde(skip_serializing_if = "int_is_one")]
    #[default = 1]
    pub n: u32,

    #[serde(skip_serializing_if = "empty", rename = "stop")]
    pub stop_at: Vec<String>,
}
```

I find it to be really useful to create your own `#[derive(Build)]` macro, as
it allows you to customize the behavior of the `Builder` pattern to your liking.

For instance:

- All `Vec`s can be appended to with the `${field_name_singular}` method, where `${field_name_singular}` is the name of
  the field it is appending to, but singular.
    - For instance, if the field is `messages`, then the method to append is `message`.
- All `Option`s can be set with the `${field_name}` method, and take in `impl Into<T>` not `Option<T>`
    - I haven't yet found cases where I want the default value to not be `None` for `Option`s, so this is useful
- Any optional field without an explicit `#[default]` attribute will have a default value of `Default::default()`
- All methods take in `impl Into<T>`!
    - Except for integral types, which take in the raw `... | u32 | i32 | u64 | i64 | u128 | i128` types because type
      inference can't otherwise infer the correct type without explicit type annotations.

The macro expands to the following:

```rust
impl ChatRequest {
    pub fn new(model: impl Into<ChatModel>) -> Self {
        Self {
            model: model.into(),
            messages: Default::default(),
            temperature: 1.0,
            top_p: 1.0,
            n: 1,
            stop_at: Default::default()
        }
    }

    pub fn message(mut self, message: impl Into<Msg>) -> Self {
        self.messages.push(message.into());
        self
    }

    pub fn temperature(mut self, temperature: impl Into<f64>) -> Self {
        self.temperature = temperature.into();
        self
    }

    pub fn top_p(mut self, top_p: impl Into<f64>) -> Self {
        self.top_p = top_p.into();
        self
    }

    pub fn n(mut self, n: u32) -> Self {
        self.n = n.into();
        self
    }

    pub fn stop_at(mut self, stop_at: impl Into<String>) -> Self {
        self.stop_at.push(stop_at.into());
        self
    }
}
```



