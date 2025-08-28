///|
pub fn align(
  input : ArrayView[Int],
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
    let char = input[i] - s_offset
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
pub fn encode(input : ArrayView[Byte]) -> Array[UInt16] {
  let outputLength = @math.ceil(input.length().to_double() * 4 / 7).to_int() + 1
  let output = align(input.map(i => i.to_int()), outputLength, 8, 14, 0, 0x4e00)
  output[outputLength - 1] = input.length().to_uint16() % 7 + 0x3d00
  output
}

///|
pub fn decode(input : Array[UInt16]) -> ArrayView[Byte] {
  if input.is_empty() || input.length() == 1 {
    return []
  }
  let length = input.length() - 1
  let residue = input[length] - 0x3d00
  let valid_residue = if residue > 0 && residue <= 7 { residue } else { 7 }
  let outLen = @math.floor(length.to_double() / 4).to_int() * 7 +
    (if length % 4 > 0 { valid_residue.to_int() } else { 0 })
  let output = align(
    input[0:length].map(i => i.to_int()),
    outLen,
    14,
    8,
    0x4e00,
    0,
  )
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
test {
  let input = b"hello world"
  let encoded = encode(input.to_array())
  let encoded_buf = @buffer.new()
  encoded.each(value => {
    encoded_buf.write_byte(value.to_byte())
    encoded_buf.write_byte((value >> 8).to_byte())
  })
  let decoded = decode(encoded).to_array() |> Bytes::from_array
  inspect(encoded_buf.to_string(), content="栙擆羼湷槜瓆帀㴄")
  inspect(@encoding.decoder(UTF8).decode(decoded), content="hello world")
}
