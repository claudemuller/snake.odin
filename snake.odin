package snake

import "core:log"
import rl "vendor:raylib"

WINDOW_SIZE :: 1000
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE
TICK_RATE :: 0.13
MAX_SNAKE_LEN :: GRID_WIDTH * GRID_WIDTH
PURPLEISH :: [4]u8{76, 53, 83, 255}

Vec2i :: [2]int

snake_len: int
snake: [MAX_SNAKE_LEN]Vec2i
move_direction: Vec2i

tick_timer: f32 = TICK_RATE
game_over: bool

restart :: proc() {
	start_head_pos := Vec2i{GRID_WIDTH / 2, GRID_WIDTH / 2}
	snake[0] = start_head_pos
	snake[1] = start_head_pos - {0, 1}
	snake[2] = start_head_pos - {0, 2}
	snake_len = 3
	move_direction = {0, 1}
	game_over = false
}

main :: proc() {
	logger := log.create_console_logger()
	context.logger = logger

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake")

	restart()

	for !rl.WindowShouldClose() {
		if rl.IsKeyDown(.UP) {
			move_direction = {0, -1}
		}
		if rl.IsKeyDown(.DOWN) {
			move_direction = {0, 1}
		}
		if rl.IsKeyDown(.LEFT) {
			move_direction = {-1, 0}
		}
		if rl.IsKeyDown(.RIGHT) {
			move_direction = {1, 0}
		}

		if game_over {
			if rl.IsKeyPressed(.ENTER) {
				restart()
			}
		} else {
			tick_timer -= rl.GetFrameTime()
		}

		if tick_timer <= 0 {
			next_part_pos := snake[0]
			snake[0] += move_direction
			head_pos := snake[0]

			if head_pos.x < 0 ||
			   head_pos.x >= GRID_WIDTH ||
			   head_pos.y < 0 ||
			   head_pos.y >= GRID_WIDTH {
				game_over = true
			}

			for i in 1 ..< snake_len {
				cur_pos := snake[i]
				snake[i] = next_part_pos
				next_part_pos = cur_pos
			}

			tick_timer += TICK_RATE
		}

		rl.BeginDrawing()
		rl.ClearBackground(PURPLEISH.rgba)

		camera := rl.Camera2D {
			zoom = f32(WINDOW_SIZE) / CANVAS_SIZE,
		}
		rl.BeginMode2D(camera)

		for i in 0 ..< snake_len {
			head_rect := rl.Rectangle {
				f32(snake[i].x * CELL_SIZE),
				f32(snake[i].y * CELL_SIZE),
				CELL_SIZE,
				CELL_SIZE,
			}
			rl.DrawRectangleRec(head_rect, rl.WHITE)
		}

		if game_over {
			txt := cstring("Game Over")
			prev_size := i32(25)
			width := rl.MeasureText(txt, prev_size)
			rl.DrawText(
				txt,
				CANVAS_SIZE / 2 - width / 2,
				CANVAS_SIZE / 2 - prev_size / 2,
				prev_size,
				rl.RED,
			)

			txt = cstring("Press enter to play again")
			size := i32(15)
			width = rl.MeasureText(txt, size)
			rl.DrawText(
				txt,
				CANVAS_SIZE / 2 - width / 2,
				CANVAS_SIZE / 2 - size / 2 + prev_size,
				size,
				rl.BLACK,
			)
		}

		rl.EndMode2D()
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
