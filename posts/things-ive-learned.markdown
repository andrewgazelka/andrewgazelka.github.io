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

_This post covers things that I want to record but are too small for an individual post_

## 2023

### 01-Jan

#### 09-Mon

- Melatonin is most useful in small dosages 
  - Start low, go higher
  - For me, .75mg milligrams makes me sleepy
    - [This is similar to the amount our brain typically makes](https://symphonynaturalhealth.com/blogs/blog/melatonin-used-for-more-than-sleep-related-issues-and-why-less-is-more-when-it-comes-to-dose)
  - Lower melatonin is less likely to wake you up in the middle of the night
- iPad Pros (2022) have horrible backlight problems (it is **so** bad)

##### Questions 

Any particular reason why this syntax isn't allowed?
```rust
trait EmbedEngine {
    const SIZE: usize;
    fn embed(input: &str) -> [f64; Self::SIZE];
}
```
i.e., why `SIZE` cannot be associated

##### TODO
- Look into `DeserializeOwned``

```rust
pub trait DeserializeOwned: for<'de> Deserialize<'de> {}
impl<T> DeserializeOwned for T where T: for<'de> Deserialize<'de> {}
```

#### 10-Tue

- [Mailbrew is an excellent way to view RSS feeds in email](https://mailbrew.com/)
- [Superhuman](https://superhuman.com/) is a really nice email client with vim-like bindings, stellar performance, and support for Google and Microsoft. 
- There is an [extension to bring back YouTube dislike 😍](https://chrome.google.com/webstore/detail/return-youtube-dislike/gebbhagfogifgggkldgodflihgfeippi)
- [One can summarize articles using **Bardeen* and OpenAI](https://www.bardeen.ai/playbooks/summarize-current-page-openai)
- [NewsGuard](https://chrome.google.com/webstore/detail/newsguard/hcgajcpgaalgpeholhdooeddllhedegi) uses AI to look at the legitimacy of articles