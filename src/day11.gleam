import advent_of_code_2025
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/pair
import gleam/result
import gleam/string

type Graph {
  Graph(adjacencies: dict.Dict(Node, List(Node)))
}

type Node {
  Node(String)
}

pub fn main() {
  advent_of_code_2025.run_with_input_file(run)
}

fn run(input: String) -> Result(Nil, String) {
  use graph <- result.try(parse_input(input))
  io.println("Part 1: " <> part1(graph))
  io.println("Part 2: " <> part2(graph))

  Ok(Nil)
}

fn part1(graph: Graph) -> String {
  count_paths(graph, Node("you"), Node("out"))
  |> int.to_string()
}

fn part2(graph: Graph) -> String {
  let srv_fft = count_paths(graph, Node("svr"), Node("fft"))
  let fft_dac = count_paths(graph, Node("fft"), Node("dac"))
  let dac_out = count_paths(graph, Node("dac"), Node("out"))

  int.to_string(srv_fft * fft_dac * dac_out)
}

fn count_paths(graph: Graph, source: Node, target: Node) -> Int {
  let topological =
    graph
    |> topological()
    |> list.drop_while(fn(node) { node != source })
    |> list.reverse()
    |> list.drop_while(fn(node) { node != target })
    // Drop the target itself
    |> list.drop(1)

  let assert Ok(paths) =
    do_count_paths(graph, source, topological, dict.from_list([#(target, 1)]))

  paths
}

fn do_count_paths(
  graph: Graph,
  source: Node,
  topological: List(Node),
  memo: dict.Dict(Node, Int),
) -> Result(Int, String) {
  case topological {
    [] ->
      memo
      |> dict.get(source)
      |> result.map_error(fn(_: Nil) { "did not encounter source node" })

    [head, ..rest] -> {
      let neighbor_res =
        neighbors(graph, head)
        |> result.map_error(fn(_: Nil) {
          "topological sort contained unknown node " <> node_name(head)
        })

      use neighbors <- result.try(neighbor_res)

      let entry =
        neighbors
        |> list.filter_map(fn(neighbor) { dict.get(memo, neighbor) })
        |> int.sum()

      do_count_paths(graph, source, rest, dict.insert(memo, head, entry))
    }
  }
}

fn new_graph() -> Graph {
  Graph(adjacencies: dict.new())
}

fn add_edge(graph: Graph, source: String, target: String) -> Graph {
  let source = Node(source)
  let target = Node(target)

  let source_neighbors =
    graph.adjacencies
    |> dict.get(source)
    |> result.unwrap(or: [])

  let target_neighbors =
    graph.adjacencies
    |> dict.get(target)
    |> result.unwrap(or: [])

  let adjacencies =
    graph.adjacencies
    |> dict.insert(source, [target, ..source_neighbors])
    |> dict.insert(target, target_neighbors)

  Graph(adjacencies:)
}

fn neighbors(graph: Graph, node: Node) -> Result(List(Node), Nil) {
  dict.get(graph.adjacencies, node)
}

fn neighbors_to(graph: Graph, node: Node) -> Result(List(Node), Nil) {
  use <- bool.guard(!dict.has_key(graph.adjacencies, node), Error(Nil))

  graph.adjacencies
  |> dict.to_list()
  |> list.filter(fn(entry) {
    let #(_key, neighbors) = entry
    list.contains(neighbors, node)
  })
  |> list.map(pair.first)
  |> Ok
}

fn map_graph(graph: Graph, map: fn(Node, List(Node)) -> a) -> List(a) {
  graph.adjacencies
  |> dict.to_list()
  |> list.map(fn(entry) {
    let #(node, neighbors) = entry
    map(node, neighbors)
  })
}

fn node_name(node: Node) -> String {
  let Node(name) = node

  name
}

fn topological(graph: Graph) -> List(Node) {
  let nodes_by_neighbor_count =
    graph
    |> map_graph(fn(node, neighbors) { #(node, list.length(neighbors)) })
    |> dict.from_list()

  // This can only fail due to internal inconsistencies
  let assert Ok(topological) = do_topological(graph, nodes_by_neighbor_count)

  list.reverse(topological)
}

fn do_topological(
  graph: Graph,
  nodes_by_neighbor_count: dict.Dict(Node, Int),
) -> Result(List(Node), String) {
  let candidates_res =
    nodes_by_neighbor_count
    |> dict.to_list()
    |> list.find(fn(entry) {
      let #(_node, neighbor_count) = entry

      neighbor_count == 0
    })
    |> result.map(pair.first)

  case candidates_res {
    Ok(candidate) -> {
      use nodes_by_neighbor_count <- result.try(subtract_node_from(
        graph,
        nodes_by_neighbor_count,
        candidate,
      ))

      use rest <- result.try(do_topological(graph, nodes_by_neighbor_count))
      Ok([candidate, ..rest])
    }
    Error(Nil) -> Ok([])
  }
}

fn subtract_node_from(
  graph: Graph,
  nodes_by_neighbor_count: dict.Dict(Node, Int),
  candidate: Node,
) -> Result(dict.Dict(Node, Int), String) {
  let neighbors_res =
    graph
    |> neighbors_to(candidate)
    |> result.map_error(fn(_: Nil) {
      "could not find inward neighbors for node " <> node_name(candidate)
    })

  use neighbors <- result.try(neighbors_res)

  neighbors
  |> list.try_fold(nodes_by_neighbor_count, fn(nodes_by_neighbor_count, node) {
    let current_res =
      nodes_by_neighbor_count
      |> dict.get(node)
      |> result.map_error(fn(_: Nil) {
        "could not find neighbors for node " <> node_name(node)
      })

    use current <- result.try(current_res)
    Ok(dict.insert(nodes_by_neighbor_count, node, current - 1))
  })
  |> result.map(fn(nodes_by_neighbor_count) {
    dict.delete(nodes_by_neighbor_count, candidate)
  })
}

fn parse_input(input: String) -> Result(Graph, String) {
  input
  |> string.trim_end()
  |> string.split("\n")
  |> list.try_fold(new_graph(), fn(graph, line) {
    use #(source, neighbors) <- result.try(parse_line(line))

    neighbors
    |> list.fold(graph, fn(graph, neighbor) {
      add_edge(graph, source, neighbor)
    })
    |> Ok()
  })
}

fn parse_line(line: String) -> Result(#(String, List(String)), String) {
  case string.split_once(line, ": ") {
    Ok(#(source, targets)) -> Ok(#(source, string.split(targets, " ")))
    Error(Nil) -> Error("Malformed input line: '" <> line <> "'")
  }
}
