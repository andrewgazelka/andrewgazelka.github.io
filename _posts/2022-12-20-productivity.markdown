---
layout: post
title: "Meaningful Productivity"
date: 2022-12-20 13:00:00 -0700
categories: productivity
toc: true
---

**I am planning on expanding this article in the future. Feel open to making a PR/issue to [my blog on GitHub](https://github.com/andrewgazelka/andrewgazelka.github.io).**

---

There are at the very minimum hundreds of TODO applications available. Every application I have tried has gotten very clunky the more 
tasks I add. Often it is hard for me to figure out which item I should focus on at a certain time. Complicating matters even further, the order in which I should complete tasks depends on how close I am to their respective due date.

To solve this issue, we will define an equation which produces a priority and use [Notion](https://www.notion.so/) to automatically sort tasks
by that priority.

The final product is the image below:

![Final Product](/assets/TODO4.png)

# Productivity
Let us define productivity as *the quantity value gained per unit of time* or

$$
\begin{align}
\text{productivity} = \frac{\text{value}}{\text{time}}
\end{align}
$$

or even more precisely

$$
\begin{align}
\text{productivity}(t) = \frac{dv}{dt}
\end{align}
$$

where $v$ is the value gain, and $t$ is the amount of time. 

## Measurement

Value is an arbitrary measurement. For an organization, value might be directly proportional to the increase in revenue or profit a task might achieve.
For an employee it might be directly proportional to an increase in raise they might receive.

Of course, this is hard to quantify, and it is usually impossible to have the precision in foresight to know exactly the _value_ of a task. 
However, if we think of value as a general heuristic for these measurements, it can still be useful. 
Ideally, there will be an approximately linear relationship between the value assigned and whatever value is being mapped to. This allows us to maximize
what we derive our value from if we do tasks that are ranked as more productive before those that are not.

## Alignment 

If an employee and their organization are highly aligned, their measurements of value will be highly correlated. 
In fact, I will define them being **perfectly aligned** if the tasks ordered by value for the employee are the same as tasks ordered by value for the organization.

Ideally, perfect alignment occurs. However, this is often not the case. An example where the company and individual incentives are misaligned would be if the individual is pressured to build something that they know does not make sense to build (perhaps for safety concerns) just because their boss thinks it is sounds like a good idea.

## The "Term" for Value

It is important to have a consistent timeline for measuring value between tasks. John Maynard Keynes [is attributed to saying](<(https://www.goodreads.com/quotes/6757924-in-the-long-run-we-are-all-dead-economists-set)>)

> In the long run, we are all dead

For this reason, and due to the nature of chaos, I believe it is most effective to measure value over the midterm: perhaps a year, two years, or a decade.

Someone who truly believes in measuring in the long term might instead think in terms of millennia.

This "extreme" thinking is often used by devout followers of the Effective Altruism movement and has been criticized by the "Waking Up" podcast host Sam Harris as hypothetically being good but 
in practice being a bad heuristic. In fact, [when interviewing neuroscientist and philosopher Dr. Erik Hoel](https://www.youtube.com/watch?v=yGxl5k6Tz48), Erik furthers Sam's claim and mentions 
he believes this category of extreme thinking disregarding intuition might have actually been one of
the main reasons for the fall of FTX. The creator of FTX, Sam Bankman-Fried, is a well-known member of the Effective Altruism movement.

# Implementing with Notion ✍

Let us make a [Notion](https://www.notion.so/) table with a **value** and **time** column, and **priority** column where we use equation (1) for priority.

![TODO1](/assets/TODO1.png)

## Exponential Rating

We will use Fibonacci Numbers for value and priority.

```text
1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610
```

This is because the growth rate of Fibonacci numbers is [approximately exponential](https://en.wikipedia.org/wiki/Random_Fibonacci_sequence#:~:text=Growth%20rate,-Johannes%20Kepler%20discovered&text=It%20demonstrates%20that%20the%20Fibonacci,is%20the%20number%20of%20factors.) (grows at the golden number).
For some things—and from my experience—we tend to be better at thinking in terms of exponential/logarithmic terms than
in linear. [We do this for sound, for instance](https://www.audiocheck.net/soundtests_nonlinear.php).
Values and time being discretized to roughly exponential numbers force us to find the true value or priority of
a task, not the human-perceived "log" of value or priority.

## Rounding

The provided image uses rounding.
However, this will not be useful if we have $\text{time} > \text{value}$, as we will either get a $1$ or $0$, which
is not useful for sorting. To correct this, we can multiply by `100` beforehand.

![TODO2](/assets/TODO2.png)

## Deadlines
The current priority of a task assumes we have an infinite time to complete each task. However, this is not usually accurate because a due date is imposed. Even if an organization does not impose one on the individual, the organization itself might have one imposed on them by an investor.

Therefore, we will add another column: `Due`.
We can then create another column Called `T-` which includes the number of days until the task is due.

Suppose we have a task that has a priority of $p$ when not considering the due date. Let us call the updated formula
for priority $\text{priority}' = p'$. Let us have a few qualifications:

1. `p'` grows as `T-` decreases
2. `p'` grows faster `T-` decreases
3. `T- >> 0` we want $p' = p$
4. When `T- = 1` we want $p'$ to be MUCH larger than when `T- >> 0`
5. When `T- = 0` we want $p'$ to be MUCH larger than when `T- = 1`

A good candidate would be an exponential function

$$
p' = p\left(ae^{bx +c } + d\right)
$$

where $x$ is `T-`.

Let us start with $b$ = $-1$, $a = 1$, $c = 0$, $d = 1$. We have

$$
\begin{align}
p' = p(e^{-x} + 1)
\end{align}
$$

This meets requirements one through three. However, this does not meet requirements four and five. Let us make
$c = 3$, i.e., things will really start getting magnified when something is due in 3 days.

$$
\begin{align}
p = p(e^{-x + 3} + 1)
\end{align}
$$

When

- $x = 0$, we have $p \approx 21p$
- $x = 1$, we have $p \approx 8p$
- $x = 2$, we have $p \approx 4p$
- $x = 3$, we have $p \approx 2p$
- $x = 4$, we have $p \approx 1.3p$

Assuming the time required to complete the task is due-date-invariant, we can use formulas (1) and (4) to get

$$
\begin{align}
v' = v'(e^{-x + 3} + 1)
\end{align},
$$
where $v$ is value and $v'$ is modified value.

To make something due at 5 PM (i.e., 17:00), we can have the formula:

```javascript
prop("Deadline") ? (dateBetween(prop("Deadline"), now(), "hours") + 17) / 24 : 100
```

And for $v'$ we have
```javascript
round(prop("SimpleValue") * (pow(e, -prop("T-") + 3) + 1))
```

![TODO3](/assets/TODO3.png)

## Task Duration

As [@wffirilat](https://github.com/wffirilat) mentioned to me, the number `3` is somewhat arbitrary. It can instead be helpful to mark the number of times a task takes

Let us add a new field `ETA` which is the estimated time the task will be in days.

We can then create a field `Conservative ETA`, which is `ETA * 1.5` and have `Value` equivalent to. However, we already have a time field—let us change `Time` from arbitrary `Time` to `Hours`.

```javascript
round(prop("SimpleValue") * (pow(e, -prop("T-") + prop("Time") * 2 / 24) + 1))
```

## Dependent and Blocking tasks

Suppose we have task $A$ that blocks task $B$. Let us have the following considerations, where 
$p_t$ is the original priority of task $t$, and $p'_t$ is the priority of task $t$ when adjusted for blocking
tasks

1. If $p_B$ is high, then $p'_A \gg p_A$
2. If $p_B$ is zero, then $p'_A = p_A$

However, this gets confusing. If we have a million tasks with priority 0.1, it is hard to think of a formula that will not make the $p_A$ priority super high.

Instead, let us think in terms of super tasks:

Let us denote $v_t$ as the value of task $t$ and $v'_t$ as the value of completing the super task, where a super task is that task and tasks which block it. 

In the example scenario, we have

$$
v'_A = v_A + v_B
$$

or

$$
\begin{align}
v'_t = v_t + \Sigma_{\text{task} \in \text{blocking(t)}} v_\text{task}
\end{align}
$$

if given time $T_t$ is the time to complete task $t$ and $T'$ is the super task time, we have

$$
T'_A = v_A + v_B
$$

or 

$$
\begin{align}
T'_t = T_t + \Sigma_{\text{task} \in \text{blocking(t)}} T_\text{task}
\end{align}
$$

so by (1), we have

$$
\begin{align}
p'_t = \frac{v'_t}{T'_t}
\end{align}
$$

## Useable Implementation

Below is a useable implementation. I have also made some QOL changes, including but not limited to the following:

- `Value` defaults to `3` when not selected
- `Hours` defaults to `3` when not selected
- `Deadline` acts as if it is thousands of days in the future if it is not selected

[![TODO4](/assets/TODO4.png)](https://judicious-mistake-368.notion.site/6c236035b4654886a2eeca298f17ce92?v=c05b9b429ee243838888f2db37610103)

To use it, you can go to [the following link](https://judicious-mistake-368.notion.site/6c236035b4654886a2eeca298f17ce92?v=c05b9b429ee243838888f2db37610103).

# Pruning ✂️

Suppose we have tasks

- a
- b
- c

Where $p_a > p_b > p_c$. We would think we should do task $a$, then $b$, then $c$. 
However, **if there is no due date for the tasks** and if time and value of a task is order-invariant, at the end of the day the productivity 
gained from doing

- Task A, then B, then C
- Task B, then A, then C
- Task C, then B, then A
- ...

is all the same. 

In this scenario, **the benefit of ranking with priority is we can prune low-priority tasks**.

# Delegation 📩 

- $V$ is value of task before delegation
- $V_d$ is the value of a certain task when delegated
- $t$ is time it will task to do task before delegation
- $t_d$ is time it will take to do task when delegated
- $T$ is the time it will take to transfer the task between the original user and delegation

## Difference in Values

Assuming the task is done of the same quality

$$
\begin{align}
V_d \leq V
\end{align}
$$

since there can be a cost of delegating which can directly be factored into the value of the task. 

- **Where we measure value at an organization level**: $V_d \approx V$
  - the person who is being delegated to might cost money to hire
- **Where we measure value at an individual level** $V_d \approx 0$
  - the individual will not get credit for the work done. In this case, usually $V_d \approx 0$ or potentially even $V_d < 0$ if it is a task the 
  delegatee thinks the delegator should have done

*Note: that we are not considering opportunity cost, as 
opportunity cost is hard to evaluate and always dynamic based on the current opportunities. Instead, we opt for values to be more static and to only do
tasks which have the highest value.*

As an employee of a company, it is usually a good idea to have your measure of value a combination of organization and strict-individual.

## Organizational Self-Delegation Strategy

We can share the Notion table cross team member

- Since $V_d \approx V$ if we are delegating in the organization (there is no extra contractor who needs to be hired),
we can assume $V = V_d$, so we do not need a separate value column.
- Since we are allowing self-delegation, $T = 0$. 
- The task should be assigned to the user who minimizes $t$ without making them over capacity 
  - We will make this value $t$ instead of having a separate $t_d$
  - Tasks can be assigned at week-long intervals, so capacity can be a meaningful measure and people can group together to hive-mind time estimates.
