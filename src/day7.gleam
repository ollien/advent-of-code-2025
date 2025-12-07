import advent_of_code_2025
import gleam/bool
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
  Map(height: Int, width: Int, splitters: set.Set(Position))
}

type Input {
  Input(map: Map, starting_position: Position)
}

type Solutions {
  Solutions(part1: Int, part2: Int)
}

type SolveState {
  SolveState(
    num_timelines: Int,
    splitters_hit: set.Set(Position),
    memo: dict.Dict(Position, Int),
  )
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use parsed <- result.try(parse_input(input))
  let solutions = solve(parsed.map, parsed.starting_position)

  io.println("Part 1: " <> int.to_string(solutions.part1))
  io.println("Part 2: " <> int.to_string(solutions.part2))

  Ok(Nil)
}

fn solve(map: Map, active_beam: Position) -> Solutions {
  let outcome =
    do_solve(
      SolveState(num_timelines: 1, splitters_hit: set.new(), memo: dict.new()),
      map,
      active_beam,
    )

  Solutions(
    part1: set.size(outcome.splitters_hit),
    part2: outcome.num_timelines,
  )
}

fn do_solve(
  solve_state: SolveState,
  map: Map,
  active_beam: Position,
) -> SolveState {
  use <- from_memo(solve_state.memo, active_beam, fn(extra) {
    SolveState(..solve_state, num_timelines: solve_state.num_timelines + extra)
  })

  let position_candidate = Position(..active_beam, row: active_beam.row + 1)
  let is_splitter = set.contains(map.splitters, position_candidate)
  case is_splitter {
    True -> {
      let left_beam = Position(..active_beam, col: active_beam.col + 1)
      let right_beam = Position(..active_beam, col: active_beam.col - 1)

      SolveState(
        ..solve_state,
        num_timelines: solve_state.num_timelines + 1,
        splitters_hit: set.insert(solve_state.splitters_hit, position_candidate),
      )
      |> continue_with_beam(map, left_beam)
      |> continue_with_beam(map, right_beam)
    }
    False -> {
      continue_with_beam(solve_state, map, position_candidate)
    }
  }
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

fn continue_with_beam(solve_state: SolveState, map: Map, beam: Position) {
  let in_bounds =
    in_bounds(width: map.width, height: map.height, candidate: beam)

  use <- bool.guard(!in_bounds, return: solve_state)

  let outcome = do_solve(solve_state, map, beam)

  let memo =
    dict.insert(
      outcome.memo,
      beam,
      outcome.num_timelines - solve_state.num_timelines,
    )

  SolveState(..outcome, memo:)
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

fn parse_input(input: String) -> Result(Input, String) {
  let empty_map = Map(height: 0, width: 0, splitters: set.new())

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
