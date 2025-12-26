import advent_of_code_2025
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Position {
  Position(row: Int, col: Int)
}

type PieceComponent {
  Filled
  NotFilled
}

type Piece {
  Piece(dict.Dict(Position, PieceComponent))
}

type Instruction {
  Instruction(width: Int, height: Int, counts: List(Int))
}

type Input {
  Input(pieces: List(Piece), instructions: List(Instruction))
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(raw_input: String) -> Result(Nil, String) {
  use input <- result.try(parse_input(raw_input))
  io.println("Part 1: " <> part1(input))
  io.println("Part 2: Merry Christmas!")

  Ok(Nil)
}

fn part1(input: Input) -> String {
  // The actual puzzle isn't real - the input can be solved by simply checking
  // if the pieces fit in the area
  let filled_counts =
    list.map(input.pieces, fn(piece) {
      let Piece(mapping) = piece

      mapping
      |> dict.values()
      |> list.count(fn(component) { component == Filled })
    })

  input.instructions
  |> list.count(fn(instruction) {
    let usable_area = instruction.width * instruction.height
    let min_area =
      instruction.counts
      |> list.zip(filled_counts)
      |> list.map(fn(entry) {
        let #(count, area) = entry

        count * area
      })
      |> int.sum()

    min_area <= usable_area
  })
  |> int.to_string()
}

fn parse_input(raw_input: String) -> Result(Input, String) {
  let input_components =
    raw_input
    |> string.trim_end()
    |> string.split("\n\n")

  let num_components = list.length(input_components)
  use <- bool.guard(
    num_components < 2,
    Error("Input does not have enough components"),
  )

  let assert #(raw_pieces, [raw_instructions]) =
    list.split(input_components, num_components - 1)

  use pieces <- result.try(parse_pieces(raw_pieces))
  use instructions <- result.try(parse_instructions(raw_instructions))

  Ok(Input(pieces:, instructions:))
}

fn parse_pieces(pieces: List(String)) -> Result(List(Piece), String) {
  list.try_map(pieces, parse_piece)
}

fn parse_piece(raw_piece: String) -> Result(Piece, String) {
  let lines =
    raw_piece
    |> string.split("\n")
    // drop the index, we don't need it
    |> list.drop(1)

  lines
  |> list.index_map(fn(line, row) { #(row, line) })
  |> list.try_fold(dict.new(), fn(piece, entry) {
    let #(row, line) = entry

    line
    |> string.to_graphemes()
    |> list.index_map(fn(line, col) { #(col, line) })
    |> list.try_fold(piece, fn(piece, entry) {
      let #(col, char) = entry
      case char {
        "#" -> Ok(dict.insert(piece, Position(row:, col:), Filled))
        "." -> Ok(dict.insert(piece, Position(row:, col:), NotFilled))
        _ -> Error("Invalid char '" <> char <> "'")
      }
    })
  })
  |> result.map(Piece)
}

fn parse_instructions(instructions: String) -> Result(List(Instruction), String) {
  instructions
  |> string.split("\n")
  |> list.try_map(parse_instruction)
}

fn parse_instruction(instruction: String) -> Result(Instruction, String) {
  let split_res =
    instruction
    |> string.split_once(": ")
    |> result.map_error(fn(_: Nil) {
      "Malformed instruction line '" <> instruction <> "'"
    })

  use #(front_half, back_half) <- result.try(split_res)
  use #(width, height) <- result.try(parse_dimensions(front_half))
  use counts <- result.try(parse_counts(back_half))

  Ok(Instruction(width:, height:, counts:))
}

fn parse_dimensions(dims: String) -> Result(#(Int, Int), String) {
  case string.split_once(dims, "x") {
    Ok(#(raw_width, raw_height)) -> {
      use width <- result.try(parse_int(raw_width))
      use height <- result.try(parse_int(raw_height))

      Ok(#(width, height))
    }

    Error(Nil) -> {
      Error("Malformed dimensions '" <> dims <> "'")
    }
  }
}

fn parse_counts(counts: String) -> Result(List(Int), String) {
  counts
  |> string.split(" ")
  |> list.try_map(parse_int)
}

fn parse_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed int '" <> input <> "'" })
}
