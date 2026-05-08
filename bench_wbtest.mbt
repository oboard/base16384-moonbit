///|
let bench_payload_1k : Bytes = Bytes::makei(1024, i => {
  ((i * 31 + 17) & 0xff).to_byte()
})

///|
let bench_payload_64k : Bytes = Bytes::makei(64 * 1024, i => {
  ((i * 31 + 17) & 0xff).to_byte()
})

///|
let bench_encoded_1k : Array[UInt16] = encode(bench_payload_1k)

///|
let bench_encoded_64k : Array[UInt16] = encode(bench_payload_64k)

///|
let bench_text : String = "MoonBit base16384 benchmark payload: 0123456789 abcdefghijklmnopqrstuvwxyz ".repeat(
  256,
)

///|
let bench_encoded_text : String = encode_str(bench_text)

///|
test (b : @bench.T) {
  b.bench(name="encode_1k", fn() { b.keep(encode(bench_payload_1k)) })
  b.bench(name="decode_1k", fn() { b.keep(decode(bench_encoded_1k)) })
  b.bench(name="encode_64k", fn() { b.keep(encode(bench_payload_64k)) })
  b.bench(name="decode_64k", fn() { b.keep(decode(bench_encoded_64k)) })
  b.bench(name="encode_str", fn() { b.keep(encode_str(bench_text)) })
  b.bench(name="decode_str", fn() {
    b.keep(try! decode_str(bench_encoded_text))
  })
}
