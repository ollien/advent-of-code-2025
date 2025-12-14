import advent_of_code_2025
import gleam/bool
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/pair
import gleam/result
import gleam/string

type Position {
  Position(x: Int, y: Int)
}

type QuadRectangle {
  // Representing rectangle corners like this, might be mirrored
  //
  // A######B
  // #      #
  // C######D
  QuadRectangle(a: Position, b: Position, c: Position, d: Position)
}

type Map {
  Map(
    segments: List(LineSegment),
    expanded_by_x: dict.Dict(Int, List(Position)),
    expanded_by_y: dict.Dict(Int, List(Position)),
    min_x: Int,
    min_y: Int,
  )
}

type LineSegment {
  LineSegment(a: Position, b: Position)
}

type WorkerMessage(a, b) {
  Demand(process.Subject(a))
  Result(b, Bool)
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use positions <- result.try(parse_input(input))

  io.println("Part 1: " <> part1(positions))
  io.println("Part 2: " <> part2(positions))

  Ok(Nil)
}

fn part1(positions: List(Position)) -> String {
  positions
  |> list.combination_pairs()
  |> list.map(fn(pair) {
    let #(pos1, pos2) = pair
    area(pos1, pos2)
  })
  |> list.max(int.compare)
  |> result.map(int.to_string)
  |> result.unwrap(or: "No solution")
}

fn part2(positions: List(Position)) -> String {
  let assert Ok(map) = build_map(positions)

  positions
  |> list.combination_pairs()
  |> list.filter(fn(pair) { pair.0 != pair.1 })
  |> list.map(fn(pair) {
    let #(pos1, pos2) = pair
    let #(corner_a, corner_d) = sort_points(pos1, pos2)
    let corner_c = Position(x: corner_a.x, y: corner_d.y)
    let corner_b = Position(x: corner_d.x, y: corner_a.y)

    QuadRectangle(a: corner_a, b: corner_b, c: corner_c, d: corner_d)
  })
  |> run_many_async(
    fn(rectangle, map) { #(rectangle, is_rectangle_eligible(map, rectangle)) },
    map,
  )
  |> list.max(fn(rectangle1, rectangle2) {
    int.compare(
      area(rectangle1.a, rectangle1.d),
      area(rectangle2.a, rectangle2.d),
    )
  })
  |> result.map(fn(rectangle) { int.to_string(area(rectangle.a, rectangle.d)) })
  |> result.unwrap(or: "No solution found")
}

fn run_many_async(
  task_args: List(a),
  task_fn: fn(a, c) -> #(b, Bool),
  task_data: c,
) -> List(b) {
  let result_subject = process.new_subject()
  let demand_subject = process.new_subject()

  let num_tasks = int.min(num_schedulers(), list.length(task_args))
  list.each(list.range(1, num_tasks), fn(_n) {
    process.spawn(fn() {
      let work_subject = process.new_subject()
      worker(work_subject, demand_subject, result_subject, task_fn, task_data)
    })
  })

  divide_work(task_args, demand_subject, result_subject, 0, [])
}

fn worker(
  work_subject: process.Subject(a),
  demand_subject: process.Subject(process.Subject(a)),
  result_subject: process.Subject(b),
  task_fn: fn(a, c) -> b,
  task_data: c,
) -> Nil {
  process.send(demand_subject, work_subject)
  let work_selector = process.select(process.new_selector(), work_subject)
  let task_arg = process.selector_receive_forever(work_selector)

  let result = task_fn(task_arg, task_data)
  process.send(result_subject, result)

  worker(work_subject, demand_subject, result_subject, task_fn, task_data)
}

fn divide_work(
  work: List(a),
  demand_subject: process.Subject(process.Subject(a)),
  result_subject: process.Subject(#(b, Bool)),
  outstanding_tasks: Int,
  results: List(b),
) -> List(b) {
  let selector =
    process.new_selector()
    |> process.select_map(demand_subject, Demand)
    |> process.select_map(result_subject, fn(entry: #(b, Bool)) {
      Result(entry.0, entry.1)
    })

  let msg = process.selector_receive_forever(selector)
  case work, msg {
    [], Demand(_subject) -> {
      divide_work(
        work,
        demand_subject,
        result_subject,
        outstanding_tasks,
        results,
      )
    }

    [next_work, ..rest_work], Demand(subject) -> {
      process.send(subject, next_work)
      divide_work(
        rest_work,
        demand_subject,
        result_subject,
        outstanding_tasks + 1,
        results,
      )
    }

    [], Result(_answer, False) if outstanding_tasks <= 1 -> {
      results
    }

    [], Result(answer, True) if outstanding_tasks <= 1 -> {
      [answer, ..results]
    }

    _work, Result(_answer, False) -> {
      divide_work(
        work,
        demand_subject,
        result_subject,
        outstanding_tasks - 1,
        results,
      )
    }

    _work, Result(answer, True) -> {
      let results = [answer, ..results]
      divide_work(
        work,
        demand_subject,
        result_subject,
        outstanding_tasks - 1,
        results,
      )
    }
  }
}

fn build_map(positions: List(Position)) -> Result(Map, String) {
  let segments = line_segments(positions)
  let expanded_segments = expand_segments(segments)
  let expanded_by_x =
    group_points(expanded_segments, fn(position) { position.x }, fn(position) {
      position.y
    })
  let expanded_by_y =
    group_points(expanded_segments, fn(position) { position.y }, fn(position) {
      position.x
    })

  use min_x <- result.try(
    expanded_segments
    |> dict.keys()
    |> list.map(fn(position) { position.x })
    |> list_min(int.compare)
    |> result.map_error(fn(_: Nil) { "No line segments" }),
  )

  use min_y <- result.try(
    expanded_segments
    |> dict.keys()
    |> list.map(fn(position) { position.y })
    |> list_min(int.compare)
    |> result.map_error(fn(_: Nil) { "No line segments" }),
  )

  Ok(Map(segments:, expanded_by_y:, expanded_by_x:, min_x:, min_y:))
}

fn expand_segments(
  segments: List(LineSegment),
) -> dict.Dict(Position, LineSegment) {
  list.fold(segments, dict.new(), fn(acc, segment) {
    case segment.a.x == segment.b.x {
      True -> {
        list.range(segment.a.y, segment.b.y)
        |> list.map(fn(y) { Position(x: segment.a.x, y: y) })
        |> list.fold(acc, fn(acc, point) { dict.insert(acc, point, segment) })
      }
      False -> {
        list.range(segment.a.x, segment.b.x)
        |> list.map(fn(x) { Position(x: x, y: segment.a.y) })
        |> list.fold(acc, fn(acc, point) { dict.insert(acc, point, segment) })
      }
    }
  })
}

fn group_points(
  segments: dict.Dict(Position, LineSegment),
  component: fn(Position) -> Int,
  other_component: fn(Position) -> Int,
) -> dict.Dict(Int, List(Position)) {
  segments
  |> dict.to_list()
  |> list.group(fn(entry) {
    let #(key, _value) = entry

    component(key)
  })
  |> dict.map_values(fn(_key, value) {
    value
    |> list.map(pair.first)
    |> list.sort(fn(a, b) {
      int.compare(other_component(a), other_component(b))
    })
  })
}

fn list_min(list: List(a), compare: fn(a, a) -> order.Order) -> Result(a, Nil) {
  case list {
    [] -> Error(Nil)
    [item] -> Ok(item)
    [head, ..rest] -> {
      list.fold(rest, head, fn(acc, item) {
        case compare(item, acc) {
          order.Lt -> item
          _other -> acc
        }
      })
      |> Ok()
    }
  }
}

fn line_segments(positions: List(Position)) -> List(LineSegment) {
  use <- bool.guard(list.length(positions) < 2, return: [])
  let assert Ok(first) = list.first(positions)
  let assert Ok(last) = list.last(positions)
  use <- bool.guard(list.length(positions) == 2, return: [
    LineSegment(a: first, b: last),
  ])

  positions
  |> list.window_by_2()
  |> list.map(fn(pair) { LineSegment(a: pair.0, b: pair.1) })
  |> list.prepend(LineSegment(a: last, b: first))
}

fn is_rectangle_eligible(map: Map, rectangle: QuadRectangle) -> Bool {
  let all_corners_eligible =
    { is_rectangle_corner_eligible(map, rectangle.a) }
    && { is_rectangle_corner_eligible(map, rectangle.b) }
    && { is_rectangle_corner_eligible(map, rectangle.c) }
    && { is_rectangle_corner_eligible(map, rectangle.d) }

  use <- bool.guard(!all_corners_eligible, return: False)

  { is_rectangle_side_eligible(map, rectangle.a, rectangle.b) }
  && { is_rectangle_side_eligible(map, rectangle.a, rectangle.c) }
  && { is_rectangle_side_eligible(map, rectangle.b, rectangle.d) }
  && { is_rectangle_side_eligible(map, rectangle.c, rectangle.d) }
}

fn is_rectangle_corner_eligible(map: Map, corner: Position) -> Bool {
  let known_outside = Position(x: corner.x, y: map.min_y - 1)
  let column_points =
    map.expanded_by_x
    |> dict.get(known_outside.x)
    |> result.unwrap(or: [])

  let #(inside, found_point) =
    column_points
    |> list.prepend(known_outside)
    |> list.window_by_2()
    |> list.fold_until(#(False, False), fn(acc, points) {
      let #(inside, _found_point) = acc
      let #(last_point, point) = points
      use <- bool.guard(point == corner, return: list.Stop(#(True, True)))
      use <- bool.guard(point.y >= corner.y, return: list.Stop(#(inside, True)))
      case off_by_one(last_point, point) && inside {
        True -> list.Continue(#(inside, False))
        False -> list.Continue(#(!inside, False))
      }
    })

  found_point && inside
}

fn is_rectangle_side_eligible(map: Map, corner1: Position, corner2: Position) {
  let #(corner1, corner2) = sort_points(corner1, corner2)
  let #(get_component, get_static_component, expanded_by_component) =
    rectangle_side_check_parts(map, corner1, corner2)

  let points_to_walk =
    expanded_by_component
    |> dict.get(get_static_component(corner1))
    |> result.unwrap(or: [])
    |> list.filter(fn(point) { get_component(point) >= get_component(corner1) })

  points_to_walk
  |> list.window_by_2()
  |> list.fold_until(True, fn(_acc, points) {
    let #(last_point, point) = points
    use <- bool.guard(point == corner2, return: list.Stop(True))
    use <- bool.guard(
      get_component(point) >= get_component(corner2),
      return: list.Stop(True),
    )
    case off_by_one(last_point, point) {
      True -> list.Continue(True)
      False -> list.Stop(False)
    }
  })
}

fn rectangle_side_check_parts(
  map: Map,
  corner1: Position,
  corner2: Position,
) -> #(fn(Position) -> Int, fn(Position) -> Int, dict.Dict(Int, List(Position))) {
  case corner1.x == corner2.x {
    True -> #(
      fn(point: Position) { point.y },
      fn(point: Position) { point.x },
      map.expanded_by_x,
    )
    False -> #(
      fn(point: Position) { point.x },
      fn(point: Position) { point.y },
      map.expanded_by_y,
    )
  }
}

fn off_by_one(a: Position, b: Position) -> Bool {
  { a.x == b.x && int.absolute_value(a.y - b.y) == 1 }
  || { a.y == b.y && int.absolute_value(a.x - b.x) == 1 }
}

fn sort_points(pos1: Position, pos2: Position) -> #(Position, Position) {
  case pos1.x > pos2.x || pos1.y > pos2.y {
    True -> #(pos2, pos1)
    False -> #(pos1, pos2)
  }
}

fn area(pos1: Position, pos2: Position) -> Int {
  { int.absolute_value(pos1.x - pos2.x) + 1 }
  * { int.absolute_value(pos1.y - pos2.y) + 1 }
}

fn parse_input(input: String) -> Result(List(Position), String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_map(parse_position)
}

fn parse_position(data: String) -> Result(Position, String) {
  data
  |> string.split(",")
  |> list.try_map(parse_int)
  |> result.try(fn(axes) {
    case axes {
      [x, y] -> Ok(Position(x:, y:))
      _ -> Error("Position must have two components: '" <> data <> "'")
    }
  })
}

fn parse_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed int '" <> input <> "'" })
}

@external(erlang, "day9_ffi", "num_schedulers")
fn num_schedulers() -> Int
