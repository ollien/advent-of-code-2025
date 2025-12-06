import advent_of_code_2025
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

type Operator {
  Add
  Multiply
}

type Alignment {
  Left
  Right
}

type Problem {
  Problem(operands: List(Int), operator: Operator, alignment: Alignment)
}

type Digit {
  Digit(Int)
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use problems <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(problems))
  io.println("Part 2: " <> part2(problems))

  Ok(Nil)
}

fn part1(problems: List(Problem)) -> String {
  problems
  |> list.map(solve_problem)
  |> int.sum()
  |> int.to_string()
}

fn part2(problems: List(Problem)) -> String {
  problems
  |> list.map(transpose_problem)
  |> list.map(solve_problem)
  |> int.sum()
  |> int.to_string()
}

fn solve_problem(problem: Problem) -> Int {
  case problem.operator {
    Add -> int.sum(problem.operands)
    Multiply -> int.product(problem.operands)
  }
}

fn transpose_problem(problem: Problem) -> Problem {
  let operands = transpose_operands(problem.operands, problem.alignment)
  Problem(..problem, operands:)
}

fn transpose_operands(operands: List(Int), alignment: Alignment) -> List(Int) {
  operands
  |> list.map(count_digits)
  |> list.max(int.compare)
  |> result.map(fn(max_digits) {
    operands
    |> list.map(fn(operand) {
      operand
      |> split_digits()
      |> pad_to_length(max_digits, alignment)
    })
    |> list.transpose()
    |> list.map(fn(maybe_digits) {
      let digits =
        maybe_digits
        |> list.filter_map(fn(maybe_digit) {
          option.to_result(maybe_digit, Nil)
        })

      concat_digits(digits)
    })
  })
  // If there's no maximum, the operands are empty, so there's nothing to transpose
  |> result.unwrap(or: operands)
}

fn count_digits(n: Int) -> Int {
  let log_10_floor =
    n
    |> int.absolute_value()
    |> int.to_float()
    |> log_10()
    // 0 would be 1 digit
    |> result.unwrap(or: 1.0)
    |> float.floor()
    |> float.truncate()

  log_10_floor + 1
}

fn split_digits(n: Int) -> List(Digit) {
  n
  |> do_split_digits()
  |> list.reverse()
}

fn do_split_digits(n: Int) -> List(Digit) {
  case n % 10 == n {
    True -> [Digit(n)]
    False -> {
      [Digit(n % 10), ..do_split_digits(n / 10)]
    }
  }
}

fn concat_digits(digits: List(Digit)) -> Int {
  list.fold(digits, 0, fn(acc, digit) {
    let Digit(n) = digit
    // We know from the type this must be 0-9
    acc * 10 + n
  })
}

fn pad_to_length(
  list: List(a),
  length: Int,
  alignment: Alignment,
) -> List(option.Option(a)) {
  let padding_needed = length - list.length(list)
  let padding = list.repeat(option.None, times: padding_needed)

  case alignment {
    Left -> {
      list
      |> list.map(option.Some)
      |> list.append(padding)
    }

    Right -> {
      list.append(padding, list.map(list, option.Some))
    }
  }
}

fn parse_input(input: String) -> Result(List(Problem), String) {
  use #(raw_number_rows, raw_operators) <- result.try(split_operators(input))
  use operators <- result.try(parse_operators(raw_operators))

  let column_widths = derive_column_widths(raw_operators)
  use number_rows <- result.try(parse_number_rows(
    raw_number_rows,
    column_widths,
  ))

  number_rows
  |> list.transpose()
  |> list.zip(operators)
  |> list.try_map(fn(pair) {
    let #(column_entries, operator) = pair
    use #(operands, alignment) <- result.try(decompose_column(column_entries))
    Ok(Problem(operands:, operator:, alignment:))
  })
}

fn parse_operators(raw_operators: String) -> Result(List(Operator), String) {
  raw_operators
  |> string.trim_end()
  |> normalize_spaces()
  |> string.split(" ")
  |> list.try_map(parse_operator)
}

fn derive_column_widths(raw_operators: String) -> List(Int) {
  // Operators are always left aligned, so we can use the spaces between them to get the corresponding column widths
  let widths =
    raw_operators
    // Drop the first operator
    |> string.drop_start(1)
    |> string.to_graphemes()
    |> list.fold([0], fn(acc, char) {
      // Our starter accumulator guarantees we will have at least one item
      let assert [current_count, ..rest] = acc
      case char {
        " " -> [current_count + 1, ..rest]
        _other -> [0, current_count, ..rest]
      }
    })

  case widths {
    [] -> []
    // There is no trailing space we can use as a + 1 so we add it here
    [last_width, ..rest] -> list.reverse([last_width + 1, ..rest])
  }
}

fn parse_number_rows(
  raw_numbers: List(String),
  column_widths: List(Int),
) -> Result(List(List(#(Int, Alignment))), String) {
  raw_numbers
  |> list.map(fn(line) {
    // Force lines to end with a space so we can know where each entry ends
    case string.ends_with(line, " ") {
      True -> line
      False -> line <> " "
    }
  })
  |> list.try_map(fn(line) { parse_number_row(line, column_widths) })
}

fn parse_number_row(
  line: String,
  column_widths: List(Int),
) -> Result(List(#(Int, Alignment)), String) {
  column_widths
  |> list.try_fold(#([], line), fn(acc, width) {
    let #(entries, remaining) = acc

    let column = string.slice(remaining, 0, width)
    use column_value <- result.try(parse_int(string.trim(column)))

    let rest = string.drop_start(remaining, width + 1)
    case string.starts_with(column, " ") {
      True -> Ok(#([#(column_value, Right), ..entries], rest))
      False -> Ok(#([#(column_value, Left), ..entries], rest))
    }
  })
  |> result.map(fn(res) { list.reverse(res.0) })
}

fn decompose_column(
  entries: List(#(Int, Alignment)),
) -> Result(#(List(Int), Alignment), String) {
  let values = list.map(entries, fn(entry) { entry.0 })
  let alignments =
    list.fold(entries, dict.new(), fn(acc, entry) {
      let #(n, alignment) = entry
      let acc_entry =
        acc
        |> dict.get(alignment)
        |> result.unwrap(or: [])

      dict.insert(acc, alignment, [n, ..acc_entry])
    })

  let lefts =
    alignments
    |> dict.get(Left)
    |> result.unwrap(or: [])

  let rights =
    alignments
    |> dict.get(Right)
    |> result.unwrap(or: [])

  // If we're lucky, everything will be left/right aligned
  // However, there is an ambiguity when a number takes up the full width,
  // so in those cases we look at the "odd ones out" and make sure
  // that nothing in the opposite alignment is wider.
  case lefts, rights {
    _lefts, [] -> Ok(#(values, Left))
    [], _rights -> Ok(#(values, Right))
    lefts, rights -> {
      let left_counts =
        lefts
        |> list.map(count_digits)
        |> list.unique()

      let right_counts =
        rights
        |> list.map(count_digits)
        |> list.unique()

      let alignment_res = case left_counts, right_counts {
        [left_count], right_counts -> {
          // We know the list must be non empty
          let assert Ok(max_right_counts) = list.max(right_counts, int.compare)
          case left_count >= max_right_counts {
            True -> Ok(Right)
            False -> Error(Nil)
          }
        }

        left_counts, [right_count] -> {
          // We know the list must be non empty
          let assert Ok(max_left_counts) = list.max(left_counts, int.compare)
          case right_count >= max_left_counts {
            True -> Ok(Left)
            False -> Error(Nil)
          }
        }

        _, _ -> {
          Error(Nil)
        }
      }

      alignment_res
      |> result.map(fn(alignment) { #(values, alignment) })
      |> result.map_error(fn(_: Nil) {
        "Column entries do not have consistent alignments:  "
        <> make_misalignment_error_debug(entries)
      })
    }
  }
}

fn make_misalignment_error_debug(entries: List(#(Int, Alignment))) -> String {
  entries
  |> list.map(fn(pair) {
    int.to_string(pair.0) <> " " <> alignment_string(pair.1)
  })
  |> string.join(", ")
}

fn alignment_string(alignment: Alignment) -> String {
  case alignment {
    Left -> "Left"
    Right -> "Right"
  }
}

fn normalize_spaces(string: String) -> String {
  let assert Ok(spaces_pattern) =
    regexp.compile(
      "[ ]+",
      regexp.Options(multi_line: False, case_insensitive: False),
    )

  regexp.replace(spaces_pattern, string, " ")
}

fn split_operators(input: String) -> Result(#(List(String), String), String) {
  input
  |> string.split("\n")
  |> trim_trailing_empty()
  |> pop_last()
  |> result.map_error(fn(_: Nil) { "Input is empty" })
}

fn pop_last(list: List(a)) -> Result(#(List(a), a), Nil) {
  case list {
    [] -> Error(Nil)
    [last] -> Ok(#([], last))
    [head, ..rest] -> {
      // We know rest must have at least one element
      let assert Ok(#(others, last)) = pop_last(rest)
      Ok(#([head, ..others], last))
    }
  }
}

fn trim_trailing_empty(list: List(String)) -> List(String) {
  list
  |> list.reverse()
  |> list.drop_while(fn(s) { s == "" })
  |> list.reverse()
}

fn parse_int(input: String) -> Result(Int, String) {
  input
  |> int.parse()
  |> result.map_error(fn(_: Nil) { "Malformed int '" <> input <> "'" })
}

fn parse_operator(input: String) -> Result(Operator, String) {
  case input {
    "*" -> Ok(Multiply)
    "+" -> Ok(Add)
    _ -> Error("Malformed operator '" <> input <> "'")
  }
}

fn log_10(n: Float) -> Result(Float, Nil) {
  let assert Ok(log_10) = float.logarithm(10.0)
  n
  |> float.logarithm
  |> result.map(fn(log_e) { log_e /. log_10 })
}
