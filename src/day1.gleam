import advent_of_code_2025
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Rotation {
  Rotation(direction: Direction, magnitude: Int)
}

type Direction {
  Left
  Right
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(file: String) -> Result(Nil, String) {
  use parsed_input <- result.try(parse_input(file))
  io.println("Part 1: " <> part1(parsed_input))
  io.println("Part 2: " <> part2(parsed_input))

  Ok(Nil)
}

fn part1(input: List(Rotation)) -> String {
  let #(_final_dial, num_zeroes) =
    input
    |> list.map(rotation_as_int)
    |> list.fold(#(50, 0), fn(acc, n) {
      let #(dial, num_zeroes) = acc
      // We know the base is not zero so this must succeed
      let assert Ok(dial) = int.modulo(dial + n, 100)

      case dial {
        0 -> #(dial, num_zeroes + 1)
        _ -> #(dial, num_zeroes)
      }
    })

  int.to_string(num_zeroes)
}

fn part2(input: List(Rotation)) -> String {
  let #(_final_dial, num_zeroes) =
    input
    |> list.map(rotation_as_int)
    |> list.fold(#(50, 0), fn(acc, n) {
      let #(dial, num_zeroes) = acc
      // We know the base is not zero so this must succeed
      let assert Ok(new_dial) = int.modulo(dial + n, 100)

      let full_revs = int.absolute_value(n) / 100
      // Three cases here
      // 1. We landed on 0, which means we clicked it
      // 2. Turning to the right by the tens part (i.e. part of a rotation) makes us click past zero.
      // 3. Turning to left right by the tens part (i.e. part of a rotation) makes us click past zero.
      //    (We must exclude the case where the dial started at zero because then any negative value would make us look like we clicked past)
      let need_another =
        new_dial == 0
        || { n > 0 && dial + { n % 100 } >= 100 }
        || { dial != 0 && n < 0 && dial - { int.absolute_value(n) % 100 } <= 0 }
      let increment = case need_another {
        True -> full_revs + 1
        False -> full_revs
      }

      #(new_dial, num_zeroes + increment)
    })

  int.to_string(num_zeroes)
}

fn rotation_as_int(rotation: Rotation) -> Int {
  case rotation.direction {
    Left -> -rotation.magnitude
    Right -> rotation.magnitude
  }
}

fn parse_input(file: String) -> Result(List(Rotation), String) {
  file
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_line)
}

fn parse_line(line: String) -> Result(Rotation, String) {
  use #(raw_direction, rest) <- result.try(split_rotation_string(line))
  use direction <- result.try(parse_direction(raw_direction))
  use magnitude <- result.try(parse_int(rest))

  Ok(Rotation(direction:, magnitude:))
}

fn split_rotation_string(line: String) -> Result(#(String, String), String) {
  line
  |> string.pop_grapheme()
  |> result.map_error(fn(_nil: Nil) { "Cannot split an empty line" })
}

fn parse_direction(char: String) -> Result(Direction, String) {
  case char {
    "L" -> Ok(Left)
    "R" -> Ok(Right)
    _else -> Error("\"" <> char <> "\" is not a valid direction")
  }
}

fn parse_int(number: String) -> Result(Int, String) {
  number
  |> int.parse()
  |> result.map_error(fn(_nil: Nil) {
    "\"" <> number <> "\" is not a valid integer"
  })
}
