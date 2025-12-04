import advent_of_code_2025
import gleam/int
import gleam/list
import gleam/string

import gleam/io
import gleam/result
import gleam/set

type Position {
  Position(row: Int, col: Int)
}

type Map {
  Map(empty: set.Set(Position), paper: set.Set(Position))
}

type MapTile {
  Empty
  Paper
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use map <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(map))
  io.println("Part 2: " <> part2(map))

  Ok(Nil)
}

fn part1(map: Map) -> String {
  map
  |> removable_paper()
  |> set.size()
  |> int.to_string()
}

fn part2(map: Map) -> String {
  map
  |> do_part2(set.new())
  |> int.to_string()
}

fn do_part2(map: Map, removed_rolls: set.Set(Position)) -> Int {
  let removable = removable_paper(map)
  case set.is_empty(removable) {
    True -> set.size(removed_rolls)
    False -> {
      removable
      |> set.fold(from: map, with: fn(map, acc) { remove_paper(map, acc) })
      |> do_part2(set.union(removed_rolls, removable))
    }
  }
}

fn removable_paper(map: Map) -> set.Set(Position) {
  set.filter(map.paper, fn(position) {
    let num_neighbors =
      position
      |> adjacent_positions()
      |> list.count(fn(candidate_position) {
        set.contains(map.paper, candidate_position)
      })

    num_neighbors < 4
  })
}

fn adjacent_positions(position: Position) -> List(Position) {
  list.range(from: -1, to: 1)
  |> list.flat_map(fn(d_row) {
    list.range(from: -1, to: 1)
    |> list.map(fn(d_col) { #(d_row, d_col) })
  })
  |> list.filter(fn(deltas) {
    let #(d_row, d_col) = deltas
    !{ d_row == 0 && d_col == 0 }
  })
  |> list.map(fn(deltas) {
    let #(d_row, d_col) = deltas
    Position(row: position.row + d_row, col: position.col + d_col)
  })
}

fn remove_paper(map: Map, position: Position) -> Map {
  Map(
    empty: set.insert(map.empty, position),
    paper: set.delete(map.paper, position),
  )
}

fn parse_input(input: String) -> Result(Map, String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_line_tiles)
  |> result.try(fn(input_tiles) {
    let map =
      list.index_fold(
        over: input_tiles,
        from: Map(empty: set.new(), paper: set.new()),
        with: build_map_line,
      )

    Ok(map)
  })
}

fn parse_line_tiles(line: String) -> Result(List(MapTile), String) {
  line
  |> string.to_graphemes()
  |> list.try_map(fn(char) {
    case char {
      "." -> Ok(Empty)
      "@" -> Ok(Paper)
      char -> Error("Invalid map character '" <> char <> "'")
    }
  })
}

fn build_map_line(map: Map, line_tiles: List(MapTile), row: Int) {
  list.index_fold(
    over: line_tiles,
    from: map,
    with: fn(map: Map, tile: MapTile, col: Int) {
      case tile {
        Paper -> Map(..map, paper: set.insert(map.paper, Position(row:, col:)))
        Empty -> Map(..map, empty: set.insert(map.empty, Position(row:, col:)))
      }
    },
  )
}
// fn parse_line(line: String, row: Int) -> Result(Map[])
