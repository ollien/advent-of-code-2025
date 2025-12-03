import advent_of_code_2025
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Bank {
  Bank(batteries: List(Int))
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use banks <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(banks))
  io.println("Part 2: " <> part2(banks))
  Ok(Nil)
}

fn part1(banks: List(Bank)) -> String {
  banks
  |> list.map(fn(bank) {
    // battery bank must be at least two long and has digits (from parsing)
    let assert Ok(config) = best_battery_config(bank, 2)

    config
  })
  |> int.sum()
  |> int.to_string()
}

fn part2(banks: List(Bank)) -> String {
  banks
  |> list.map(fn(bank) {
    // battery bank must be at least two long and has digits (from parsing)
    let assert Ok(config) = best_battery_config(bank, 12)

    config
  })
  |> int.sum()
  |> int.to_string()
}

fn best_battery_config(bank: Bank, length: Int) -> Result(Int, String) {
  do_best_battery_config(bank.batteries, [], length)
}

fn do_best_battery_config(
  remaining_batteries: List(Int),
  maxes: List(Int),
  length_remaining: Int,
) -> Result(Int, String) {
  let num_maxes = list.length(maxes)
  case length_remaining {
    0 if num_maxes == 0 -> {
      Error("No batteries to configure")
    }

    0 -> {
      maxes
      |> list.reverse()
      |> concat_digits()
    }

    _n -> {
      remaining_batteries
      |> max_and_after(length_remaining - 1)
      |> result.try(fn(result) {
        let #(max, rest) = result
        do_best_battery_config(rest, [max, ..maxes], length_remaining - 1)
      })
    }
  }
}

fn concat_digits(digits: List(Int)) -> Result(Int, String) {
  list.try_fold(digits, 0, fn(acc, n) {
    case n > 9 || n < 0 {
      True -> Error(int.to_string(n) <> " is not a digit")
      False -> Ok(acc * 10 + n)
    }
  })
}

fn max_and_after(
  batteries: List(Int),
  min_to_maintain: Int,
) -> Result(#(Int, List(Int)), String) {
  case batteries {
    [] -> Error("No batteries to scan")
    [head, ..rest] -> Ok(do_max_and_after(rest, min_to_maintain, head, rest))
  }
}

fn do_max_and_after(
  batteries: List(Int),
  min_to_maintain: Int,
  best_head: Int,
  best_rest: List(Int),
) -> #(Int, List(Int)) {
  let num_batteries = list.length(batteries)

  case batteries {
    [] -> #(best_head, best_rest)
    [_head, ..] if num_batteries < min_to_maintain -> {
      #(best_head, best_rest)
    }
    [_head, ..] if num_batteries == min_to_maintain -> {
      #(best_head, best_rest)
    }
    [head, ..rest] if head <= best_head -> {
      do_max_and_after(rest, min_to_maintain, best_head, best_rest)
    }
    [head, ..rest] -> {
      do_max_and_after(rest, min_to_maintain, head, rest)
    }
  }
}

fn parse_input(input: String) -> Result(List(Bank), String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_line)
}

fn parse_line(line: String) -> Result(Bank, String) {
  line
  |> string.to_graphemes()
  |> list.try_map(parse_int)
  |> result.try(fn(numbers) {
    case numbers {
      [] -> Error("Bank of batteries cannot be empty")
      [_n] -> Error("Bank of batteries cannot be one long")
      _ -> Ok(numbers)
    }
  })
  |> result.map(Bank)
}

fn parse_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed int '" <> input <> "'" })
}
