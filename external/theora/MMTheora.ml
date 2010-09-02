class reader_of_file fname =
  let fd = Unix.openfile fname [Unix.O_RDONLY] 0o400 in
  let x = ref 0 in
  let read n =
    let s = String.create n in
    let r = Unix.read fd s 0 n in
    x := !x + r;
    Printf.printf "Read %d -> %d\n%!" n !x;
    assert (r > 0);
    s,r
  in
  let sync = Ogg.Sync.create read in
  (* let sync,fd = Ogg.Sync.create_from_file fname in *)
  let rec fill os =
    let page = Ogg.Sync.read sync in
    try
      (* We drop pages which are not for us.. *)
      if Ogg.Page.serialno page = Ogg.Stream.serialno os then
        Ogg.Stream.put_page os page;
    with
      | Ogg.Bad_data -> fill os (* Do not care about page that are not for us.. *)
  in
  (* Test wether the stream is theora *)
  let test_theora () =
    (* Get First page *)
    let page = Ogg.Sync.read sync in
    (* Check wether this is a b_o_s *)
    if not (Ogg.Page.bos page) then raise Video.IO.Invalid_file;
    (* Create a stream with this ID *)
    let serial = Ogg.Page.serialno page in
    Printf.printf "Testing stream %nx.\n" serial;
    let os = Ogg.Stream.create ~serial () in
    Ogg.Stream.put_page os page;
    let packet = Ogg.Stream.get_packet os in
    (* Test header. Do not catch anything, first page should be sufficient. *)
    if not (Theora.Decoder.check packet) then raise Not_found;
    Printf.printf "Got a theora stream!\n" ;
    let dec = Theora.Decoder.create () in
    (* Decode headers *)
    let rec f packet =
      try
        Theora.Decoder.headerin dec packet
      with
        | Theora.Not_enough_data ->
          let rec g () =
            try
              let packet = Ogg.Stream.get_packet os in
              f packet
            with
              | Ogg.Not_enough_data -> fill os; g ()
          in
          g ()
    in
    let info,vendor,comments = f packet in
    serial,os,dec,info,vendor,comments
  in
  (** Now find a theora stream *)
  let rec init () =
    try
      Printf.printf "Testing... %!";
      let ans = test_theora () in
      Printf.printf "ok!\n%!";
      ans
    with
      | Not_found ->
        Printf.printf "This stream was not theora..\n";
        init ()
      | Video.IO.Invalid_file as e ->
        Printf.printf "No theora stream was found..\n%!";
        raise e
  in
  let serial,os,dec,info,vendor,comments = init () in
  (* TODO: handle more formats *)
  let _ = assert (info.Theora.pixel_fmt = Theora.PF_420) in
object (self)
  method width = info.Theora.frame_width

  method height = info.Theora.frame_height

  method frame_rate = (float_of_int info.Theora.fps_numerator) /. (float_of_int info.Theora.fps_denominator)

  val mutable latest_yuv = None

  method get_yuv =
    try
      let yuv = Theora.Decoder.get_yuv dec os in
      latest_yuv <- Some yuv;
      yuv
    with
      | Ogg.Not_enough_data when not (Ogg.Stream.eos os) ->
        (fill os; self#get_yuv)
      | Theora.Duplicate_frame ->
        (* Got a duplicate frame, sending previous one ! *)
        begin
          match latest_yuv with
            | Some x -> x
            | None   -> raise Video.IO.Invalid_file
        end

  method get_rgba8 =
    let yuv = self#get_yuv in
    Image.RGBA8.of_YUV420 (Image.YUV420.make yuv.Theora.y yuv.Theora.y_stride yuv.Theora.u yuv.Theora.v yuv.Theora.u_stride)

  method read buf ofs len =
    let n = ref 0 in
    try
      while !n < len do
        buf.(ofs + !n) <- self#get_rgba8;
        incr n
      done;
      !n
    with
      | Ogg.Not_enough_data -> !n

  method close = Unix.close fd

  (* TODO *)
  method seek (n:int) : unit = assert false
end

let reader_of_file fname =
  (new reader_of_file fname :> Video.IO.reader)
