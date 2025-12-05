import advent_of_code_2025
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/result
import gleam/string

type Range {
  Range(start: Int, end: Int)
}

type Ingredient {
  Ingredient(Int)
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use #(ranges, ingredients) <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(ranges, ingredients))
  io.println("Part 2: " <> part2(ranges))
  Ok(Nil)
}

fn part1(ranges: List(Range), ingredients: List(Ingredient)) -> String {
  ingredients
  |> list.count(fn(ingredient) {
    list.any(ranges, fn(range) { is_fresh(range, ingredient) })
  })
  |> int.to_string()
}

fn part2(ranges: List(Range)) -> String {
  ranges
  |> merge_ranges()
  |> list.map(fn(range) { range.end - range.start + 1 })
  |> int.sum()
  |> int.to_string()
}

fn is_fresh(range: Range, ingredient: Ingredient) {
  let Ingredient(value) = ingredient

  value >= range.start && value <= range.end
}

fn merge_ranges(ranges: List(Range)) -> List(Range) {
  let ranges =
    list.sort(ranges, fn(a, b) {
      order.break_tie(int.compare(a.start, b.start), int.compare(a.end, b.end))
    })

  case ranges {
    [] -> []
    [range] -> [range]
    [head, ..rest] -> {
      let #(ranges, last_range) =
        list.fold(rest, #([], head), fn(acc, range) {
          let #(ranges, last_range) = acc

          case range.start <= last_range.end + 1 {
            True -> {
              #(
                ranges,
                Range(
                  start: last_range.start,
                  // the new end must be strictly larger, we don't want to shorten the acc range
                  end: int.max(range.end, last_range.end),
                ),
              )
            }
            False -> {
              #([last_range, ..ranges], range)
            }
          }
        })

      [last_range, ..ranges]
    }
  }
}

fn parse_input(
  input: String,
) -> Result(#(List(Range), List(Ingredient)), String) {
  let sections_result =
    input
    |> string.trim()
    |> string.split_once("\n\n")

  case sections_result {
    Ok(#(range_section, ingredient_section)) -> {
      use ranges <- result.try(parse_ranges(range_section))
      use ingredients <- result.try(parse_ingredients(ingredient_section))

      Ok(#(ranges, ingredients))
    }
    Error(Nil) -> Error("Input does not have two sections")
  }
}

fn parse_ranges(range_section: String) -> Result(List(Range), String) {
  range_section
  |> string.split("\n")
  |> list.try_map(parse_range)
}

fn parse_ingredients(
  ingredient_section: String,
) -> Result(List(Ingredient), String) {
  ingredient_section
  |> string.split("\n")
  |> list.try_map(parse_ingredient)
}

fn parse_range(line: String) -> Result(Range, String) {
  case string.split_once(line, "-") {
    Ok(#(start, end)) -> {
      use start <- result.try(parse_int(start))
      use end <- result.try(parse_int(end))

      Ok(Range(start:, end:))
    }

    Error(Nil) -> {
      Error("Malformed range '" <> line <> "' - must contain dash")
    }
  }
}

fn parse_ingredient(line: String) -> Result(Ingredient, String) {
  use value <- result.try(parse_int(line))

  Ok(Ingredient(value))
}

fn parse_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed int '" <> input <> "'" })
}
