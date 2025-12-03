import advent_of_code_2025
import gleam/bool
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Range {
  Range(start: Int, end: Int)
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use ranges <- result.try(parse_input(input))
  io.println("Part 1: " <> solve(ranges, part1))
  io.println("Part 2: " <> solve(ranges, part2))
  Ok(Nil)
}

fn solve(ranges: List(Range), solver: fn(Range) -> List(Int)) -> String {
  ranges
  |> list.flat_map(solver)
  |> int.sum()
  |> int.to_string()
}

fn part1(range: Range) -> List(Int) {
  list.range(range.start, range.end)
  |> list.filter(fn(n) {
    let assert Ok(n_log_10) = log_10(int.to_float(n))
    let digits =
      n_log_10
      |> float.ceiling()
      |> float.truncate()

    use <- bool.guard(digits % 2 == 1, return: False)
    let assert Ok(divisor) =
      int.power(10, int.to_float(digits / 2)) |> result.map(float.truncate)

    let left = n / divisor
    let right = n % divisor

    left == right
  })
}

fn part2(range: Range) -> List(Int) {
  list.range(range.start, range.end)
  |> list.filter(fn(n) {
    let assert Ok(n_log_10) = log_10(int.to_float(n))
    let digits = {
      n_log_10
      |> float.ceiling()
      |> float.truncate()
    }

    list.range(1, digits / 2)
    |> list.find(fn(pow) {
      use <- bool.guard(pow < 1, return: False)
      use <- bool.guard(digits % pow != 0, False)

      let assert Ok(divisor) =
        int.power(10, int.to_float(pow)) |> result.map(float.truncate)

      let parts = divide_to_parts(n, divisor)
      all_equal(parts)
    })
    |> result.is_ok()
  })
}

fn log_10(n: Float) -> Result(Float, Nil) {
  let assert Ok(log_10) = float.logarithm(10.0)
  n
  |> float.logarithm
  |> result.map(fn(log_e) { log_e /. log_10 })
}

fn divide_to_parts(n: Int, divisor: Int) -> List(Int) {
  use <- bool.guard(n == 0, return: [])
  // echo #(n, divisor, n % divisor)

  let m = n % divisor
  [m, ..divide_to_parts(n / divisor, divisor)]
}

fn all_equal(list: List(a)) -> Bool {
  case list {
    [] -> True
    [_head] -> True
    [first, second, ..rest] -> {
      first == second && all_equal([second, ..rest])
    }
  }
}

fn parse_input(input: String) -> Result(List(Range), String) {
  input
  |> string.trim_end()
  |> string.split(",")
  |> list.try_map(parse_range)
}

fn parse_range(input: String) -> Result(Range, String) {
  case string.split_once(input, "-") {
    Ok(#(raw_start, raw_end)) -> {
      use start <- result.try(parse_positive_int(raw_start))
      use end <- result.try(parse_positive_int(raw_end))

      Ok(Range(start:, end:))
    }
    Error(Nil) -> {
      Error("Malformed range '" <> input <> "'")
    }
  }
}

fn parse_positive_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed positive int '" <> input <> "'" })
  |> result.try(fn(n) {
    case n > 0 {
      True -> Ok(n)
      // Necessary for logarithms to take place
      False -> Error("Malformed positive int '" <> input <> "'")
    }
  })
}
