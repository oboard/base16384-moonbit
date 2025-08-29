# oboard/base16384

[![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/oboard/base16384-moonbit/check.yml)](https://github.com/oboard/base16384-moonbit/actions/workflows/check.yml)
[![License](https://img.shields.io/github/license/oboard/base16384-moonbit)](https://github.com/oboard/base16384-moonbit/blob/main/LICENSE)


Encode binary file to printable utf16be, and vice versa.

It is a MoonBit reimplementation of [base16384](https://github.com/fumiama/base16384).

## API

```moonbit
fn decode(Array[UInt16]) -> ArrayView[Byte]

fn decode_str(String) -> String raise

fn encode(Array[Byte]) -> Array[UInt16]

fn encode_str(String) -> String
```

## Examples

```moonbit

///|
let input = "hello world"
let encoded = @base16384.encode_str(input)
let decoded = @base16384.decode_str(encoded)
inspect(encoded, content="栙擆羼湷槜瓆帀㴄")
inspect(decoded, content="hello world")

```
