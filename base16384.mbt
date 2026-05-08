///|
/// Converts bytes to 16-bit values by realigning bit boundaries from source
/// width to target width.
///
/// Parameters:
///
/// * `input` : The array of bytes to be converted.
/// * `output_length` : The length of the output array to be created.
/// * `s_width` : The bit width of each source element (typically 8 for bytes).
/// * `t_width` : The bit width of each target element (typically 14 for
///   base16384 encoding).
/// * `s_offset` : The offset to subtract from each source element before
///   processing.
/// * `t_offset` : The offset to add to each target element after processing.
///
/// Returns an array of 16-bit unsigned integers with the realigned bit data.
///
fn align_bytes(
  input : BytesView,
  output_length : Int,
  s_width : Int,
  t_width : Int,
  s_offset : Int,
  t_offset : Int,
) -> Array[UInt16] {
  let mask = (1 << t_width) - 1
  let output = Array::make(output_length, (0).to_uint16())
  let mut offset = 0
  let mut rest = 0
  let mut j = 0
  for i in 0..<input.length() {
    let char = input[i].to_int() - s_offset
    offset += s_width
    while offset >= t_width {
      let bit_offset = offset - t_width
      if j < output_length {
        output[j] = (rest + (char >> bit_offset) + t_offset).to_uint16()
      }
      j += 1
      offset = bit_offset
      rest = 0
    }
    rest += (char << (t_width - offset)) & mask
  }
  if offset > 0 && j < output_length {
    output[j] = (rest + t_offset).to_uint16()
  }
  output
}

///|
fn decode_bytes(
  input : ArrayView[UInt16],
  output_length : Int,
  s_offset : Int,
) -> Bytes {
  let mask = (1 << 8) - 1
  let output = Array::make(output_length, b'\x00')
  let mut offset = 0
  let mut rest = 0
  let mut j = 0
  for i in 0..<input.length() {
    let char = input[i].to_int() - s_offset
    offset += 14
    while offset >= 8 {
      let bit_offset = offset - 8
      if j < output_length {
        output[j] = ((rest + (char >> bit_offset)) & mask).to_byte()
      }
      j += 1
      offset = bit_offset
      rest = 0
    }
    rest += (char << (8 - offset)) & mask
  }
  if offset > 0 && j < output_length {
    output[j] = (rest & mask).to_byte()
  }
  Bytes::from_array(output)
}

///|
fn decode_string_bytes(
  input : String,
  input_length : Int,
  output_length : Int,
  s_offset : Int,
) -> Bytes {
  Bytes::makei(output_length, i => {
    let bit = i * 8
    let unit = bit / 14
    let offset = bit % 14
    let curr = input[unit].to_int() - s_offset
    if offset <= 6 {
      ((curr >> (6 - offset)) & 0xff).to_byte()
    } else {
      let first_bits = 14 - offset
      let second_bits = 8 - first_bits
      let next = if unit + 1 < input_length {
        input[unit + 1].to_int() - s_offset
      } else {
        0
      }
      let left = (curr & ((1 << first_bits) - 1)) << second_bits
      let right = (next >> (14 - second_bits)) & ((1 << second_bits) - 1)
      (left | right).to_byte()
    }
  })
}

///|
fn decoded_length(encoded_length : Int, residue : UInt16) -> Int {
  if residue == 0 {
    encoded_length / 4 * 7
  } else if residue <= 7 {
    let residue_len = residue.to_int()
    let partial_units = (residue_len * 4 + 6) / 7
    (encoded_length - partial_units) / 4 * 7 + residue_len
  } else {
    encoded_length / 4 * 7
  }
}

///|
pub fn encode(input : BytesView) -> Array[UInt16] {
  let outputLength = (input.length() * 4 + 6) / 7 + 1
  let output = align_bytes(input, outputLength, 8, 14, 0, 0x4e00)
  output[outputLength - 1] = input.length().to_uint16() % 7 + 0x3d00
  output
}

///|
/// Decodes a base16384-encoded array of 16-bit values back to the original byte
/// data.
///
/// Parameters:
///
/// * `input` : The array of 16-bit unsigned integers representing
///   base16384-encoded data.
///
/// Returns an `ArrayView[Byte]` containing the decoded byte data. Returns an
/// empty view if the input is empty or contains only the length marker.
///
pub fn decode(input : ArrayView[UInt16]) -> BytesView {
  if input.is_empty() || input.length() == 1 {
    return []
  }
  let length = input.length() - 1
  let residue = input[length] - 0x3d00
  let outLen = decoded_length(length, residue)
  // Exclude the trailing length marker from bit realignment
  let output = decode_bytes(input[0:length], outLen, 0x4e00)
  output[:]
}

///|
/// Encodes a UTF-8 string into a base16384-encoded string representation.
///
/// Parameters:
///
/// * `input` : The UTF-8 string to be encoded.
///
/// Returns a base16384-encoded string where each 16-bit value is stored as two
/// consecutive bytes in little-endian format.
///
pub fn encode_str(input : String) -> String {
  let bytes = @encoding/utf8.encode(input)
  let encoded = encode(bytes[:])
  let encoded_buf = @buffer.new(size_hint=encoded.length() * 2)
  encoded.each(value => encoded_buf.write_uint16_le(value))
  encoded_buf.to_string()
}

///|
/// Decodes a base16384-encoded string back to its original UTF-8 string
/// representation.
///
/// Parameters:
///
/// * `input` : The base16384-encoded string to decode.
///
/// Returns the original UTF-8 string.
///
/// Throws an error of type `Error` if the decoded bytes cannot be converted to
/// a valid UTF-8 string.
///
pub fn decode_str(input : String) -> String raise Error {
  if input.is_empty() || input.length() == 1 {
    return ""
  }
  let length = input.length() - 1
  let residue = input[length] - 0x3d00
  let outLen = decoded_length(length, residue)
  let output = decode_string_bytes(input, length, outLen, 0x4e00)
  @encoding/utf8.decode(output[:])
}

///|
test {
  let input = "hello world"
  let encoded = encode_str(input)
  let decoded = decode_str(encoded)
  inspect(encoded, content="栙擆羼湷槜瓆帀㴄")
  inspect(decoded, content="hello world")
}

///|
test "encode" {
  assert_eq(encode_str(""), "㴀")
  assert_eq(encode_str("1"), "婀㴁")
  assert_eq(encode_str("12"), "婌渀㴂")
  assert_eq(encode_str("123"), "婌焰㴃")
  assert_eq(encode_str("1234"), "婌焳帀㴄")
  assert_eq(encode_str("12345"), "婌焳廔㴅")
  assert_eq(encode_str("123456"), "婌焳廔萀㴆")
  assert_eq(encode_str("1234567"), "婌焳廔萷㴀")
  assert_eq(encode_str("12345678"), "婌焳廔萷尀㴁")
  assert_eq(encode_str("123456789"), "婌焳廔萷導帀㴂")
}

///|
test "decode" {
  assert_eq(decode_str("㴀"), "")
  assert_eq(decode_str("婀㴁"), "1")
  assert_eq(decode_str("婌渀㴂"), "12")
  assert_eq(decode_str("婌焰㴃"), "123")
  assert_eq(decode_str("婌焳帀㴄"), "1234")
  assert_eq(decode_str("婌焳廔㴅"), "12345")
  assert_eq(decode_str("婌焳廔萀㴆"), "123456")
  assert_eq(decode_str("婌焳廔萷㴀"), "1234567")
  assert_eq(decode_str("婌焳廔萷尀㴁"), "12345678")
  assert_eq(decode_str("婌焳廔萷導帀㴂"), "123456789")
}

///|
test "decode preserves trailing zero bytes" {
  let input = b"a\x00b\x00"
  assert_eq(decode(encode(input)), input[:])
}
