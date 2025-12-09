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

fn build_circuits(points: List(Point)) -> List(Int) {
  let visit_queue = make_visit_queue(points)

  do_build_circuits(visit_queue, num_circuits, new_unionfind())
}

fn do_build_circuits(
  visit_queue: List(#(Point, Point)),
  num_circuits: Int,
  union_find: UnionFind(Point),
) -> List(Int) {
  use <- bool.lazy_guard(num_circuits == 0, fn() { set_sizes(union_find) })
  use head, visit_queue <- try_pop(visit_queue, fn() { set_sizes(union_find) })

  let #(point1, point2) = head

  let union_find =
    union_find
    |> insert_new(point1)
    |> insert_new(point2)
    |> union(point1, point2)

  do_build_circuits(visit_queue, num_circuits - 1, union_find)
}

fn build_until_big_circuit(
  points: List(Point),
) -> option.Option(#(Point, Point)) {
  let visit_queue = make_visit_queue(points)

  do_build_until_big_circuit(list.length(points), visit_queue, new_unionfind())
}

fn do_build_until_big_circuit(
  num_points: Int,
  visit_queue: List(#(Point, Point)),
  union_find: UnionFind(Point),
) -> option.Option(#(Point, Point)) {
  use head, visit_queue <- try_pop(visit_queue, fn() { option.None })

  let #(point1, point2) = head

  let union_find =
    union_find
    |> insert_new(point1)
    |> insert_new(point2)
    |> union(point1, point2)

  case num_sets(union_find) == 1 && set_sizes(union_find) == [num_points] {
    True -> option.Some(#(point1, point2))
    False -> do_build_until_big_circuit(num_points, visit_queue, union_find)
  }
}

fn make_visit_queue(points: List(Point)) -> List(#(Point, Point)) {
  points
  |> list.combination_pairs()
  |> list.filter(fn(points) { pair.first(points) != pair.second(points) })
  |> list.map(fn(points) {
    #(points, distance(pair.first(points), pair.second(points)))
  })
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

type UnionFind(a) {
  UnionFind(map: dict.Dict(a, a))
}

fn new_unionfind() -> UnionFind(a) {
  UnionFind(map: dict.new())
}

fn num_sets(union_find: UnionFind(a)) -> Int {
  union_find.map
  |> dict.to_list()
  |> list.count(fn(entry) { pair.first(entry) == pair.second(entry) })
}

fn set_sizes(union_find: UnionFind(a)) -> List(Int) {
  union_find.map
  |> dict.keys()
  |> list.fold(dict.new(), fn(counts, key) {
    let set = find(union_find, key)

    let count = counts |> dict.get(set) |> result.unwrap(or: 0)
    dict.insert(counts, set, count + 1)
  })
  |> dict.values()
}

fn insert_new(union_find: UnionFind(a), value: a) -> UnionFind(a) {
  case dict.has_key(union_find.map, value) {
    True -> union_find
    False -> UnionFind(map: dict.insert(union_find.map, value, value))
  }
}

fn union(union_find: UnionFind(a), value1: a, value2: a) -> UnionFind(a) {
  let set1 = find(union_find, value1)
  let set2 = find(union_find, value2)

  case set1, set2 {
    option.None, _set2 -> union_find
    _set1, option.None -> union_find
    option.Some(set1), option.Some(set2) -> {
      UnionFind(map: dict.insert(union_find.map, set1, set2))
    }
  }
}

fn find(union_find: UnionFind(a), value: a) -> option.Option(a) {
  case dict.get(union_find.map, value) {
    Error(Nil) -> option.None
    Ok(parent) if parent == value -> option.Some(parent)
    Ok(parent) -> find(union_find, parent)
  }
}
