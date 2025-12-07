import advent_of_code_2025
import gleam/dict
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

type SimpleSimulationStep {
  SimpleSimulationStep(map: Map, splits: Int)
}

type QuantumSimulationOutcome {
  QuantumSimulationOutcome(num_timelines: Int, memo: dict.Dict(Position, Int))
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use parsed <- result.try(parse_input(input))

  io.println(
    "Part 1: "
    <> solve(parsed.map, parsed.starting_position, run_simple_simulation),
  )

  io.println(
    "Part 2: "
    <> solve(parsed.map, parsed.starting_position, run_quantum_simulation),
  )
  Ok(Nil)
}

fn solve(
  map: Map,
  starting_position: Position,
  simulation: fn(Map) -> Int,
) -> String {
  let first_beam = Position(..starting_position, row: starting_position.row + 1)
  let map = Map(..map, beams: set.insert(map.beams, first_beam))

  map
  |> simulation()
  |> int.to_string()
}

fn run_simple_simulation(map: Map) -> Int {
  do_run_simple_simulation(map, 0)
}

fn do_run_simple_simulation(map: Map, total_splits: Int) -> Int {
  let step = step_simple_simulation(map, total_splits)
  case step.map == map {
    True -> step.splits
    False -> do_run_simple_simulation(step.map, step.splits)
  }
}

fn step_simple_simulation(map: Map, total_splits: Int) -> SimpleSimulationStep {
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
  SimpleSimulationStep(map: Map(..map, beams:), splits:)
}

fn run_quantum_simulation(map: Map) -> Int {
  let outcome = do_run_quantum_simulation(map, 1, dict.new())

  outcome.num_timelines
}

fn do_run_quantum_simulation(
  map: Map,
  num_timelines: Int,
  memo: dict.Dict(Position, Int),
) -> QuantumSimulationOutcome {
  set.fold(
    map.beams,
    QuantumSimulationOutcome(num_timelines:, memo:),
    fn(acc, beam) {
      let QuantumSimulationOutcome(num_timelines:, memo:) = acc

      use <- from_memo(memo, beam, fn(extra) {
        QuantumSimulationOutcome(num_timelines: num_timelines + extra, memo:)
      })

      let position_candidate = Position(..beam, row: beam.row + 1)
      let is_splitter = set.contains(map.splitters, position_candidate)
      case is_splitter {
        True -> {
          let left_beam = Position(..beam, col: beam.col + 1)
          let right_beam = Position(..beam, col: beam.col - 1)
          let num_timelines = num_timelines + 1

          let QuantumSimulationOutcome(num_timelines:, memo:) =
            continue_quantum_simulation(map, left_beam, num_timelines, memo)
          continue_quantum_simulation(map, right_beam, num_timelines, memo)
        }
        False -> {
          continue_quantum_simulation(
            map,
            position_candidate,
            num_timelines,
            memo,
          )
        }
      }
    },
  )
}

fn from_memo(
  memo: dict.Dict(a, b),
  key: a,
  then: fn(b) -> c,
  otherwise: fn() -> c,
) -> c {
  case dict.get(memo, key) {
    Ok(value) -> then(value)
    Error(Nil) -> otherwise()
  }
}

fn continue_quantum_simulation(
  map: Map,
  beam: Position,
  num_timelines: Int,
  memo: dict.Dict(Position, Int),
) {
  let in_bounds =
    in_bounds(width: map.width, height: map.height, candidate: beam)

  case in_bounds {
    True -> {
      let map = Map(..map, beams: set.from_list([beam]))
      let outcome = do_run_quantum_simulation(map, num_timelines, memo)
      let memo =
        dict.insert(outcome.memo, beam, outcome.num_timelines - num_timelines)

      QuantumSimulationOutcome(..outcome, memo:)
    }
    False -> {
      QuantumSimulationOutcome(num_timelines:, memo:)
    }
  }
}

fn insert_if_in_bounds(
  positions: set.Set(Position),
  width width: Int,
  height height: Int,
  candidate candidate: Position,
) -> set.Set(Position) {
  case in_bounds(width:, height:, candidate:) {
    False -> positions
    True -> set.insert(positions, candidate)
  }
}

fn in_bounds(
  width width: Int,
  height height: Int,
  candidate candidate: Position,
) {
  candidate.row < height
  && candidate.row >= 0
  && candidate.col < width
  && candidate.col >= 0
}

// Helpful for debugging, but not used
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
