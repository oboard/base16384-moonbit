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
  input : Array[Byte],
  output_length : Int,
  s_width : Int,
  t_width : Int,
  s_offset : Int,
  t_offset : Int,
) -> Array[UInt16] {
  let mask = (1 << t_width) - 1
  let output = Array::make(output_length, (0).to_uint16())
  fn process_input(i : Int, offset : Int, rest : Int, j : Int) -> Unit {
    if i >= input.length() {
      if offset > 0 && j < output_length {
        output[j] = rest.to_uint16() + t_offset.to_uint16()
      }
      return
    }
    let char = input[i].to_int() - s_offset
    let new_offset = offset + s_width
    fn extract_bits(
      curr_offset : Int,
      curr_rest : Int,
      curr_j : Int,
    ) -> (Int, Int, Int) {
      if curr_offset < t_width {
        (curr_offset, curr_rest, curr_j)
      } else {
        let bit_offset = curr_offset - t_width
        let output_val = curr_rest.to_uint16() +
          @cmp.maximum(
            @cmp.minimum(
              (char.to_uint16() >> bit_offset) + t_offset.to_uint16(),
              0xFFFF,
            ),
            0,
          )
        if curr_j >= output_length {
          (bit_offset, 0, curr_j)
        } else {
          output[curr_j] = output_val
          extract_bits(bit_offset, 0, curr_j + 1)
        }
      }
    }

    let (final_offset, final_rest, new_j) = extract_bits(new_offset, rest, j)
    let updated_rest = final_rest + ((char << (t_width - final_offset)) & mask)
    process_input(i + 1, final_offset, updated_rest, new_j)
  }

  process_input(0, 0, 0, 0)
  output
}

///|
fn align_uint16(
  input : Array[UInt16],
  output_length : Int,
  s_width : Int,
  t_width : Int,
  s_offset : Int,
  t_offset : Int,
) -> Array[UInt16] {
  let mask = (1 << t_width) - 1
  let output = Array::make(output_length, (0).to_uint16())
  fn process_input(i : Int, offset : Int, rest : Int, j : Int) -> Unit {
    if i >= input.length() {
      if offset > 0 && j < output_length {
        output[j] = rest.to_uint16() + t_offset.to_uint16()
      }
      return
    }
    let char = input[i].to_int() - s_offset
    let new_offset = offset + s_width
    fn extract_bits(
      curr_offset : Int,
      curr_rest : Int,
      curr_j : Int,
    ) -> (Int, Int, Int) {
      if curr_offset < t_width {
        (curr_offset, curr_rest, curr_j)
      } else {
        let bit_offset = curr_offset - t_width
        let output_val = curr_rest.to_uint16() +
          @cmp.maximum(
            @cmp.minimum(
              (char.to_uint16() >> bit_offset) + t_offset.to_uint16(),
              0xFFFF,
            ),
            0,
          )
        if curr_j >= output_length {
          (bit_offset, 0, curr_j)
        } else {
          output[curr_j] = output_val
          extract_bits(bit_offset, 0, curr_j + 1)
        }
      }
    }

    let (final_offset, final_rest, new_j) = extract_bits(new_offset, rest, j)
    let updated_rest = final_rest + ((char << (t_width - final_offset)) & mask)
    process_input(i + 1, final_offset, updated_rest, new_j)
  }

  process_input(0, 0, 0, 0)
  output
}

///|
pub fn encode(input : Array[Byte]) -> Array[UInt16] {
  let outputLength = @math.ceil(input.length().to_double() * 4 / 7).to_int() + 1
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
pub fn decode(input : Array[UInt16]) -> ArrayView[Byte] {
  if input.is_empty() || input.length() == 1 {
    return []
  }
  let length = input.length() - 1
  let residue = input[length] - 0x3d00
  let valid_residue = if residue > 0 && residue <= 7 { residue } else { 7 }
  let outLen = (length.to_double() / 4).floor().to_int() * 7 +
    (if length % 4 > 0 { valid_residue.to_int() } else { 0 })
  let output = align_uint16(input, outLen, 14, 8, 0x4e00, 0)
  fn find_last_non_zero(idx : Int) -> Int {
    if idx < 0 {
      -1
    } else if output[idx] == 0 {
      find_last_non_zero(idx - 1)
    } else {
      idx
    }
  }

  let lastNonZero = find_last_non_zero(outLen - 1)
  return if lastNonZero < 0 {
    []
  } else {
    output[0:lastNonZero + 1].map(i => i.to_byte())
  }
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
  let encoded = encode(@encoding.encode(UTF8, input).to_array())
  let encoded_buf = @buffer.new()
  encoded.each(value => {
    encoded_buf.write_byte(value.to_byte())
    encoded_buf.write_byte((value >> 8).to_byte())
  })
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
  if input.is_empty() {
    return ""
  }
  let bytes = input.to_bytes().to_array()
  let len = bytes.length()
  let array = Array::make(len / 2, (0).to_uint16())
  let mut i = 0
  while i < len - 1 {
    array[i / 2] = bytes[i].to_uint16() + (bytes[i + 1].to_uint16() << 8)
    i = i + 2
  }
  if i < len {
    array[i / 2] = bytes[i].to_uint16()
  }
  @encoding.decoder(UTF8).decode(decode(array).to_array() |> @bytes.from_array)
}

///|
test {
  let input = "hello world"
  let encoded = encode_str(input)
  let decoded = decode_str(encoded)
  inspect(encoded, content="栙擆羼湷槜瓆帀㴄")
  inspect(decoded, content="hello world")
}
