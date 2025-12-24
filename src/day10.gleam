import advent_of_code_2025
import gleam/bool
import gleam/deque
import gleam/dict
import gleam/float
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/order
import gleam/pair
import gleam/regexp
import gleam/result
import gleam/set
import gleam/string

const epsilon = 0.000001

type ButtonConfig {
  ButtonConfig(light_toggles: List(Int))
}

type LightConfig {
  LightConfig(desired: List(Int), num: Int)
}

type ManualEntry {
  ManualEntry(
    light_config: LightConfig,
    buttons: List(ButtonConfig),
    joltage_requirements: List(Int),
  )
}

type InputComponents {
  InputComponents(
    light_diagram: String,
    button_schematics: List(String),
    joltage_requirements: String,
  )
}

type Lights {
  Lights(dict.Dict(Int, Bool))
}

type Matrix {
  Matrix(rows: Int, columns: Int, entries: dict.Dict(#(Int, Int), Float))
}

type EquationComponent {
  Constant(n: Float)
  Variable(index: Int, coefficient: Float)
}

type Equation {
  Equation(variable_index: Int, dependencies: List(EquationComponent))
}

type JoltageSlot {
  JoltageSlot(
    required_joltage: Int,
    equation_buttons: List(#(IndexedButton, Equation)),
    free_buttons: List(IndexedButton),
  )
}

type IndexedButton {
  IndexedButton(button: ButtonConfig, index: Int)
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use manual_entries <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(manual_entries))
  io.println("Part 2: " <> part2(manual_entries))

  Ok(Nil)
}

fn part1(entries: List(ManualEntry)) -> String {
  entries
  |> list.try_map(find_light_config_path_length)
  |> result.map(fn(path) {
    path
    |> int.sum()
    |> int.to_string()
  })
  |> result.unwrap(or: "No result found")
}

fn part2(entries: List(ManualEntry)) -> String {
  entries
  |> list.try_map(find_joltage_config_path_length)
  |> result.map(fn(path) {
    path
    |> int.sum()
    |> int.to_string()
  })
  |> result.unwrap(or: "No result found")
}

fn find_light_config_path_length(entry: ManualEntry) -> Result(Int, Nil) {
  let to_visit =
    entry.buttons
    |> list.map(fn(_button_config) {
      #(0, all_off_lights_from_config(entry.light_config))
    })
    |> deque.from_list()

  do_find_light_config_path_length(
    entry.light_config,
    to_visit,
    entry.buttons,
    set.new(),
  )
}

fn do_find_light_config_path_length(
  target: LightConfig,
  to_visit: deque.Deque(#(Int, Lights)),
  buttons: List(ButtonConfig),
  visited: set.Set(Lights),
) -> Result(Int, Nil) {
  use entry, to_visit <- try_pop_front(to_visit, or: Error(Nil))
  let #(depth, lights) = entry

  use <- bool.guard(matches_desired(lights, target), return: Ok(depth))
  let visited = set.insert(visited, lights)

  let #(to_visit, visited) =
    list.fold(buttons, #(to_visit, visited), fn(acc, button_config) {
      let #(to_visit, visited) = acc

      let assert Ok(next_lights) = apply_button_config(lights, button_config)
      case set.contains(visited, next_lights) {
        True -> #(to_visit, visited)
        False -> {
          #(
            deque.push_back(to_visit, #(depth + 1, next_lights)),
            // Set visited optimistically, because if we've already seen it, we know there's a shorter path.
            set.insert(visited, next_lights),
          )
        }
      }
    })

  do_find_light_config_path_length(target, to_visit, buttons, visited)
}

fn lights_from_config(config: LightConfig) -> Lights {
  list.range(0, config.num - 1)
  |> list.map(fn(index) { #(index, list.contains(config.desired, index)) })
  |> dict.from_list()
  |> Lights()
}

fn all_off_lights_from_config(config: LightConfig) -> Lights {
  list.range(0, config.num - 1)
  |> list.map(fn(index) { #(index, False) })
  |> dict.from_list()
  |> Lights()
}

fn apply_button_config(
  lights: Lights,
  button_config: ButtonConfig,
) -> Result(Lights, Nil) {
  list.try_fold(button_config.light_toggles, lights, fn(lights, idx) {
    toggle_light(lights, idx)
  })
}

fn toggle_light(lights: Lights, index: Int) -> Result(Lights, Nil) {
  let Lights(light_map) = lights
  light_map
  |> dict.get(index)
  |> result.map(fn(value) { Lights(dict.insert(light_map, index, !value)) })
}

fn matches_desired(lights: Lights, config: LightConfig) -> Bool {
  lights_from_config(config) == lights
}

fn try_pop_front(
  deque: deque.Deque(a),
  or or: b,
  continue continue: fn(a, deque.Deque(a)) -> b,
) -> b {
  case deque.pop_front(deque) {
    Ok(#(front, deque)) -> continue(front, deque)
    Error(Nil) -> or
  }
}

fn find_joltage_config_path_length(entry: ManualEntry) -> Result(Int, Nil) {
  let matrix = joltage_matrix(entry)
  let rref = rref(matrix)
  let free_variables = free_variable_indices(rref)
  let equations =
    rref
    |> build_equations()
    |> normalize_equations(free_variables)

  brute_force_free_variables(entry, equations, free_variables)
  |> option.to_result(Nil)
}

fn joltage_matrix(entry: ManualEntry) -> Matrix {
  // Can't fail unless we have a malformed input
  let assert Ok(matrix) =
    entry.joltage_requirements
    |> list.index_map(fn(joltage, index) {
      let applicable_buttons =
        entry.buttons
        |> list.index_map(fn(button, button_index) {
          case button_toggles_index(button, index) {
            True -> Ok(button_index)
            False -> Error(Nil)
          }
        })
        |> list.filter_map(function.identity)

      list.range(0, list.length(entry.buttons) - 1)
      |> list.map(fn(column) {
        case list.contains(applicable_buttons, column) {
          True -> 1.0
          False -> 0.0
        }
      })
      |> list.append([int.to_float(joltage)])
    })
    |> new_matrix()

  matrix
}

fn button_toggles_index(button: ButtonConfig, index: Int) -> Bool {
  list.any(button.light_toggles, fn(toggle_index) { index == toggle_index })
}

fn free_variable_indices(rref_matrix: Matrix) -> List(Int) {
  rref_matrix
  |> map_rows(fn(row) {
    let assert Ok(free_indices) = free_variable_index(row)
    free_indices
  })
  |> list.flatten()
  |> list.unique()
}

fn free_variable_index(rref_row: List(Float)) -> Result(List(Int), Nil) {
  do_free_variable_index(rref_row, list.length(rref_row), 0, False, [])
}

fn do_free_variable_index(
  rref_row: List(Float),
  row_size: Int,
  index: Int,
  past_pivot: Bool,
  acc: List(Int),
) -> Result(List(Int), Nil) {
  case rref_row {
    _ if index == row_size - 1 -> Ok(acc)
    [] -> Ok(acc)
    [0.0, ..rest] ->
      do_free_variable_index(rest, row_size, index + 1, past_pivot, acc)
    [1.0, ..rest] if !past_pivot ->
      do_free_variable_index(rest, row_size, index + 1, True, acc)
    [_value, ..rest] if past_pivot ->
      do_free_variable_index(rest, row_size, index + 1, True, [index, ..acc])
    _other -> Error(Nil)
  }
}

fn build_equations(rref_matrix: Matrix) -> List(Equation) {
  map_rows(rref_matrix, fn(row) { build_equation(row) })
  |> list.filter_map(function.identity)
}

fn build_equation(rref_row: List(Float)) -> Result(Equation, Nil) {
  do_build_equation(rref_row, 0, option.None, [])
}

fn do_build_equation(
  rref_row: List(Float),
  index: Int,
  lhs_index: option.Option(Int),
  rhs: List(EquationComponent),
) -> Result(Equation, Nil) {
  case rref_row, lhs_index {
    [], option.None -> {
      Error(Nil)
    }
    [], option.Some(lhs) -> {
      Ok(Equation(lhs, rhs))
    }

    [1.0, ..rest], option.None -> {
      do_build_equation(rest, index + 1, option.Some(index), rhs)
    }

    [0.0, ..rest], _any -> {
      do_build_equation(rest, index + 1, lhs_index, rhs)
    }

    [_other, ..], option.None -> {
      panic as "matrix is not in rref"
    }

    [head], option.Some(_lhs) -> {
      do_build_equation([], index + 1, lhs_index, [Constant(head), ..rhs])
    }

    [head, ..rest], option.Some(_lhs) -> {
      do_build_equation(rest, index + 1, lhs_index, [
        Variable(index:, coefficient: float.negate(head)),
        ..rhs
      ])
    }
  }
}

fn normalize_equations(
  equations: List(Equation),
  free_variables: List(Int),
) -> List(Equation) {
  list.map(equations, fn(equation) {
    normalize_equation(equation, free_variables)
  })
}

fn normalize_equation(equation: Equation, free_variables: List(Int)) -> Equation {
  let upd_dependencies =
    free_variables
    |> list.fold(equation.dependencies, fn(dependencies, free_variable_index) {
      let existing_dependency =
        list.find(dependencies, fn(dependency) {
          case dependency {
            Variable(index: index, ..) if index == free_variable_index -> {
              True
            }

            _other -> False
          }
        })

      case existing_dependency {
        Ok(_dependency) -> dependencies
        Error(Nil) -> [
          Variable(index: free_variable_index, coefficient: 0.0),
          ..dependencies
        ]
      }
    })
    |> list.sort(fn(a, b) {
      case a, b {
        Constant(n), Constant(m) -> float.compare(n, m)
        Constant(..), Variable(..) -> order.Lt
        Variable(..), Constant(..) -> order.Gt
        Variable(index: index_a, ..), Variable(index: index_b, ..) ->
          int.compare(index_a, index_b)
      }
    })

  Equation(..equation, dependencies: upd_dependencies)
}

fn brute_force_free_variables(
  manual_entry: ManualEntry,
  equations: List(Equation),
  free_variable_indices: List(Int),
) -> option.Option(Int) {
  // The worst upper bound is the maximum joltage across the board
  let max_joltage =
    list.max(manual_entry.joltage_requirements, int.compare)
    |> result.unwrap(or: 0)

  let joltage_slots = map_buttons_to_slots(manual_entry, equations)
  let min_joltage_by_button = min_joltage_by_free_button(joltage_slots)
  // ...but can be reduced to the minimum joltage that each button effects
  let free_variable_bounds =
    list.map(free_variable_indices, fn(index) {
      min_joltage_by_button
      |> dict.get(index)
      |> result.unwrap(or: max_joltage)
    })

  brute_force_minimum(free_variable_bounds, fn(values) {
    let variable_values =
      free_variable_indices
      |> list.zip(list.map(values, int.to_float))
      |> dict.from_list()

    presses_to_make_joltages(joltage_slots, variable_values)
  })
}

fn brute_force_minimum(
  search_depths: List(Int),
  make_value: fn(List(Int)) -> option.Option(Int),
) -> option.Option(Int) {
  do_brute_force_minimum(search_depths, make_value, [], option.None)
}

fn do_brute_force_minimum(
  search_depths: List(Int),
  make_value: fn(List(Int)) -> option.Option(Int),
  values: List(Int),
  min: option.Option(Int),
) -> option.Option(Int) {
  case search_depths {
    [] -> {
      let res =
        // Pass the values in in the same order we got the depths to ensure consistency
        values
        |> list.reverse()
        |> make_value()
      case res, min {
        option.None, option.None -> option.None
        option.None, option.Some(min) -> option.Some(min)
        option.Some(res), option.None -> option.Some(res)
        option.Some(res), option.Some(min) -> {
          option.Some(int.min(res, min))
        }
      }
    }

    [depth, ..rest_depths] -> {
      list.range(0, depth)
      |> list.fold(min, fn(min, value) {
        do_brute_force_minimum(rest_depths, make_value, [value, ..values], min)
      })
    }
  }
}

fn plug_into_equation(equation: Equation, variables: List(Float)) -> Float {
  let assert #([], result) =
    equation.dependencies
    |> list.fold(#(variables, 0.0), fn(acc, component) {
      let #(variables, n) = acc

      case component {
        Constant(value) -> #(variables, n +. value)
        Variable(coefficient:, ..) -> {
          let assert [variable, ..rest] = variables
          #(rest, normalize_values(n +. variable *. coefficient))
        }
      }
    })

  result
}

fn map_buttons_to_slots(
  manual_entry: ManualEntry,
  equations: List(Equation),
) -> List(JoltageSlot) {
  let pairings = pair_equations_to_buttons(manual_entry.buttons, equations)

  list.index_map(manual_entry.joltage_requirements, fn(joltage, joltage_index) {
    list.index_fold(
      pairings,
      JoltageSlot(
        required_joltage: joltage,
        equation_buttons: [],
        free_buttons: [],
      ),
      fn(slot, pair, pair_index) {
        let #(button, maybe_equation) = pair
        use <- bool.guard(!button_toggles_index(button, joltage_index), slot)

        let indexed_button = IndexedButton(button:, index: pair_index)
        case maybe_equation {
          option.Some(equation) ->
            JoltageSlot(..slot, equation_buttons: [
              #(indexed_button, equation),
              ..slot.equation_buttons
            ])
          option.None ->
            JoltageSlot(..slot, free_buttons: [
              indexed_button,
              ..slot.free_buttons
            ])
        }
      },
    )
  })
}

fn pair_equations_to_buttons(
  buttons: List(ButtonConfig),
  equations: List(Equation),
) -> List(#(ButtonConfig, option.Option(Equation))) {
  do_pair_equations_to_buttons(buttons, 0, equations)
}

fn do_pair_equations_to_buttons(
  buttons: List(ButtonConfig),
  index: Int,
  equations: List(Equation),
) -> List(#(ButtonConfig, option.Option(Equation))) {
  use button, buttons <- try_pop(buttons, [])

  let find_equation_res =
    list.find(equations, fn(equation) { equation.variable_index == index })

  let other_pairs = do_pair_equations_to_buttons(buttons, index + 1, equations)
  case find_equation_res {
    Ok(equation) -> [#(button, option.Some(equation)), ..other_pairs]
    Error(Nil) -> [#(button, option.None), ..other_pairs]
  }
}

fn min_joltage_by_free_button(joltage_slots: List(JoltageSlot)) {
  joltage_slots
  |> list.fold(dict.new(), fn(acc, slot) {
    list.fold(slot.free_buttons, acc, fn(acc, button) {
      let min_joltage = case dict.get(acc, button.index) {
        Ok(min) -> int.min(slot.required_joltage, min)
        Error(Nil) -> slot.required_joltage
      }

      dict.insert(acc, button.index, min_joltage)
    })
  })
}

fn presses_to_make_joltages(
  slots: List(JoltageSlot),
  free_variables: dict.Dict(Int, Float),
) -> option.Option(Int) {
  let ordered_free_vars =
    free_variables
    |> dict.to_list()
    |> list.sort(fn(a, b) { int.compare(pair.first(a), pair.first(b)) })
    |> list.map(pair.second)

  slots
  |> list.fold_until(option.Some(dict.new()), fn(acc, slot) {
    // We don't have None in the acc, this is just used as the final result
    let assert option.Some(presses_by_index) = acc
    let free_presses =
      slot.free_buttons
      |> list.map(fn(indexed_button) {
        let assert Ok(value) = dict.get(free_variables, indexed_button.index)

        #(indexed_button, value)
      })

    let local_presses =
      slot.equation_buttons
      |> list.map(fn(entry) {
        let #(indexed_button, equation) = entry
        #(indexed_button, plug_into_equation(equation, ordered_free_vars))
      })
      |> list.append(free_presses)
      |> dict.from_list()

    let joltage = float.sum(dict.values(local_presses))
    let presses_valid =
      local_presses
      |> dict.values()
      |> list.all(fn(value) {
        normalize_values(value) >=. 0.0
        && normalize_values(value) == float.floor(value)
      })

    let is_joltage =
      float.loosely_equals(
        joltage,
        int.to_float(slot.required_joltage),
        epsilon,
      )

    case is_joltage && presses_valid {
      False -> list.Stop(option.None)
      True -> {
        let combined =
          dict.combine(local_presses, presses_by_index, fn(a, b) {
            assert a == b
            a
          })

        list.Continue(option.Some(combined))
      }
    }
  })
  |> option.map(fn(presses) {
    presses
    |> dict.values()
    |> float.sum()
    |> float.truncate()
  })
}

fn new_matrix(rows: List(List(Float))) -> Result(Matrix, Nil) {
  let row_dim = list.length(rows)

  use <- bool.guard(row_dim == 0, return: Error(Nil))
  use col_dim <- result.try(column_dimension(rows))

  let entries =
    list.index_fold(rows, dict.new(), fn(acc, row_entries, row) {
      list.index_fold(row_entries, acc, fn(acc, entry, col) {
        dict.insert(acc, #(row, col), entry)
      })
    })

  Ok(Matrix(rows: row_dim, columns: col_dim, entries:))
}

fn column_dimension(rows: List(List(Float))) -> Result(Int, Nil) {
  case rows {
    [] -> Error(Nil)
    [head, ..rest] -> {
      let head_length = list.length(head)
      let others_have_length =
        list.all(rest, fn(other) { list.length(other) == head_length })

      use <- bool.guard(!others_have_length, return: Error(Nil))
      Ok(head_length)
    }
  }
}

// Adaptation of this algorithm https://rosettacode.org/wiki/Reduced_row_echelon_form#Common_Lisp
fn rref(matrix: Matrix) -> Matrix {
  do_rref(matrix, 0, 0)
}

fn do_rref(matrix: Matrix, current_row: Int, pivot_col: Int) -> Matrix {
  use <- bool.guard(
    current_row >= matrix.rows || pivot_col >= matrix.columns,
    return: matrix,
  )

  use #(pivot_row, pivot_col) <- ok_or(
    find_pivot_position(matrix, current_row, pivot_col),
    matrix,
  )

  let assert Ok(matrix) = swap_rows(matrix, pivot_row, current_row)
  let assert Ok(pivot) = dict.get(matrix.entries, #(current_row, pivot_col))
  let matrix = case pivot {
    0.0 -> matrix
    _other -> {
      let assert Ok(matrix) =
        map_row(matrix, current_row, fn(value) {
          normalize_values(value /. pivot)
        })

      matrix
    }
  }

  list.range(0, matrix.rows - 1)
  |> list.filter(fn(n) { n != current_row })
  |> list.fold(matrix, fn(matrix, n) {
    let assert Ok(factor) = dict.get(matrix.entries, #(n, pivot_col))
    let assert Ok(matrix) =
      index_map_row(matrix, n, fn(value, column) {
        let assert Ok(current_row_value) =
          dict.get(matrix.entries, #(current_row, column))

        normalize_values(value -. { current_row_value *. factor })
      })

    matrix
  })
  |> do_rref(current_row + 1, pivot_col + 1)
}

fn swap_rows(matrix: Matrix, row1: Int, row2: Int) -> Result(Matrix, Nil) {
  use <- bool.guard(row1 < 0 || row1 >= matrix.rows, return: Error(Nil))
  use <- bool.guard(row2 < 0 || row2 >= matrix.rows, return: Error(Nil))

  let row1_entries =
    list.range(0, matrix.columns - 1)
    |> list.map(fn(column) {
      let assert Ok(value) = dict.get(matrix.entries, #(row1, column))

      #(#(row1, column), value)
    })

  let row2_entries =
    list.range(0, matrix.columns - 1)
    |> list.map(fn(column) {
      let assert Ok(value) = dict.get(matrix.entries, #(row2, column))

      #(#(row2, column), value)
    })

  let entries =
    list.fold(row1_entries, matrix.entries, fn(acc, entry) {
      let #(#(_row, col), value) = entry
      dict.insert(acc, #(row2, col), value)
    })

  let entries =
    list.fold(row2_entries, entries, fn(acc, entry) {
      let #(#(_row, col), value) = entry
      dict.insert(acc, #(row1, col), value)
    })

  Ok(Matrix(..matrix, entries:))
}

fn find_pivot_position(
  matrix: Matrix,
  current_row: Int,
  current_pivot_col: Int,
) -> option.Option(#(Int, Int)) {
  do_find_pivot_position(matrix, current_row, current_row, current_pivot_col)
}

fn do_find_pivot_position(
  matrix: Matrix,
  current_row: Int,
  current_pivot_row: Int,
  current_pivot_col: Int,
) -> option.Option(#(Int, Int)) {
  let assert Ok(value) =
    dict.get(matrix.entries, #(current_pivot_row, current_pivot_col))

  case float.loosely_equals(0.0, value, epsilon) {
    True
      if current_pivot_row == matrix.rows - 1
      && current_pivot_col == matrix.columns - 1
    -> {
      option.None
    }

    True if current_pivot_row == matrix.rows - 1 -> {
      do_find_pivot_position(
        matrix,
        current_row,
        current_row,
        current_pivot_col + 1,
      )
    }

    True ->
      do_find_pivot_position(
        matrix,
        current_row,
        current_pivot_row + 1,
        current_pivot_col,
      )

    _other -> option.Some(#(current_pivot_row, current_pivot_col))
  }
}

fn map_rows(matrix: Matrix, map: fn(List(Float)) -> a) -> List(a) {
  list.range(0, matrix.rows - 1)
  |> list.map(fn(row) {
    list.range(0, matrix.columns - 1)
    |> list.map(fn(column) {
      let assert Ok(value) = dict.get(matrix.entries, #(row, column))
      value
    })
    |> map()
  })
}

fn index_map_row(
  matrix: Matrix,
  row: Int,
  map: fn(Float, Int) -> Float,
) -> Result(Matrix, Nil) {
  use <- bool.guard(row >= matrix.rows, Error(Nil))

  let entries =
    list.range(0, matrix.columns - 1)
    |> list.map(fn(column) {
      let assert Ok(value) = dict.get(matrix.entries, #(row, column))
      #(#(row, column), map(value, column))
    })
    |> list.fold(matrix.entries, fn(entries, entry) {
      let #(position, value) = entry

      dict.insert(entries, position, value)
    })

  Ok(Matrix(..matrix, entries:))
}

fn map_row(
  matrix: Matrix,
  row: Int,
  map: fn(Float) -> Float,
) -> Result(Matrix, Nil) {
  index_map_row(matrix, row, fn(value, _index) { map(value) })
}

fn ok_or(option: option.Option(a), or: b, continue: fn(a) -> b) -> b {
  case option {
    option.Some(value) -> continue(value)
    option.None -> or
  }
}

fn normalize_values(n: Float) -> Float {
  use <- bool.guard(float.loosely_equals(0.0, n, epsilon), 0.0)

  use <- bool.guard(
    float.loosely_equals(float.floor(n), n, epsilon),
    float.floor(n),
  )

  use <- bool.guard(
    float.loosely_equals(float.ceiling(n), n, epsilon),
    float.ceiling(n),
  )

  n
}

fn print_matrix(matrix: Matrix) -> Nil {
  list.range(0, matrix.rows - 1)
  |> list.each(fn(row) {
    io.print("[ ")
    list.range(0, matrix.columns - 1)
    |> list.each(fn(col) {
      let assert Ok(value) = dict.get(matrix.entries, #(row, col))
      case float.floor(value) == value {
        True -> io.print(int.to_string(float.truncate(value)) <> " ")
        False -> io.print(float.to_string(value) <> " ")
      }
    })
    io.println(" ]")
  })

  io.println("")
}

fn try_pop(list: List(a), or: b, continue continue: fn(a, List(a)) -> b) -> b {
  case list {
    [] -> or
    [head, ..rest] -> continue(head, rest)
  }
}

fn parse_input(input: String) -> Result(List(ManualEntry), String) {
  let assert Ok(pattern) =
    regexp.compile(
      "^\\[([.#]+)\\] ((?:\\([0-9,]+\\) )*\\([0-9,]+\\)) {((?:[0-9,])*)}$",
      regexp.Options(case_insensitive: False, multi_line: True),
    )

  case regexp.scan(pattern, input) {
    [] -> Error("Input does not match pattern")
    matches -> {
      matches
      |> list.map(fn(match) {
        // Must be true by pattern
        let assert [
          option.Some(light_diagram),
          option.Some(button_schematics),
          option.Some(joltage_requirements),
        ] = match.submatches

        InputComponents(
          light_diagram:,
          button_schematics: string.split(button_schematics, " "),
          joltage_requirements:,
        )
      })
      |> list.try_map(parse_input_components)
    }
  }
}

fn parse_input_components(
  input_components: InputComponents,
) -> Result(ManualEntry, String) {
  use light_config <- result.try(parse_light_diagram(
    input_components.light_diagram,
  ))

  use buttons <- result.try(parse_button_schematics(
    input_components.button_schematics,
  ))

  use joltage_requirements <- result.try(parse_joltage_requirements(
    input_components.joltage_requirements,
  ))

  Ok(ManualEntry(light_config:, buttons:, joltage_requirements:))
}

fn parse_light_diagram(diagram: String) -> Result(LightConfig, String) {
  let on_off_res =
    diagram
    |> string.to_graphemes()
    |> list.try_map(fn(char) {
      case char {
        "#" -> Ok(True)
        "." -> Ok(False)
        other -> Error("Invalid light char: " <> other)
      }
    })

  use on_off <- result.try(on_off_res)

  let desired_lights =
    on_off
    |> list.index_map(fn(on, index) { #(index, on) })
    |> list.filter(pair.second)
    |> list.map(pair.first)

  Ok(LightConfig(desired: desired_lights, num: list.length(on_off)))
}

fn parse_button_schematics(
  button_schematics: List(String),
) -> Result(List(ButtonConfig), String) {
  list.try_map(button_schematics, parse_button_schematic)
}

fn parse_button_schematic(
  button_schematic: String,
) -> Result(ButtonConfig, String) {
  case
    string.starts_with(button_schematic, "(")
    && string.ends_with(button_schematic, ")")
  {
    True -> {
      button_schematic
      |> string.drop_start(1)
      |> string.drop_end(1)
      |> string.split(",")
      |> list.try_map(parse_int)
      |> result.map(ButtonConfig)
    }

    _ -> Error("Invalid button schematic: " <> button_schematic)
  }
}

fn parse_joltage_requirements(config: String) -> Result(List(Int), String) {
  config
  |> string.split(",")
  |> list.try_map(parse_int)
}

fn parse_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed int '" <> input <> "'" })
}
