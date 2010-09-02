let writer () =
  (object (self)
    val dev = Ao.open_live ()

    method write buf ofs len =
      let s = Audio.to_16le_create buf ofs len in
      Ao.play dev s

    method close =
      Ao.close dev
   end :> Audio.IO.writer)
