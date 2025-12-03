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
  Ok(Nil)
}

fn part1(banks: List(Bank)) -> String {
  banks
  |> list.map(best_battery_config)
  |> int.sum()
  |> int.to_string()
}

fn best_battery_config(bank: Bank) -> Int {
  // We've guaranteed bank batteries will have at least two elements so both these asserts are ok
  let assert Ok(#(max, rest)) = max_and_after(bank.batteries)
  let assert Ok(rest_max) = list.max(rest, int.compare)
  max * 10 + rest_max
}

fn max_and_after(batteries: List(Int)) -> Result(#(Int, List(Int)), Nil) {
  case batteries {
    [] -> Error(Nil)
    [_n] -> Error(Nil)
    [head, ..rest] -> do_max_and_after(rest, head, rest)
  }
}

fn do_max_and_after(
  batteries: List(Int),
  best_head: Int,
  best_rest: List(Int),
) -> Result(#(Int, List(Int)), Nil) {
  case batteries {
    [] -> Error(Nil)
    [_n] -> Ok(#(best_head, best_rest))
    [head, ..rest] if head <= best_head -> {
      do_max_and_after(rest, best_head, best_rest)
    }
    [head, ..rest] -> {
      do_max_and_after(rest, head, rest)
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
