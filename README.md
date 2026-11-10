# Image Slide Puzzle (FPGA, pure Verilog)

A picture cut into a 4x4 grid, one piece missing: slide the other fifteen
around until it is whole again. It is all hardware - no CPU, no software. A
state machine plays the game, and the picture is drawn live from an image ROM,
pixel by pixel, as the beam scans. There is no framebuffer.

Course project 4 of 2110597 Graphics System Architecture, Chulalongkorn
University.

## Quick start

Pick whichever you have. Every board needs Vivado (the free edition is
enough) on `PATH`.

### No board: play in the browser

Open the VGA Playground, turn on **Gamepad mode**, and use the arrow keys:

<https://vga-playground.com/?repo=https://github.com/xHexlabx/fpga-image-game-slide&ref=main>

### Digilent Basys3 (VGA monitor)

```sh
vivado -mode batch -source scripts/create_project_basys3.tcl
```

1. Open `vivado_project_basys3/basys3_slidepuzzle.xpr` in Vivado.
2. Click **Generate Bitstream** (it runs synthesis and implementation first).
3. Plug a VGA monitor into the Basys3 and the board into USB, then
   **Open Hardware Manager -> Auto Connect -> Program Device**.

### ALINX AX7010 (HDMI monitor)

```sh
vivado -mode batch -source scripts/create_project.tcl
```

Then open `vivado_project/ax7010_slidepuzzle.xpr` and follow the same steps
as for the Basys3.

## How to play

1. The title screen shows the whole picture, with a band of light sweeping
   across it now and then. **Press any button to start.**
2. The board is shuffled. Each press slides the tile beside the gap **in the
   direction you pressed, into the gap**. For example, *up* moves the tile
   below the gap up.
3. When every tile is home, the missing piece comes back. The finished
   picture opens from the centre as a growing circle, then it returns to the
   title.

Stuck? Hold **peek** to see the finished picture. **Start** reshuffles at
any time. Every shuffle can be solved.

### Controls

| Action | Basys3 | AX7010 | VGA Playground |
|---|---|---|---|
| slide up / down / left / right | `btnU` `btnD` `btnL` `btnR` | `key[0]` `key[1]` `key[2]` `key[3]` | arrow keys |
| start / reshuffle | `btnC` (centre) | up + down together | `t` or `a` |
| peek (hold) | `SW0` up, or `btnL` + `btnR` | left + right together | `s` or `b` |

Notes:

- On the AX7010, the second button of a chord moves nothing, so a chord costs
  at most the one move its first button made. If that move is still sliding
  when the chord completes, the reshuffle waits for the tile to land.
- The AX7010 also takes five optional buttons on header J10, each wired from
  its pin to ground: up W19 (pin 3), down W18 (pin 4), left R14 (pin 5),
  right P14 (pin 6), start Y17 (pin 7), GND on pin 1. They use internal
  pull-ups, so with nothing wired they read as released. Do not touch pin 2,
  which is 5V.
- In the playground you can also use the switches `ui_in` (keys `0`-`7`):
  `0` `1` `2` `3` are the directions and `7` is start. These buttons are
  toggles: a click flips the bit and it stays flipped, so every flip in
  either direction counts as one press.

### Targets

The same game core runs on all three:

| | Basys3 | AX7010 | VGA Playground |
|---|---|---|---|
| top | `hdl_basys3/top_basys3.v` | `hdl/top.v` | `src/tt_um_hextex_slidepuzzle.v` |
| pins | `constraints_basys3/basys3_slidepuzzle.xdc` | `constraints/ax7010_slidepuzzle.xdc` | `info.yaml` |
| FPGA | Artix-7 `xc7a35tcpg236-1` | Zynq-7000 `xc7z010clg400-1` | (simulated) |
| clock | 100 MHz -> 25.175 MHz | 50 MHz -> 25.175 MHz | 25.175 MHz |
| output | VGA 640x480@60, 4 bits/channel, dithered | HDMI 640x480@60, 24-bit | Tiny VGA, 2 bits/channel, dithered |
| shared | `src/puzzle_core.v`, `src/vga_timing.v`, `src/image.mem`, `src/palette.mem` | same | same |

> **Status:**
> - **Simulation:** verified for the core, the playground top, and the
>   button and video paths of both board tops.
> - **Vivado:** both boards build clean through bitstream.
> - **Playground compile:** linted with Verilator 5.054 and the playground's
>   own flags, with no errors.
>
> Not yet tried on real hardware.

## How it works

### Drawing the picture without moving it

The picture never moves in memory. The only thing a move changes is
`board`, sixteen 4-bit entries that say which tile sits in each slot. For
every pixel, stage 0 of the renderer works out:

```
slot    = which slot the beam is in      3 comparators per axis: x >= 160/320/480
tile    = board[slot]                    a 16:1 mux
lx, ly  = position inside the slot       x - col*160, y - row*120 (shift + add)
address = (tile_row*60 + ly/2) * 320 + tile_col*80 + lx/2
```

Every multiply is by a constant, so there are only shifts and adds
(`*320 = <<8 + <<6`, `*160 = <<7 + <<5`, `*120 = <<7 - <<3`) and no
divider. A move rewrites two board entries, and the next frame shows the
picture rearranged.

### Indexed colour

The 320x240 picture is stored as one 8-bit palette index per pixel (600
kbit, in block RAM), with a 256-entry table of 24-bit colours. This is how
indexed-colour consoles stored backgrounds: a byte per pixel, and the real
colour looked up on the way out. `scripts/gen_image.py` picks the 256
colours that suit the picture best.

### Pipeline

```
stage 0   x, y -> slot, tile, address, effect flags   (combinational, registered)
stage 1   image ROM:   address -> palette index      (block RAM)
stage 2   palette ROM: index   -> 24-bit colour
stage 3   bevels, the gap, dimming, shine            -> r, g, b
```

hsync, vsync and display-enable ride the same four registers, so the
colour and the sync come out together.

### Shuffling so it can always be solved

Placing the fifteen tiles at random would give an unsolvable board half of
the time (the classic 14-15 puzzle). The shuffle instead starts from the
solved board and makes 200 random but legal moves of the gap, one per clock,
all inside one vertical blanking interval. It never undoes the move it just
made. Every step is a real move, so walking back is always possible. The
random source is a 16-bit LFSR that steps on every clock, so how long the
player waits before pressing start decides the board.

### The sliding tile is a sprite

When a move is accepted, the tile becomes a 160x120 sprite at exactly the
position it was drawn. That is why a move can start mid-frame without a
seam. The sprite steps 16 px (horizontal) or 12 px (vertical) once per
frame during vblank. Both slots it is travelling between draw as the gap
underneath it. Only when the sprite arrives are the two board entries
written. Presses during a slide are ignored.

### Win: the iris

The board is solved when `board[i] == i` for all sixteen slots. The radius
grows 6 px a frame. For each pixel, `dx^2 + dy^2 < r^2` decides whether it
shows the finished picture or the dimmed board. `|dx|` and `|dy|` are
formed with compare-and-subtract, so nothing is signed. `r^2` sits in a
register, because it depends only on `r` and not on the pixel.

### The other effects

These are all per-pixel tests in stage 0, applied in stage 3:

- Every tile has a raised bevel: the top and left 2 px lighter, the bottom
  and right 2 px darker.
- The gap is a dark well with a 5 px shadow along its top and left.
- The title shine is a band where `|x + y - pos| < 26`.

### Three ends for three targets

- `hdl/top.v` (AX7010) puts the core between the Clocking Wizard, debounced
  buttons and an HDMI transmitter built in fabric: `tmds_encoder.v` does
  the TMDS 8b/10b encoding and `oserdes_tmds.v` serialises it with
  `OSERDESE2`, so no HDMI chip is needed.
- `hdl_basys3/top_basys3.v` (Basys3) uses the same buttons and core and
  drives the board's 12-bit resistor VGA port. 8-bit colour becomes 4 bits
  with the same bit-built 4x4 Bayer threshold as the playground:
  `level = (15c + threshold) >> 8`. The Basys3's buttons are active-high,
  so they are inverted before the shared debouncer.
- `src/tt_um_hextex_slidepuzzle.v` puts the same core between the
  playground's pins and the Tiny VGA output.
  - `gamepad_pmod_rx.v` is a fresh receiver for the gamepad's 3-wire
    shift-register protocol.
  - 24-bit colour becomes 2 bits per channel with a 4x4 Bayer threshold built
    from bits, `{x0^y0, y0, x1^y1, y1}`, with no table:
    `level = (3c + threshold) >> 8`.

`src/` keeps to a few rules for the playground:

- Nothing is wider than 32 bits or signed, because its simulator handles
  neither.
- No array is written inside a `for` loop, because Verilator rejects that.
- No comment line starts with the word "verilator", because Verilator
  reads such comments as directives and stops on one it doesn't know.

## Layout

```
./
  info.yaml          playground / Tiny Tapeout manifest
  src/               everything the playground needs, shared with the boards
    puzzle_core.v      the game and the renderer
    vga_timing.v       640x480@60 timing
    tt_um_hextex_slidepuzzle.v   playground top
    gamepad_pmod_rx.v  gamepad receiver (playground only)
    image.mem          picture, 8-bit indices    (generated)
    palette.mem        256 x RRGGBB              (generated)
  hdl/               AX7010 top, HDMI, and the button debounce (Basys3 uses it too)
  constraints/       AX7010 pins
  hdl_basys3/        Basys3 top (VGA)
  constraints_basys3/  Basys3 pins
  scripts/           create_project.tcl (AX7010), create_project_basys3.tcl,
                     gen_image.py
  sim/               testbenches and frame checkers
```

The VGA Playground's loader has fixed paths:

- it reads `info.yaml` from the root of a branch;
- it fetches every source file, and every `$readmemh` file, from `src/`;
- it finds the `$readmemh` files by reading the literal file name in the
  call.

That is why the shared files live in `src/` rather than `hdl/`, and why
`puzzle_core.v` says `$readmemh("image.mem")` with a bare name. Vivado finds
the same bare name because both `create_project*.tcl` scripts add the two
`.mem` files to the project. Icarus finds it because the testbenches run from `src/`.

## Using your own picture

```sh
python3 scripts/gen_image.py my_picture.jpg --preview /tmp/preview.png
```

The picture in `src/` now is `images/mambo.jpeg`. It is square, so it was
made with `--crop-y 1`: the 4:3 window sits at the bottom, which keeps the
whole face and loses only the top of the hat.

```sh
python3 scripts/gen_image.py images/mambo.jpeg --crop-y 1
```

The script crops the picture to 4:3, scales it to 320x240, reduces
it to 256 colours, and rewrites `src/image.mem` and `src/palette.mem`. The
crop is centred unless `--crop-x` / `--crop-y` move it (0 = left/top edge,
1 = right/bottom edge). With no argument it writes the built-in test scene (a
lake at dusk, original procedural art). The puzzle is easiest when each part
of the picture looks different: a large plain sky makes for tiles that cannot
be told apart. Then rerun the simulations; nothing in them depends on which picture it is.

## Building

The quick start above has the steps. These are the results after place and
route:

| Resource | AX7010 (xc7z010) | Basys3 (xc7a35t) |
|---|---|---|
| Slice LUTs | 929 / 17600 | 733 / 20800 |
| Registers | 535 / 35200 | 343 / 41600 |
| Block RAM tiles | 24.5 / 60 | 24.5 / 50 |
| DSP48 | 2 / 80 | 2 / 90 |
| Slack at 25.175 MHz | 17.8 ns | 16.2 ns |

- **Block RAM:** the picture takes 24 RAMB36 and the palette one RAMB18.
- **DSPs:** the iris's `dx^2` and `dy^2` use the two DSPs.
- **Warnings:** Vivado reports reading both `.mem` files. The only warning
  is the usual input-clock redefinition by the Clocking Wizard.

### VGA Playground

The playground loads a public GitHub branch whose root holds `info.yaml`,
and fetches the sources from `src/`. This repo has `info.yaml` at its root,
so any branch works directly:

```
https://vga-playground.com/?repo=https://github.com/<user>/<repo>&ref=<branch>
```

## Verification

The testbenches run from `src/` so that the `.mem` files are found:

```sh
cd src        # from the project root
mkdir -p ../sim/out   # frame dumps go here
iverilog -o /tmp/tb_puzzle.vvp ../sim/tb_puzzle.v puzzle_core.v vga_timing.v
vvp /tmp/tb_puzzle.vvp && python3 ../sim/check_frames.py

iverilog -o /tmp/tb_tt.vvp ../sim/tb_tt.v tt_um_hextex_slidepuzzle.v \
         puzzle_core.v vga_timing.v gamepad_pmod_rx.v
vvp /tmp/tb_tt.vvp && python3 ../sim/check_tt.py

# shuffle soak: six full 200-move shuffles, each checked for solvability
iverilog -P tb_puzzle.SHUF=200 -P tb_puzzle.REPLAY=0 -o /tmp/tb_soak.vvp \
         ../sim/tb_puzzle.v puzzle_core.v vga_timing.v
vvp /tmp/tb_soak.vvp

# the playground's compile, with its own Verilator flags (warnings are fine;
# only %Error lines stop the playground)
cd ..
verilator --cc -O3 -Wall -Wno-EOFNEWLINE -Wno-DECLFILENAME --x-assign fast \
          --debug-check -Isrc/ --top-module tt_um_hextex_slidepuzzle -Wno-fatal \
          --Mdir /tmp/vl src/tt_um_hextex_slidepuzzle.v src/puzzle_core.v \
          src/vga_timing.v src/gamepad_pmod_rx.v
cd src

# the AX7010 top's buttons (Clocking Wizard and hdmi_tx stubbed in the bench)
iverilog -o /tmp/tb_top.vvp ../sim/tb_top.v ../hdl/top.v ../hdl/pad_input.v \
         puzzle_core.v vga_timing.v
vvp /tmp/tb_top.vvp

# the Basys3 top's buttons and VGA port (Clocking Wizard stubbed)
iverilog -o /tmp/tb_basys3.vvp ../sim/tb_basys3.v ../hdl_basys3/top_basys3.v \
         ../hdl/pad_input.v puzzle_core.v vga_timing.v
vvp /tmp/tb_basys3.vvp
```

**`tb_puzzle.v`** plays a whole game at real 640x480 timing.

- It watches the shuffle move by move. Then it undoes the shuffle by
  pressing the same directions in reverse order, which must solve the board
  and trigger the win.
- Along the way it checks that:
  - every board is a permutation with solvable parity;
  - a move off the edge of the board changes nothing;
  - a press during a slide is ignored;
  - peek blocks moves.
- It dumps seven frames: title, shuffled, peek, mid-slide, mid-iris, final,
  and soak in the soak run.
- `check_frames.py` rebuilds every pixel of every frame from `image.mem`,
  `palette.mem` and the logged board state alone, then compares exactly.

**`tb_tt.v`** drives the playground top the way the playground does.

- The gamepad model is a line-for-line copy of the playground's
  `updateGamepadPmod()`.
- It checks that:
  - start, the arrows and select each act exactly once per press;
  - each switch flip is one press;
  - a switch already on through reset is not a press;
  - `ui_in[7]` reshuffles;
  - the sync pulses on `uo_out[7]` / `uo_out[3]` are 96 clocks / 2 lines.
- `check_tt.py` decodes the title frame from `uo_out` with the playground's
  own bit mapping and compares it exactly against the dithered picture.

**`tb_top.v`** runs the AX7010 top's button path at the real 5 ms debounce.
The Clocking Wizard and `hdmi_tx` are stubbed, because they exist only
inside Vivado, and the picture behind them is already checked by
`tb_puzzle.v`. Presses are counted where they reach the core. It checks:

- power-on reset;
- a 2 ms blip is filtered out;
- any key on the title starts a game;
- up then down gives one up, no down and a reshuffle, even when the up
  started a slide;
- left then right peeks while held, with one left and no right;
- the J10 direction and start buttons work;
- every push is exactly one press.

**`tb_basys3.v`** runs the Basys3 top the same way, with the Clocking Wizard
stubbed. It checks:

- no phantom press at power-on from the active-high buttons;
- a 2 ms blip is filtered out;
- btnC starts a game and reshuffles;
- a direction is exactly one press;
- SW0 peeks, and btnL + btnR peeks with one left and no right;
- the VGA port: sync pulses of 96 clocks and 2 lines, black outside the
  picture, and every visible pixel equal to the core's colour dithered to
  4 bits.

## Outstanding for submission

- [ ] Load it live in the VGA Playground
- [ ] Hardware bring-up on the AX7010 (and/or Basys3)
- [ ] Video of it running on real hardware
- [ ] Short written explanation of the hardware
- [x] Swap the test scene for the final picture (`scripts/gen_image.py`)
