package snake

import rl "vendor:raylib"

WINDOW_SIZE :: 1000
PURPLEISH :: [4]u8{76, 53, 83, 255}

main :: proc() {
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Snake")

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(PURPLEISH.rgba)

		rl.EndDrawing()
	}
}
