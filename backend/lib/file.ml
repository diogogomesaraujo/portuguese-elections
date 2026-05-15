  let read_lines file_path =
    let contents =
      In_channel.with_open_bin
        file_path
        In_channel.input_all
    in
    String.split_on_char '\n' contents
