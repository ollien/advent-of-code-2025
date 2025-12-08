import advent_of_code_2025
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/set
import gleam/string

type Point {
  Point(x: Int, y: Int, z: Int)
}

const num_circuits = 1000

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use points <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(points))
  io.println("Part 2: " <> part2(points))

  Ok(Nil)
}

fn part1(points: List(Point)) -> String {
  points
  |> build_circuits()
  |> list.map(set.size)
  |> list.sort(int.compare)
  |> list.reverse()
  |> list.take(3)
  |> int.product()
  |> int.to_string()
}

fn part2(points: List(Point)) -> String {
  points
  |> build_until_big_circuit()
  |> option.map(fn(pair) {
    let #(point1, point2) = pair
    int.to_string(point1.x * point2.x)
  })
  |> option.unwrap(or: "No solution fund")
}

fn build_circuits(points: List(Point)) -> List(set.Set(Point)) {
  let visit_queue = make_visit_queue(points)

  do_build_circuits(visit_queue, num_circuits, dict.new())
}

fn do_build_circuits(
  visit_queue: List(#(Point, Point)),
  num_circuits: Int,
  adjacencies: dict.Dict(Point, set.Set(Point)),
) -> List(set.Set(Point)) {
  use <- bool.lazy_guard(num_circuits == 0, return: fn() {
    circuits_from_adjacencies(adjacencies)
  })

  use head, visit_queue <- try_pop(visit_queue, fn() {
    circuits_from_adjacencies(adjacencies)
  })

  let #(point1, point2) = head

  let point1_neighbors =
    adjacencies
    |> dict.get(point1)
    |> result.unwrap(or: set.new())

  let point2_neighbors =
    adjacencies
    |> dict.get(point2)
    |> result.unwrap(or: set.new())

  case
    set.contains(point1_neighbors, point2)
    || set.contains(point2_neighbors, point1)
  {
    True -> {
      do_build_circuits(visit_queue, num_circuits, adjacencies)
    }
    False -> {
      let point1_neighbors = set.insert(point1_neighbors, point2)
      let point2_neighbors = set.insert(point2_neighbors, point1)

      let adjacencies =
        adjacencies
        |> dict.insert(point1, point1_neighbors)
        |> dict.insert(point2, point2_neighbors)

      do_build_circuits(visit_queue, num_circuits - 1, adjacencies)
    }
  }
}

fn build_until_big_circuit(
  points: List(Point),
) -> option.Option(#(Point, Point)) {
  let visit_queue = make_visit_queue(points)

  do_build_until_big_circuit(set.from_list(points), visit_queue, dict.new())
}

fn do_build_until_big_circuit(
  points: set.Set(Point),
  visit_queue: List(#(Point, Point)),
  adjacencies: dict.Dict(Point, set.Set(Point)),
) -> option.Option(#(Point, Point)) {
  use head, visit_queue <- try_pop(visit_queue, fn() { option.None })

  let #(point1, point2) = head

  let point1_neighbors =
    adjacencies
    |> dict.get(point1)
    |> result.unwrap(or: set.new())

  let point2_neighbors =
    adjacencies
    |> dict.get(point2)
    |> result.unwrap(or: set.new())

  use <- bool.lazy_guard(
    set.contains(point1_neighbors, point2)
      || set.contains(point2_neighbors, point1),
    fn() { do_build_until_big_circuit(points, visit_queue, adjacencies) },
  )

  let point1_neighbors = set.insert(point1_neighbors, point2)
  let point2_neighbors = set.insert(point2_neighbors, point1)

  let adjacencies =
    adjacencies
    |> dict.insert(point1, point1_neighbors)
    |> dict.insert(point2, point2_neighbors)

  let circuit = walk_circuit(adjacencies, point1)
  case circuit == points {
    True -> option.Some(#(point1, point2))
    False -> do_build_until_big_circuit(points, visit_queue, adjacencies)
  }
}

fn circuits_from_adjacencies(
  adjacencies: dict.Dict(Point, set.Set(Point)),
) -> List(set.Set(Point)) {
  adjacencies
  |> dict.to_list()
  |> list.sort(fn(a, b) { int.compare(set.size(a.1), set.size(b.1)) })
  |> list.reverse()
  |> do_circuits_from_adjacencies(adjacencies, set.new())
}

fn do_circuits_from_adjacencies(
  adjacency_queue: List(#(Point, set.Set(Point))),
  adjacencies: dict.Dict(Point, set.Set(Point)),
  visited: set.Set(Point),
) -> List(set.Set(Point)) {
  use head, adjacency_queue <- try_pop(adjacency_queue, fn() { [] })
  use <- bool.lazy_guard(set.contains(visited, head.0), fn() {
    do_circuits_from_adjacencies(adjacency_queue, adjacencies, visited)
  })

  let visited = set.insert(visited, head.0)
  let circuit = walk_circuit(adjacencies, head.0)
  let visited = set.union(visited, circuit)

  [
    circuit,
    ..do_circuits_from_adjacencies(adjacency_queue, adjacencies, visited)
  ]
}

fn walk_circuit(
  adjacencies: dict.Dict(Point, set.Set(Point)),
  start: Point,
) -> set.Set(Point) {
  do_walk_circuit(adjacencies, [start], set.new())
}

fn do_walk_circuit(
  adjacencies: dict.Dict(Point, set.Set(Point)),
  to_visit: List(Point),
  visited: set.Set(Point),
) -> set.Set(Point) {
  use visiting, to_visit <- try_pop(to_visit, fn() { visited })

  let visited = set.insert(visited, visiting)

  let to_visit =
    adjacencies
    |> dict.get(visiting)
    |> result.unwrap(set.new())
    |> set.fold(to_visit, fn(to_visit, neighbor) {
      case set.contains(visited, neighbor) {
        True -> to_visit
        False -> [neighbor, ..to_visit]
      }
    })

  do_walk_circuit(adjacencies, to_visit, visited)
}

fn make_visit_queue(points: List(Point)) -> List(#(Point, Point)) {
  points
  |> list.fold(dict.new(), fn(acc, point1) {
    points
    |> list.filter(fn(point2) { point2 != point1 })
    |> list.map(fn(point2) {
      #(pair.new(point1, point2), distance(point1, point2))
    })
    |> dict.from_list()
    |> dict.combine(acc, fn(old, new) {
      case old == new {
        True -> new
        False -> panic as "distances cannot be different"
      }
    })
  })
  |> dict.to_list()
  |> list.sort(fn(a, b) { float.compare(a.1, b.1) })
  |> list.map(pair.first)
}

fn distance(a: Point, b: Point) -> Float {
  // All values must be positive, so this is guaranteed safe
  let assert Ok(distance) =
    int.square_root(square(a.x - b.x) + square(a.y - b.y) + square(a.z - b.z))

  distance
}

fn square(a: Int) -> Int {
  a * a
}

fn try_pop(list: List(a), or: fn() -> b, then: fn(a, List(a)) -> b) -> b {
  case list {
    [] -> {
      or()
    }

    [head, ..rest] -> {
      then(head, rest)
    }
  }
}

fn parse_input(input: String) -> Result(List(Point), String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_point)
}

fn parse_point(data: String) -> Result(Point, String) {
  data
  |> string.split(",")
  |> list.try_map(parse_int)
  |> result.try(fn(axes) {
    case axes {
      [x, y, z] -> Ok(Point(x:, y:, z:))
      _ -> Error("Point must have three components: '" <> data <> "'")
    }
  })
}

fn parse_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed int '" <> input <> "'" })
}
