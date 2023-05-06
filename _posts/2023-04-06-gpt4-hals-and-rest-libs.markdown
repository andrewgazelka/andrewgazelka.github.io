---
layout: post
title: "GPT4 HALs and REST libraries"
---

[//]: # (# Harnessing the Power of Language Models for Hardware Abstraction and REST APIs in Rust)

Hardware Abstraction Layers (HALs) are software components that provide a uniform interface to interact with hardware,
abstracting away the underlying complexities. REST libraries, on the other hand, simplify communication with RESTful
APIs, providing convenient methods to make requests and handle responses.

# Pros & Cons of HALs & REST Libraries

## Benefits

HALs and REST libraries are essential tools that speed up development, especially in an age before GPT-4. They
allow developers to focus on writing application logic without having to worry about low-level hardware details or the
intricacies of API communication.

## Limitations

Despite their benefits, HALs and REST libraries can also limit development:

1. **HALs:**
    - Abstract away hardware, potentially preventing you from performing specific tasks.
    - May suffer from poor documentation or maintenance.
    - Can cause unexpected behavior and make debugging difficult.
2. **(Thicc) REST libraries:**
    - Abstract away the API, potentially preventing you from performing specific tasks.
    - May suffer from poor maintenance for your chosen language.

REST APIs which are instead one-to-one mappings of the API's endpoints can be considered "thin" REST libraries and
do not suffer from the same limitations as thick REST libraries. Generally, the one-to-one mapping of the HAL is
instead considered a "Peripheral Access Crate" (PAC).

# Peripheral Access Crates (PACs)

The PAC is a one-to-one mapping from a microcontroller's registers to code.
An example of a PAC is the `stm32h7` library, which is a Peripheral Access Crate (PAC) for the STM32 family of
microcontrollers. PACs provide a thin wrapper around hardware, offering a more direct way to interact with it.

## Example: Using a PAC to Blink an LED

```rust
#[entry]
fn main() -> ! {
    let peripherals = stm32h7x3::Peripherals::take().unwrap();
    let pwr = &peripherals.PWR;
    let rcc = &peripherals.RCC;

    // Enable the GPIO clock (using the PAC)
    rcc.ahb4enr.modify(|_, w| w.gpioden().set_bit());

    // Enable voltage scaling (using the PAC)
    pwr.cr3.modify(|_, w| w.svden().enabled());

    // Configure GPIO pin D15 as output for the LED (using the PAC)
    let gpiod = &peripherals.GPIOD;
    gpiod.moder.modify(|_, w| w.moder15().output());

    loop {
        // Toggle the LED (using the PAC)
        gpiod.odr.modify(|r, w| w.odr15().bit(!r.odr15().bit()));

        // Delay (not precise)
        asm::delay(8_000_000);
    }
}
```

# GPT-4 for thin REST and PAC Calls

GPT-4 makes it much easier to implement logic that combines multiple REST or PAC calls. While reading
documentation to combine these calls is not too difficult, it can be time-consuming. Using GPT-4, you can feed in
the REST API/reference manual docs and obtain code that works for your specific use case, saving a considerable amount
of time. Since the task of transferring from the style of an english doc to code is not creating new knowledge—but just
style transferring—GPT-4 generally performs quite well. Even without docs, GPT-4 usually still generates code that
mostly works—albeit with a few modifications.

## Using an `svd` file to generate a PAC

An `svd` file is a standardized XML format for describing the registers of a microcontroller. It is used by PACs to
generate code for interacting with the microcontroller's registers. A portion of the `svd` file for the COMP1 peripheral
is listed below:

```html

<peripheral>
    <name>COMP1</name>
    <description>COMP1</description>
    <groupName>COMP1</groupName>
    <!--  ...-->
    <registers>
        <!-- ... -->
        <register>
            <name>CFGR1</name>
            <displayName>CFGR1</displayName>
            <description>Comparator configuration register 1</description>
            <addressOffset>0xC</addressOffset>
            <size>0x20</size>
            <access>read-write</access>
            <resetValue>0x00000000</resetValue>
            <fields>
                <!-- ... -->
                <field>
                    <name>POLARITY</name>
                    <description>COMP channel 1 polarity selection
                        bit
                    </description>
                    <bitOffset>3</bitOffset>
                    <bitWidth>1</bitWidth>
                </field>
                <!-- ... -->
            </fields>
        </register>
        <!-- ... -->
    </registers>
</peripheral>
```

The full SVD containing COMP1 can be downloaded here: [comp1.svd](/assets/comp1.svd). The full STM32H743 SVD (which
contains all peripherals) can be downloaded here: [STM32H743.svd](/assets/STM32H743.svd).

Concatenating the full `comp1.svd` with the prompt:

> in Rust using the stm32h7 crate modify registers of COMP1 to negate the output of the comparison

and pasting into ChatGPT(4) yields the code:

```rust
// Add this to your Cargo.toml
// [dependencies]
// stm32h7 = "0.13.0"

use stm32h7::stm32h7x3;

fn main() {
    // Get access to the device specific peripherals
    let peripherals = stm32h7x3::Peripherals::take().unwrap();

    // Configure the COMP1 peripheral
    configure_comp1(&peripherals);
}

fn configure_comp1(peripherals: &stm32h7x3::Peripherals) {
    // Get access to the COMP1 peripheral
    let comp1 = &peripherals.COMP1;

    // Modify the CFGR1 register to negate the output of the comparison
    comp1.cfgr1.modify(|_, w| w.polarity().set_bit());

    // Add any other configuration as needed
}
```

which is correct.

## Without an `svd`

we obtain

```rust
comp1.csr.modify( | _, w| w.neg().set_bit());
```

which is incorrect code (does not compile and uses wrong registers). This shows that GPT4 understands the
semantics of how registers are set with the `stm32h7` crate, but does not necessarily know what the registers
are without extra context. We are using GPT4 to transform the `[english prompt + SVD] -> [Rust code]` using the
style of the `stm32h7` crate. I have seen GPT4 generate exceptional outputs when all it needs to do is
style transfer and is not generating "new" knowledge.

## Asking for TIM15 (trimmed svd)

I had to trim the indentation and removed bit-offset tags so the SVD file could fit in 8k tokens required by GPT-4.
I do not yet have access to `gpt-4-32k` which can handle up to `32k` tokens. The prompt:

> In Rust using the stm32h7 crate modify registers of TIM15 (OC1) to output a clock duty 50%.
> Show how to set the pre-scalar as well. Include comments

We obtain

```rust
use stm32h7xx_hal::{
    pac::TIM15,
    prelude::*,
};

fn config_tim15(tim15: &TIM15, prescaler: u16) {
    // Set the prescaler
    tim15.psc.write(|w| w.psc().bits(prescaler));

    // Set timer to auto-reload mode and enable auto-reload preload
    tim15.cr1.modify(|_, w| {
        w.opm().continuous()
            .arpe().enabled()
    });

    // Set CCR1 value to half for 50% duty cycle
    let arr = tim15.arr.read().arr().bits();
    tim15.ccr1.write(|w| w.ccr1().bits(arr / 2));

    // Set output compare mode
    tim15.ccmr1_output.modify(|_, w| {
        w.oc1m().pwm_mode1()
            .oc1pe().enabled()
    });

    // Enable capture/compare output for channel 1
    tim15.ccer.modify(|_, w| w.cc1e().set_bit());

    // Enable the timer
    tim15.cr1.modify(|_, w| w.cen().enabled());
}
```

This is mostly correct and can be modified to get:

```rust
 /// Create a new blanking timer and init clock
fn main() {
    // ..

    // Set the prescaler
    tim15.psc.write(|w| w.psc().bits(TIM15_PRESCALER));

    // Set timer to auto-reload mode and enable auto-reload preload
    tim15.cr1.modify(|_, w| {
        w.opm()
            .variant(OPM_A::Disabled)
            .arpe()
            .variant(ARPE_A::Enabled)
    });

    // Set CCR1 value to half for 50% duty cycle
    let arr = tim15.arr.read().arr().bits();
    tim15.ccr1().write(|w| w.ccr().bits(arr / 2));

    // Set output compare mode
    tim15.ccmr1_output()
        .modify(|_, w| w.oc1m().variant(PwmMode1).oc1pe().variant(OC1PE_A::Enabled));

    // Enable capture/compare output for channel 1
    tim15.ccer.modify(|_, w| w.cc1e().set_bit());

    // Enable the timer
    tim15.cr1.modify(|_, w| w.cen().enabled());
}
```

## Asking questions

With the same SVD we can ask

> What is TIM15 OC1. Is OC1 a channel or output source or something? What does it stand for?

and we get:

> TIM15 is a general-purpose timer that can be used for various timing and control tasks in a microcontroller system.
> OC1 (Output Compare 1) is a channel and is an important feature of the TIM15 timer. The acronym "OC" stands for Output
> Compare, which refers to the ability of the timer to compare the counter value with a predefined value stored in a
> register (CCR1 in this case).

> When the counter value matches the value stored in the CCR1 register, an event is generated, which can trigger an
> interrupt, create a pulse on an output pin, or perform some other related action. This functionality can be used for
> generating periodic signals, controlling PWM (Pulse Width Modulation) outputs, and implementing other timing-related
> tasks in the system.

> In summary, OC1 in TIM15 is a channel used for comparing the counter value with a predefined value to trigger specific
> actions, and it stands for Output Compare 1.

## Rust: A Perfect Match for Language Models

Rust is an excellent choice for working with Language Models like GPT-4 for several reasons:

1. **Token efficiency:** Rust has a low token count, which is beneficial since you pay for the number of tokens
   generated by the Language Model.

    - With `serde`, you can use `#[derive(Deserialize)]` and `#[derive(Serialize)]` for a struct, then
      use `serde_json::from_str` and `serde_json::to_string` to convert between JSON and Rust structs without generating
      extra code.
2. **Code verification:** Rust makes it easier to verify the correctness of the generated code.

    - PACs in Rust use `enum`s to represent different registers, ensuring type correctness at compile-time.
    - Rust's strong typing makes it harder for mistakes to go unnoticed, which is crucial when working with Language
      Models, as they can occasionally generate incorrect code.
3. **Clarity:** Rust's syntax and constructs, like `serde`, make it clear what's happening in the code, which is
   important for developers who need to understand and maintain it.

## Conclusion

By combining the power of Rust with GPT-4, you can create efficient, verifiable, and easily understandable code
for your hardware abstraction and REST API needs. This approach allows you to bypass the limitations of traditional HALs
and REST libraries, ultimately leading to more streamlined and effective development processes.
