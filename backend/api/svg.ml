open Backend.File

let svg_from_file ~path =
   List.fold_left (fun acc l -> acc ^ l) "" (read_lines path)
