import argv
import gleam/io
import gleam/result
import gleam_community/ansi
import gleave
import glint
import simplifile

pub fn main() {
  io.println("Usage: gleam run -m day<n> <filename>")
  gleave.exit(1)
}

pub fn run_with_input_file(run: fn(String) -> Result(Nil, String)) {
  glint.new()
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: [], do: run_command(run))
  |> glint.run(argv.load().arguments)
}

fn run_command(run: fn(String) -> Result(Nil, String)) -> glint.Command(Nil) {
  use filename_arg <- glint.named_arg("filename")
  use named, _unnamed, _flags <- glint.command()

  let filename = filename_arg(named)
  case run_with_file(filename, run) {
    Ok(Nil) -> Nil
    Error(err) -> io.println_error(ansi.red("error") <> ": " <> err)
  }
}

fn run_with_file(
  filename: String,
  run: fn(String) -> Result(Nil, String),
) -> Result(Nil, String) {
  simplifile.read(filename)
  |> result.map_error(simplifile.describe_error)
  |> result.try(run)
}
