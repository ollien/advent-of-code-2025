import advent_of_code_2025
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string

type Position {
  Position(row: Int, col: Int)
}

type Map {
  Map(
    height: Int,
    width: Int,
    splitters: set.Set(Position),
    beams: set.Set(Position),
  )
}

type Input {
  Input(map: Map, starting_position: Position)
}

type SimulationStep {
  SimulationStep(map: Map, splits: Int)
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use parsed <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(parsed.map, parsed.starting_position))
  Ok(Nil)
}

fn part1(map: Map, starting_position: Position) -> String {
  let first_beam = Position(..starting_position, row: starting_position.row + 1)
  let map = Map(..map, beams: set.insert(map.beams, first_beam))

  map
  |> run_simulation()
  |> int.to_string()
}

fn run_simulation(map: Map) -> Int {
  do_run_simulation(map, 0)
}

fn do_run_simulation(map: Map, total_splits: Int) -> Int {
  let step = step_simulation(map, total_splits)
  case step.map == map {
    True -> step.splits
    False -> do_run_simulation(step.map, step.splits)
  }
}

fn step_simulation(map: Map, total_splits: Int) -> SimulationStep {
  let res =
    set.fold(map.beams, #(set.new(), total_splits), fn(acc, beam) {
      let #(beams, splits) = acc

      let position_candidate = Position(..beam, row: beam.row + 1)
      let is_splitter = set.contains(map.splitters, position_candidate)
      case is_splitter {
        True -> {
          let beams =
            beams
            |> insert_if_in_bounds(
              width: map.width,
              height: map.height,
              candidate: Position(..position_candidate, col: beam.col - 1),
            )
            |> insert_if_in_bounds(
              width: map.width,
              height: map.height,
              candidate: Position(..position_candidate, col: beam.col + 1),
            )

          #(beams, splits + 1)
        }
        False -> {
          let beams =
            insert_if_in_bounds(
              beams,
              width: map.width,
              height: map.height,
              candidate: position_candidate,
            )

          #(beams, splits)
        }
      }
    })

  let #(beams, splits) = res
  SimulationStep(map: Map(..map, beams:), splits:)
}

fn insert_if_in_bounds(
  positions: set.Set(Position),
  width width: Int,
  height height: Int,
  candidate candidate: Position,
) -> set.Set(Position) {
  case
    candidate.row >= height
    || candidate.row < 0
    || candidate.col >= width
    || candidate.col < 0
  {
    True -> positions
    False -> set.insert(positions, candidate)
  }
}

fn debug_print_map(map: Map) -> Nil {
  list.each(list.range(0, map.height - 1), fn(row) {
    list.each(list.range(0, map.width - 1), fn(col) {
      let position = Position(row:, col:)
      let is_beam = set.contains(map.beams, position)
      let is_splitter = set.contains(map.splitters, position)

      case is_beam, is_splitter {
        True, _is_splitter -> io.print("|")
        False, True -> io.print("^")
        False, False -> io.print(".")
      }
    })

    io.println("")
  })
}

fn parse_input(input: String) -> Result(Input, String) {
  let empty_map =
    Map(height: 0, width: 0, splitters: set.new(), beams: set.new())

  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.index_map(fn(line, row) { #(line, row) })
  |> list.try_fold(#(empty_map, option.None), fn(acc, entry) {
    let #(line, row) = entry
    let #(current_map, starting_position) = acc
    parse_map_line(current_map, starting_position, row, line)
  })
  |> result.try(fn(res) {
    let #(map, starting_position) = res

    case starting_position {
      option.None -> Error("No starting position foun")
      option.Some(starting_position) -> Ok(Input(map:, starting_position:))
    }
  })
}

fn parse_map_line(
  current_map: Map,
  starting_position: option.Option(Position),
  row: Int,
  line: String,
) -> Result(#(Map, option.Option(Position)), String) {
  let current_map =
    Map(
      ..current_map,
      height: int.max(current_map.height, row + 1),
      width: int.max(current_map.width, string.length(line)),
    )

  line
  |> string.to_graphemes()
  |> list.index_map(fn(col, char) { #(col, char) })
  |> list.try_fold(#(current_map, starting_position), fn(acc, entry) {
    let #(char, col) = entry
    let #(current_map, starting_position) = acc

    case char {
      "." -> {
        Ok(acc)
      }
      "^" ->
        Ok(#(
          Map(
            ..current_map,
            splitters: set.insert(current_map.splitters, Position(row:, col:)),
          ),
          starting_position,
        ))
      "S" if starting_position == option.None -> {
        Ok(#(current_map, option.Some(Position(row:, col:))))
      }
      "S" -> {
        Error("Found more than one starting position")
      }
      other -> {
        Error("Invalid map char '" <> other <> "'")
      }
    }
  })
}
