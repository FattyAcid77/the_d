ELEVEN ROOMS, ALREADY BUILT

Every .tres in this folder is loaded by MapRooms at startup. The art is in
Art/ so it works the moment you unzip it — move the PNGs wherever you keep
art and re-point the .tres files if you'd rather.

  reception                Reception            <- known from the start
  above_path               Upper Corridor
  m_room                   M Room
  masochist_room           Masochist Room
  sadistic_room            Sadistic Room
  down_path                Lower Corridor
  path_room                Corridor
  maryam_room              Maryam's Room
  maryam_room_mirror       Maryam's Room        (the mirror side)
  maryam_path_room         Maryam's Corridor
  maryam_path_room_mirror  Maryam's Corridor    (the mirror side)

WHAT YOU STILL HAVE TO DO
In each room's SCENE, add a MapRoom node with `room_id` set to the id above,
and a CollisionShape2D over the walkable floor. Nothing else.

TWO EXTRA FILES I MADE FOR YOU (Art/)
  MAP_BOARD.png   the green board with the rooms and their outlines erased,
                  worn corners kept. This is the map BACKGROUND — rooms are
                  drawn on top as he finds them. Full_Map.png can't be the
                  background: its rooms are baked in, so everything would be
                  revealed from the start.
  MAP_MARKER.png  the little Sami, cut out of Full_Map.png (9x17).

A NOTE ON SCALE
The rooms in Full_Map.png are drawn BIGGER than your separate room PNGs
(Full_Map spans x 225-427, the eleven rooms together span x 258-382). The
separate art is what gets drawn, so the map will look correct but sit a bit
smaller inside the board than your mock-up. If you want it to fill the board,
scale the eleven room PNGs up by about 1.6x around the board's centre — or
leave it, it reads fine as a map with a margin.

DISPLAY NAMES are English keys, so they translate through translations.csv
like everything else. Both Maryam rooms share a name on purpose — the mirror
one shouldn't announce itself.

The filename RECIPTION_ROOM.png is left as you sent it; only the room's id
is spelled "reception".
