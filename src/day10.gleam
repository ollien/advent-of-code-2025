import advent_of_code_2025
import gleam/bool
import gleam/deque
import gleam/dict
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

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use manual_entries <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(manual_entries))

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
