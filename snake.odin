package snake

import rl "vendor:raylib"

WINDOW_SIZE :: 1000
GRID_WIDTH :: 20
CELL_SIZE :: 16
CANVAS_SIZE :: GRID_WIDTH * CELL_SIZE
TICK_RATE :: 0.13
PURPLEISH :: [4]u8{76, 53, 83, 255}

Vec2i :: [2]int

snake_head_pos: Vec2i
tick_timer: f32 = TICK_RATE
move_direction: Vec2i

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake")

	snake_head_pos = {GRID_WIDTH / 2, GRID_WIDTH / 2}
	move_direction = {0, 1}

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

		tick_timer -= rl.GetFrameTime()

		if tick_timer <= 0 {
			snake_head_pos += move_direction
			tick_timer += TICK_RATE
		}

		rl.BeginDrawing()
		rl.ClearBackground(PURPLEISH.rgba)

		camera := rl.Camera2D {
			zoom = f32(WINDOW_SIZE) / CANVAS_SIZE,
		}
		rl.BeginMode2D(camera)

		head_rect := rl.Rectangle {
			f32(snake_head_pos.x * CELL_SIZE),
			f32(snake_head_pos.y * CELL_SIZE),
			CELL_SIZE,
			CELL_SIZE,
		}
		rl.DrawRectangleRec(head_rect, rl.WHITE)

		rl.EndMode2D()
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
