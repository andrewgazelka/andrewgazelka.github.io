---
layout: post
title: "Things I've Learned Journal"
---

# Things I've Learned...
{: .no_toc }

<details open markdown="block">
  <summary>
    Table of contents
  </summary>
  {: .text-delta }
- TOC
{:toc}
</details>

_A log of things I've learned and happen to remember on a given day_

_Covers things that I want to record, but are too small for an individual post_

## 2023

### 01-jan

#### 09-mon

- Melatonin is most useful in small doseages 
  - Start low go higher
  - For me .75mg milligrams makes me sleepy
    - [This is similar to the amount our brain makes normally](https://symphonynaturalhealth.com/blogs/blog/melatonin-used-for-more-than-sleep-related-issues-and-why-less-is-more-when-it-comes-to-dose)
  - Lower melatonin less likely to wake you up in the middle of the night
- iPad Pros (2022) have horrible backlight problems (it is **so** bad)

##### Questions 

any particular reason why this syntax isn't allowed?
```rust
trait EmbedEngine {
    const SIZE: usize;
    fn embed(input: &str) -> [f64; Self::SIZE];
}
```
i.e., why `SIZE` cannot be associated

##### TODO
- look into `DeserializeOwned`

```rust
pub trait DeserializeOwned: for<'de> Deserialize<'de> {}
impl<T> DeserializeOwned for T where T: for<'de> Deserialize<'de> {}
```
