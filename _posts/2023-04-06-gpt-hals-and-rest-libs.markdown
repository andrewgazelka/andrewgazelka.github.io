---
layout: post
title: "GPT HALs and REST libraries"
---

[//]: # (# Harnessing the Power of Language Models for Hardware Abstraction and REST APIs in Rust)

## Introduction to HALs and REST Libraries

Hardware Abstraction Layers (HALs) are software components that provide a uniform interface to interact with hardware,
abstracting away the underlying complexities. REST libraries, on the other hand, simplify communication with RESTful
APIs, providing convenient methods to make requests and handle responses.

## The Pros and Cons of HALs and REST Libraries

### Benefits

HALs and REST libraries are essential tools that speed up development, especially in an age before GPT-3 and GPT-4. They
allow developers to focus on writing application logic without having to worry about low-level hardware details or the
intricacies of API communication.

### Limitations

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

## The Power of Peripheral Access Crates (PACs)

The PAC is a one-to-one mapping from a microcontroller's registers to code.
An example of a PAC is the `stm32h7` library, which is a Peripheral Access Crate (PAC) for the STM32 family of
microcontrollers. PACs provide a thin wrapper around hardware, offering a more direct way to interact with it.

### Example: Using a PAC to Blink an LED

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

## Leveraging GPT-3/GPT-4 for thin REST and PAC Calls

GPT-3 and GPT-4 make it much easier to implement logic that combines multiple REST or PAC calls. While reading
documentation to combine these calls is not too difficult, it can be time-consuming. Using GPT-3/GPT-4, you can feed in
the REST API/reference manual docs and obtain code that works for your specific use case, saving a considerable amount
of time. Even without the docs, GPT-3/GPT-4 can often still generate code that often works, though it may require some
modifications.

### Using an `svd` file to generate a PAC

The `svd` file is a standardized XML format for describing the registers of a microcontroller. It is used by PACs to
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

Using concatenating the full `comp1.svd` and the prompt

> in Rust using the stm32h7 crate modify registers of COMP1 to negate the output of the comparison

into ChatGPT(4) yields

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

which is correct code.

### Without an `svd`

we obtain

```rust
comp1.csr.modify( | _, w| w.neg().set_bit());
```

which is incorrect code (does not compile and uses wrong registers). This shows that GPT4 understands the
semantics of how registers are set with the `stm32h7` crate, but does not necessarily know what the registers
are without extra context. We are using GPT4 to transform the `[english prompt + SVD] -> [Rust code]` using the
style of the `stm32h7` crate. I have seen GPT4 generate exceptional outputs when all it needs to do is
style transfer and not generating new knowledge.

## Rust: A Perfect Match for Language Models

Rust is an excellent choice for working with Language Models like GPT-3/GPT-4 for several reasons:

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

By combining the power of Rust with GPT-3/GPT-4, you can create efficient, verifiable, and easily understandable code
for your hardware abstraction and REST API needs. This approach allows you to bypass the limitations of traditional HALs
and REST libraries, ultimately leading to more streamlined and effective development processes.
